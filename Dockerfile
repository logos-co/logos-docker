# Stage 1: Build
FROM nixos/nix:2.34.1 AS builder
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
WORKDIR /app

RUN nix build 'github:logos-co/logos-logoscore-cli/8720885dd821cd63eb1da00c842328cbfd1fe5fa#cli-appimage' --out-link ./logoscore --refresh
RUN nix build 'github:logos-co/logos-package-manager/202af6fa0f0f4493bc59c8a609dff9326f78a18d#cli-appimage' --out-link ./package-manager --refresh
RUN nix build 'github:logos-co/logos-package-downloader/02503323b46ec35148ad00cd636d46ac8f2506b5#cli-appimage' --out-link ./package-downloader --refresh

RUN mkdir -p /app-final/logos \
    && cp -rL ./logoscore/* /app-final/logos/ \
    && cp -rL ./package-manager/* /app-final/logos/ \
    && cp -rL ./package-downloader/* /app-final/logos/

# Stage 2: Runtime
FROM ubuntu:24.04
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl netcat-openbsd && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app-final/logos /app/logos
RUN cd /app/logos && for app in logoscore lgpm lgpd; do \
        chmod a+rx "$app.AppImage" \
        && "./$app.AppImage" --appimage-extract > /dev/null \
        && mv squashfs-root "$app" \
        && rm "$app.AppImage"; \
    done
RUN ln -s /app/logos/logoscore/AppRun /bin/logoscore \
    && ln -s /app/logos/lgpm/AppRun /bin/lgpm \
    && ln -s /app/logos/lgpd/AppRun /bin/lgpd

RUN mkdir -p /var/lib/logos/blockchain /var/lib/logos/config /var/lib/logos/persistence \
    && usermod -u 10000 ubuntu && groupmod -g 10000 ubuntu \
    && chown -R ubuntu:ubuntu /var/lib/logos /home/ubuntu

USER ubuntu
WORKDIR /home/ubuntu

ARG DELIVERY_VERSION
ARG STORAGE_VERSION
ARG BLOCKCHAIN_VERSION
ARG OPENMETRICS_VERSION
ARG RLN_VERSION
ARG LEZ_RLN_VERSION
ARG LEZ_CORE_VERSION

ARG MODULES_REPO=https://raw.githubusercontent.com/logos-co/logos-modules-release/refs/heads/main/logos-repo.json
ARG RLN_REPO=https://github.com/logos-co/logos-rln-modules/releases/download/index/logos-repo.json

ENV LGPD_CONFIG=/home/ubuntu/repositories.json
RUN for repo in "${MODULES_REPO}" "${RLN_REPO}"; do \
        lgpd --config ${LGPD_CONFIG} --json repo list | grep -qF "${repo}" \
            || lgpd --config ${LGPD_CONFIG} repo add "${repo}"; \
    done

RUN mkdir packages \
    && if [ -n "${DELIVERY_VERSION}" ]; then lgpd --config ${LGPD_CONFIG} --repo ${MODULES_REPO} download delivery_module --version ${DELIVERY_VERSION} --output ./packages; fi \
    && if [ -n "${STORAGE_VERSION}" ]; then lgpd download storage_module --version ${STORAGE_VERSION} --output ./packages; fi \
    && if [ -n "${BLOCKCHAIN_VERSION}" ]; then lgpd download blockchain_module --version ${BLOCKCHAIN_VERSION} --output ./packages; fi \
    && if [ -n "${RLN_VERSION}" ]; then lgpd --config ${LGPD_CONFIG} --repo ${RLN_REPO} download liblogos_rln_module --version ${RLN_VERSION} --output ./packages; fi \
    && if [ -n "${LEZ_RLN_VERSION}" ]; then lgpd --config ${LGPD_CONFIG} --repo ${RLN_REPO} download liblogos_lez_rln_module --version ${LEZ_RLN_VERSION} --output ./packages; fi \
    && if [ -n "${LEZ_CORE_VERSION}" ]; then lgpd --config ${LGPD_CONFIG} --repo ${RLN_REPO} download lez_core --version ${LEZ_CORE_VERSION} --output ./packages; fi \
    && lgpd download openmetrics --version ${OPENMETRICS_VERSION} --output ./packages

RUN mkdir modules \
    && lgpm install --dir ./packages --modules-dir ./modules

CMD ["logoscore", "-D", "-m", "./modules", "--config-dir", "/var/lib/logos/config", "--persistence-path", "/var/lib/logos/persistence"]