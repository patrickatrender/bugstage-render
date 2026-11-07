# BugStage on Render

Deploys [BugStage](https://bugstage.dev) to Render. The Dockerfile clones and builds
BugStage from https://ganigeorgiev.com/git/bugstage/bugstage at build time, so this
repo holds only the deploy config.

## Deploy

1. Click **Deploy to Render** (or open `https://dashboard.render.com/blueprint/new?repo=<this repo URL>`).
2. No browser opens on a server. After the first deploy, open the service logs and find
   the line after "Launch the URL below in the browser": it looks like
   `http://0.0.0.0:10000/_/#/pbinstall/<token>`. Replace `http://0.0.0.0:10000` with your
   `https://<service>.onrender.com` URL, open it, and create the superuser. This also
   creates the first Maintainer account. The token expires about 2 hours after the
   service starts; restart the service to print a fresh one.
3. In the PocketBase dashboard (`/_/`), set **Settings > Application > Application URL** to
   your public URL.

## Configuration

- `BUGSTAGE_REF`: the branch or tag to build (default `master`). Change it and redeploy
  (clear the build cache) to upgrade.
- Data lives on a 5 GB persistent disk at `/pb_data`. Back it up from the PocketBase dashboard.

## Git over SSH

Render web services expose only HTTP(S), so BugStage's SSH server can't be reached
directly. This template adds a `/_ssh` route that tunnels SSH over a WebSocket on the
normal HTTPS port (see `patches/ssh_tunnel.go`). BugStage's own SSH server still handles
key checks and pushes.

One-time client setup:

1. Install [websocat](https://github.com/vi/websocat) (`brew install websocat`).
2. Add to `~/.ssh/config`:
   ```
   Host <service>.onrender.com
     ProxyCommand websocat --binary wss://%h/_ssh
     ServerAliveInterval 30
   ```
3. Register your public key in BugStage (user settings > SSH keys), then use the SSH
   remote shown on the repository page.

Clone and fetch also work over plain HTTPS: `https://<service>.onrender.com/git/<project>/<repo>`.

## Limitations on Render

- A persistent disk means one instance only, and deploys have a few seconds of downtime.
