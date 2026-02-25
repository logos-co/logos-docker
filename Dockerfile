FROM ubuntu:24.04

# Install Nix dependencies
RUN apt-get update -y && apt-get install -y curl bzip2 gnupg
# Install Nix, ensuring it doesn't start a daemon in the container
RUN curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install linux --no-start-daemon --no-confirm --init none

# Add Nix to the PATH
ENV PATH="/nix/var/nix/profiles/default/bin:/nix/var/nix/profiles/default/sbin:/root/.nix-profile/bin:$PATH"

# Enable flakes
RUN echo "experimental-features = nix-command flakes" >> /etc/nix/nix.conf

WORKDIR /app

# Build logos and package manager
RUN nix bundle --bundler github:logos-co/nix-bundle-dir/complete-qt-plugin-bundling#qtApp github:logos-co/logos-liblogos/properly-handle-portable-modules --out-link ./logos --refresh
RUN nix bundle --bundler github:logos-co/nix-bundle-dir/complete-qt-plugin-bundling#qtApp github:logos-co/logos-package-manager-module/properly-handle-portable-modules#cli --out-link ./package-manager --refresh

# Setup modules and config
RUN mkdir modules \
    && ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

# Logos Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/storage_config_test.json .

# Run
CMD ["./logos/bin/logoscore", "-m", "./modules", "--load-modules", "waku_module,storage_module", "-c", "waku_module.initWaku(@waku_config.json)", "-c", "waku_module.startWaku()", "-c", "storage_module.init(@storage_config_test.json)", "-c", "storage_module.start()", "-c", "storage_module.importFiles('/tmp/storage_files')"]
