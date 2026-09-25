# Stage 1: Build
FROM nixos/nix:2.34.1 AS builder
RUN printf '%s\n' \
        'experimental-features = nix-command flakes' \
        'extra-substituters = https://cache.nix.logos.co/public' \
        'extra-trusted-public-keys = public:l4HrXgL4nw246+LBh2SOJyhz64BoGegOYLheT/iIAPU=' \
        'fallback = true' \
    >> /etc/nix/nix.conf
WORKDIR /app

# release/0.3.0
ARG LOGOSCTL_REF=d9eb3ba89923c90452a3bebb36eccc09809c3062
RUN nix build "github:logos-co/logos-logoscore-cli/${LOGOSCTL_REF}#ctl-appimage" --out-link ./result \
    && ./result/logosctl.AppImage --appimage-extract > /dev/null \
    && mv squashfs-root logosctl

# Stage 2: Runtime
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app/logosctl /app/logosctl
RUN ln -s /app/logosctl/AppRun /usr/local/bin/logosctl

RUN mkdir -p /var/lib/logos/blockchain /var/lib/logos/persistence \
    && usermod -u 10000 ubuntu && groupmod -g 10000 ubuntu \
    && chown -R ubuntu:ubuntu /var/lib/logos /home/ubuntu

USER ubuntu
WORKDIR /home/ubuntu

ENV LANG=C.UTF-8 LOGOSCTL_CONFIG_DIR=/var/lib/logos
COPY --chown=ubuntu:ubuntu config.yaml /tmp/config.yaml
RUN logosctl daemon config set /tmp/config.yaml && rm /tmp/config.yaml

ARG DELIVERY_VERSION=0.2.1
ARG STORAGE_VERSION=2.1.3
ARG BLOCKCHAIN_VERSION=0.2.4
ARG OPENMETRICS_VERSION=0.1.1
ARG RLN_VERSION

ARG MODULES_REPO=https://raw.githubusercontent.com/logos-co/logos-modules-release/refs/heads/main/logos-repo.json

RUN logosctl daemon start --detach \
    && { logosctl catalog ls | grep -qF "\"url\":\"${MODULES_REPO}\"" || logosctl catalog add "${MODULES_REPO}"; } \
    && for url in $(logosctl catalog ls | grep -o '"url":"[^"]*"' | cut -d'"' -f4); do \
        [ "${url}" = "${MODULES_REPO}" ] || logosctl catalog disable "${url}"; \
    done \
    && { [ -z "${DELIVERY_VERSION}" ] || logosctl install delivery_module --version "${DELIVERY_VERSION}" -y; } \
    && { [ -z "${STORAGE_VERSION}" ] || logosctl install storage_module --version "${STORAGE_VERSION}" -y; } \
    && { [ -z "${BLOCKCHAIN_VERSION}" ] || logosctl install blockchain_module --version "${BLOCKCHAIN_VERSION}" -y; } \
    && { [ -z "${OPENMETRICS_VERSION}" ] || logosctl install openmetrics --version "${OPENMETRICS_VERSION}" -y; } \
    && { [ -z "${RLN_VERSION}" ] || logosctl install liblogos_rln_module --version "${RLN_VERSION}" -y; } \
    && logosctl package ls \
    && logosctl daemon stop \
    && while logosctl status > /dev/null 2>&1; do sleep 1; done \
    && rm -rf /var/lib/logos/logs/*

CMD ["logosctl", "daemon", "start"]
