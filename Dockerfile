# syntax=docker/dockerfile:1
# vpn-lite — minimal OpenVPN tunnel container (CONNECT proxy + killswitch).

FROM rust:alpine AS builder
WORKDIR /build
COPY Cargo.toml ./
COPY src ./src
RUN cargo build --release

FROM alpine:3.20
RUN apk add --no-cache openvpn iptables iproute2 tini
COPY --from=builder /build/target/release/vpn-lite /usr/local/bin/vpn-lite

EXPOSE 8888

# /healthz returns 200 only while tun0 exists — covers tunnel + proxy.
HEALTHCHECK --interval=30s --timeout=10s --start-period=90s --retries=3 \
  CMD wget -q -O /dev/null http://127.0.0.1:${PROXY_PORT:-8888}/healthz || exit 1

ENTRYPOINT ["/sbin/tini", "--", "vpn-lite"]
