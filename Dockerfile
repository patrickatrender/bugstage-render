# Builds BugStage from the upstream Git repo at build time.
# Set BUGSTAGE_REF (branch or tag) as an env var on Render to pin a version.

FROM golang:1.27-alpine AS build
RUN apk add --no-cache git
ARG BUGSTAGE_REPO=https://ganigeorgiev.com/git/bugstage/bugstage
ARG BUGSTAGE_REF=master
WORKDIR /src
RUN git clone --depth=1 --branch "${BUGSTAGE_REF}" "${BUGSTAGE_REPO}" . \
 && git log -1 --format='Building BugStage %H (%cd)'
RUN go mod download

# Add the SSH-over-WebSocket tunnel (/_ssh) so Git over SSH works behind Render's HTTP-only proxy.
COPY patches/ssh_tunnel.go base/ssh_tunnel.go
RUN sed -i 's/^\(\s*\)app := bugstage.New()$/&\n\1registerSSHTunnel(app)/' base/main.go \
 && grep -q 'registerSSHTunnel(app)' base/main.go \
 || (echo "ERROR: could not patch base/main.go (upstream changed?)" && exit 1)

RUN CGO_ENABLED=0 go build -trimpath \
    -ldflags "-s -w -X ganigeorgiev.com/pocketbase/pocketbase.Version=${BUGSTAGE_REF}" \
    -o /out/bugstage ./base

FROM alpine:3.23
RUN apk add --no-cache ca-certificates tzdata
COPY --from=build /out/bugstage /usr/local/bin/bugstage
EXPOSE 8090
# SQLite data, uploads and Git repos live in /pb_data (Render persistent disk).
# SSH listens on loopback only; it's reached through the /_ssh WebSocket tunnel.
CMD ["sh", "-c", "exec bugstage serve --http=0.0.0.0:${PORT:-8090} --ssh=127.0.0.1:8022 --dir=/pb_data"]
