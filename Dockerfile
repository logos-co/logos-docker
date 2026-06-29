# Stage 1: Build
FROM nixos/nix:2.34.1 AS builder
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
WORKDIR /app

RUN nix build 'github:logos-co/logos-logoscore-cli/bae0d5440af16932327969a2aed5e2bf5d0943b0#cli-appimage' --out-link ./logoscore --refresh
RUN nix build 'github:logos-co/logos-package-manager/205d6bb295c43e9432aef367dd32dac82e39bddf#cli-appimage' --out-link ./package-manager --refresh
RUN nix build 'github:logos-co/logos-package-downloader/b6f46e62b625c02a9251cd40682fbf8277177d67#cli-appimage' --out-link ./package-downloader --refresh

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

RUN mkdir packages \
    && if [ -n "${DELIVERY_VERSION}" ]; then lgpd download delivery_module --version ${DELIVERY_VERSION} --output ./packages; fi \
    && if [ -n "${STORAGE_VERSION}" ]; then lgpd download storage_module --version ${STORAGE_VERSION} --output ./packages; fi \
    && if [ -n "${BLOCKCHAIN_VERSION}" ]; then lgpd download blockchain_module --version ${BLOCKCHAIN_VERSION} --output ./packages; fi \
    && lgpd download openmetrics --version ${OPENMETRICS_VERSION} --output ./packages

RUN mkdir modules \
    && lgpm install --dir ./packages --modules-dir ./modules

CMD ["logoscore", "-D", "-m", "./modules", "--config-dir", "/var/lib/logos/config", "--persistence-path", "/var/lib/logos/persistence"]