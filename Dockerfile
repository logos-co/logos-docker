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
RUN nix bundle --bundler github:logos-co/nix-bundle-dir/fix-applicationDirPath#qtApp      github:logos-co/logos-liblogos/properly-handle-portable-modules --out-link ./logos --refresh
RUN nix bundle --bundler github:logos-co/nix-bundle-dir/complete-qt-plugin-bundling#qtApp github:logos-co/logos-package-manager-module/properly-handle-portable-modules#cli --out-link ./package-manager --refresh

# Setup modules and config
RUN mkdir modules

## Delivery
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

## Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/storage_config_test.json .

## Blockchain
RUN mkdir -p /etc/logos/blockchain

RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-blockchain-module

RUN nix shell nixpkgs#patchelf -c sh -c "\
old=\$(patchelf --print-needed modules/liblogos_blockchain_module/liblogos_blockchain_module.so | grep logos_blockchain) && \
patchelf --replace-needed \"\$old\" liblogos_blockchain.so \
modules/liblogos_blockchain_module/liblogos_blockchain_module.so && \
patchelf --set-rpath '\$ORIGIN' \
modules/liblogos_blockchain_module/liblogos_blockchain_module.so \
"

# Swarm
EXPOSE 3000/udp
# Blend
EXPOSE 3400/udp
# REST
EXPOSE 8080/tcp

ENV LOGOS_BLOCKCHAIN_CONFIG_PATH=/etc/logos/blockchain/node_config.yaml
ENV LOGOS_BLOCKCHAIN_PARAMETERS='{\
  "initial_peers": [\
    "/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWNzrYagh1S3EbmPpywFkLK2gGFApFaHYc4VgvqMGLLmeP",\
    "/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWH5pQ7KeLEZJsc933UXBXPQDMHLa897opPP9YaS3kEMi1",\
    "/ip4/65.109.51.37/udp/3003/quic-v1/p2p/12D3KooWGdkKHAQ6ZRQ7YW6zhMgMQjAaidyp4LuATNgKUtmB68GU",\
    "/ip4/65.109.51.37/udp/3000/quic-v1"\
  ],\
  "output": "/etc/logos/blockchain/node_config.yaml"\
}'


# Entrypoint

COPY start.sh /start.sh
RUN chmod +x /start.sh

CMD ["/start.sh"]

