# Stage 1: Build
FROM nixos/nix:2.34.1 AS builder
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf
WORKDIR /app

RUN nix build 'github:logos-co/logos-logoscore-cli/454e0696e9417acaac2c0b6dc1f209b5838c7635#cli-appimage' --out-link ./logoscore --refresh
RUN nix build 'github:logos-co/logos-package-manager/a59f14eb1045df4364d8ce795498ad2e0b323e1e#cli-appimage' --out-link ./package-manager --refresh
RUN nix build 'github:logos-co/logos-package-downloader/9f9531b82493b01c3ede0b6b5be04a7422fc6a6e#cli-appimage' --out-link ./package-downloader --refresh

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

RUN mkdir -p /etc/logos/blockchain && chown -R ubuntu:ubuntu /etc/logos

USER ubuntu
WORKDIR /home/ubuntu

RUN mkdir packages \
    && lgpd download logos-delivery-module --release build-20260422-1bfdb89-84 --output ./packages \
    && lgpd download logos-storage-module --release build-20260422-1bfdb89-84 --output ./packages \
    && lgpd download logos-blockchain-module --release build-20260422-1bfdb89-84 --output ./packages

RUN mkdir modules \
    && lgpm install --dir ./packages --modules-dir ./modules

CMD ["logoscore", "-D", "-m", "/home/ubuntu/modules"]