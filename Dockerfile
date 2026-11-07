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
RUN CGO_ENABLED=0 go build -trimpath \
    -ldflags "-s -w -X ganigeorgiev.com/pocketbase/pocketbase.Version=${BUGSTAGE_REF}" \
    -o /out/bugstage ./base

FROM alpine:3.23
RUN apk add --no-cache ca-certificates tzdata
COPY --from=build /out/bugstage /usr/local/bin/bugstage
EXPOSE 8090
# SQLite data, uploads and Git repos live in /pb_data (Render persistent disk)
CMD ["sh", "-c", "exec bugstage serve --http=0.0.0.0:${PORT:-8090} --dir=/pb_data"]
