# BugStage on Render

Deploys [BugStage](https://bugstage.dev) to Render. The Dockerfile clones and builds
BugStage from https://ganigeorgiev.com/git/bugstage/bugstage at build time, so this
repo holds only the deploy config.

## Deploy

1. Click **Deploy to Render** (or open `https://dashboard.render.com/blueprint/new?repo=<this repo URL>`).
2. After the first deploy, open the service logs and find the PocketBase installer link
   (`http://0.0.0.0:PORT/_/#/pbinstal/...`). Replace `http://0.0.0.0:PORT` with your
   `https://<service>.onrender.com` URL and create the superuser. This also creates the
   first Maintainer account.
3. In the PocketBase dashboard (`/_/`), set **Settings > Application > Application URL** to
   your public URL.

## Configuration

- `BUGSTAGE_REF`: the branch or tag to build (default `master`). Change it and redeploy
  (clear the build cache) to upgrade.
- Data lives on a 5 GB persistent disk at `/pb_data`. Back it up from the PocketBase dashboard.

## Limitations on Render

- **Git push over SSH is not available.** Render web services expose only HTTP(S), so the
  SSH server on port 8022 is unreachable from outside. Clone over HTTPS works.
- A persistent disk means one instance only, and deploys have a few seconds of downtime.
