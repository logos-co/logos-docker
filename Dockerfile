FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

ARG LOGOSCTL_VERSION=0.3.0
ARG TARGETARCH
RUN case "${TARGETARCH:-$(dpkg --print-architecture)}" in \
        amd64) arch=x86_64 ;; \
        arm64) arch=aarch64 ;; \
        *) echo "unsupported architecture: ${TARGETARCH}" >&2; exit 1 ;; \
    esac \
    && mkdir -p /app && cd /app \
    && curl -fsSL "https://github.com/logos-co/logos-logoscore-cli/releases/download/${LOGOSCTL_VERSION}/logosctl-${arch}-linux.tar.gz" | tar -xz \
    && "./logosctl-${arch}.AppImage" --appimage-extract > /dev/null \
    && mv squashfs-root logosctl \
    && rm "logosctl-${arch}.AppImage" \
    && ln -s /app/logosctl/AppRun /usr/local/bin/logosctl

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
# Separate catalog until the RLN modules are published to logos-modules-release.
ARG RLN_REPO=https://github.com/logos-co/logos-rln-modules/releases/download/index/logos-repo.json

RUN logosctl daemon start --detach \
    && for repo in "${MODULES_REPO}" "${RLN_REPO}"; do \
        logosctl catalog ls | grep -qF "\"url\":\"${repo}\"" || logosctl catalog add "${repo}"; \
    done \
    && pkg() { [ -z "$2" ] || logosctl install "$1" --version "$2" --catalog "$3" -y; } \
    && pkg delivery_module "${DELIVERY_VERSION}" "${MODULES_REPO}" \
    && pkg storage_module "${STORAGE_VERSION}" "${MODULES_REPO}" \
    && pkg blockchain_module "${BLOCKCHAIN_VERSION}" "${MODULES_REPO}" \
    && pkg openmetrics "${OPENMETRICS_VERSION}" "${MODULES_REPO}" \
    && pkg liblogos_rln_module "${RLN_VERSION}" "${RLN_REPO}" \
    && logosctl package ls \
    && logosctl daemon stop \
    && while logosctl status > /dev/null 2>&1; do sleep 1; done \
    && rm -rf /var/lib/logos/logs/*

CMD ["logosctl", "daemon", "start"]
