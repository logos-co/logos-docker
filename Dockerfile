FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

ARG LOGOSCTL_VERSION=0.3.2
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
    && rm "logosctl-${arch}.AppImage"
RUN ln -s /app/logosctl/AppRun /usr/local/bin/logosctl

RUN mkdir -p /var/lib/logos/blockchain /var/lib/logos/persistence \
    && usermod -u 10000 ubuntu && groupmod -g 10000 ubuntu \
    && chown -R ubuntu:ubuntu /var/lib/logos /home/ubuntu

USER ubuntu
WORKDIR /home/ubuntu

ENV LANG=C.UTF-8 LOGOSCTL_CONFIG_DIR=/var/lib/logos
COPY --chown=ubuntu:ubuntu config.yaml /tmp/config.yaml
RUN logosctl daemon config set /tmp/config.yaml && rm /tmp/config.yaml

ARG DELIVERY_VERSION=0.3.2
ARG STORAGE_VERSION=3.0.2
ARG BLOCKCHAIN_VERSION=0.3.4
# Bootstrap peers of the network BLOCKCHAIN_VERSION joins, from its release; bump them together.
ARG BLOCKCHAIN_PEERS="/ip4/65.109.51.37/udp/3000/quic-v1/p2p/12D3KooWFrouXfmrR4nsLMtE7wu15DoMJ6VtoUtHinREZCvbWHar /ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWJRGau8M1rjT7R5e4YYsgdFhsMX35nRDtMwCDjxQkXAHz /ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWQXJavMDTRscjauFSgVAB1VLB6Rzpy2uY5SU9Tk7927tb /ip4/65.109.51.37/udp/50001/quic-v1/p2p/12D3KooWSQc7CcGtvWDPF1yCbBthFnQjprfCVHmfmNDUrSmqQsU1"
ARG OPENMETRICS_VERSION=0.1.2
ARG RLN_VERSION
ARG LIBP2P_VERSION

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
    && { [ -z "${LIBP2P_VERSION}" ] || logosctl install libp2p_module --version "${LIBP2P_VERSION}" -y; } \
    && logosctl package ls \
    && logosctl daemon stop \
    && while logosctl status > /dev/null 2>&1; do sleep 1; done \
    && rm -rf /var/lib/logos/logs/* \
    && rm -rf /home/ubuntu/.logos_storage

# logosctl starts a storage node with the daemon, in ~/.logos_storage. The build
# step above started one too; its key is removed so containers do not share it,
# and the directory moves into the session where a volume can keep it.
RUN mkdir -p /var/lib/logos/storage && ln -s /var/lib/logos/storage /home/ubuntu/.logos_storage

# `docker run <image> logos-node` runs a node; see the README.
ENV LOGOS_NODE_PEERS=${BLOCKCHAIN_PEERS}
COPY logos-node /usr/local/bin/logos-node
EXPOSE 3000/udp 3400/udp 8090/udp 8091/tcp 9000/udp 30303/tcp 30303/udp 9464/tcp
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s CMD ["logos-node", "health"]

CMD ["logosctl", "daemon", "start"]
