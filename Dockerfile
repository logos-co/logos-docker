# Stage 1: Build
FROM nixos/nix:2.34.1 AS builder
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
WORKDIR /app

RUN nix build 'github:logos-co/logos-logoscore-cli/ab6365eae7920ebf20b16f91b06295be55d55821#cli-appimage' --out-link ./logoscore --refresh
RUN nix build 'github:logos-co/logos-package-manager/2b4b72087154dd4d6f691ac2527e06e0dadaef4d#cli-appimage' --out-link ./package-manager --refresh
RUN nix build 'github:logos-co/logos-package-downloader/172a518450f74da820232a51cc31dd6af8d190a7#cli-appimage' --out-link ./package-downloader --refresh

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

RUN mkdir -p /etc/logos/blockchain /etc/logos/persistence && chown -R ubuntu:ubuntu /etc/logos

USER ubuntu
WORKDIR /home/ubuntu

RUN mkdir packages \
    && lgpd download delivery_module --version 1.1.0 --output ./packages \
    && lgpd download storage_module --version 1.0.0 --output ./packages \
    && lgpd download liblogos_blockchain_module --version 1.0.0 --output ./packages \
    && lgpd download openmetrics --version 0.1.0 --output ./packages

RUN mkdir modules \
    && lgpm install --dir ./packages --modules-dir ./modules

CMD ["logoscore", "-D", "-m", "/home/ubuntu/modules", "--persistence-path", "/etc/logos/persistence"]