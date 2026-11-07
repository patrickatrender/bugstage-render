package main

// SSH-over-WebSocket tunnel for hosts that only expose HTTP(S), such as Render.
//
// The Dockerfile copies this file into BugStage's ./base package and calls
// registerSSHTunnel(app) from main(). It adds a GET /_ssh route that upgrades to
// a WebSocket and pipes raw bytes to BugStage's own SSH server, so key checks and
// push handling stay in BugStage.
//
// Client side (~/.ssh/config):
//
//	Host your-service.onrender.com
//	  ProxyCommand websocat --binary wss://%h/_ssh
//	  ServerAliveInterval 30

import (
	"io"
	"net"
	"net/http"
	"os"
	"time"

	"ganigeorgiev.com/pocketbase/pocketbase/core"
	"golang.org/x/net/websocket"
)

const sshTunnelPath = "/_ssh"

func registerSSHTunnel(app core.App) {
	target := os.Getenv("BUGSTAGE_SSH_TUNNEL_TARGET")
	if target == "" {
		target = "127.0.0.1:8022"
	}

	app.OnServe().BindFunc(func(se *core.ServeEvent) error {
		se.Router.GET(sshTunnelPath, func(e *core.RequestEvent) error {
			ws := websocket.Server{
				// No Origin check: SSH clients aren't browsers. Auth is done by
				// BugStage's SSH server (registered public keys).
				Handshake: func(*websocket.Config, *http.Request) error { return nil },
				Handler: func(conn *websocket.Conn) {
					defer conn.Close()
					conn.PayloadType = websocket.BinaryFrame
					// clear any read/write deadlines inherited from the HTTP server
					_ = conn.SetDeadline(time.Time{})

					upstream, err := net.DialTimeout("tcp", target, 10*time.Second)
					if err != nil {
						e.App.Logger().Error("SSH tunnel: failed to reach SSH server", "target", target, "error", err)
						return
					}
					defer upstream.Close()

					done := make(chan struct{}, 2)
					go func() { _, _ = io.Copy(upstream, conn); done <- struct{}{} }()
					go func() { _, _ = io.Copy(conn, upstream); done <- struct{}{} }()
					<-done
				},
			}

			ws.ServeHTTP(hijackableWriter(e.Response), e.Request)
			return nil
		})

		return se.Next()
	})
}

// hijackableWriter unwraps PocketBase's response writer wrappers until it finds
// one that implements http.Hijacker (needed for the WebSocket upgrade).
func hijackableWriter(w http.ResponseWriter) http.ResponseWriter {
	for {
		if _, ok := w.(http.Hijacker); ok {
			return w
		}
		u, ok := w.(interface{ Unwrap() http.ResponseWriter })
		if !ok {
			return w
		}
		w = u.Unwrap()
	}
}
