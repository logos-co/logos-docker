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
RUN nix bundle --bundler github:logos-co/nix-bundle-dir/1ecb9662145a1ad84007a970b4bef50a4af159c9#qtApp github:logos-co/logos-liblogos/19d29d4ef99292d9285b3a561cb7ea8029be3b74 --out-link ./logos --refresh
RUN nix bundle --bundler github:logos-co/nix-bundle-dir/1ecb9662145a1ad84007a970b4bef50a4af159c9#qtApp github:logos-co/logos-package-manager-module/4c49df4c42bfb5bc4a6a27e526ab9755baa064a9#cli --out-link ./package-manager --refresh

# Setup modules and config
RUN mkdir modules

## Delivery
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

## Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/storage_config_test.json .

## Blockchain
### Configuration
RUN mkdir -p /etc/logos/blockchain

### Install
RUN ./package-manager/bin/lgpm --release="build-20260303-26c5b47-57" --modules-dir ./modules/ install logos-blockchain-module

### Make circuits executable
RUN test -d ./modules/liblogos_blockchain_module/circuits && \
    find ./modules/liblogos_blockchain_module/circuits -name witness_generator -exec chmod u+x {} + && \
    find ./modules/liblogos_blockchain_module/circuits -name prover -exec chmod u+x {} + && \
    find ./modules/liblogos_blockchain_module/circuits -name verifier -exec chmod u+x {} +

### Ports
#### Swarm
EXPOSE 3000/udp
#### Blend
EXPOSE 3400/udp
#### REST
EXPOSE 8080/tcp

### Environment
ENV LOGOS_BLOCKCHAIN_DEPLOYMENT=devnet
ENV LOGOS_BLOCKCHAIN_CONFIG_PATH=/etc/logos/blockchain/node_config.yaml
ENV LOGOS_BLOCKCHAIN_PARAMETERS='{\
  "initial_peers": [\
    "/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWCvKvaztLMGiQX3Nm3K3Nh7SA4bBHVN2drB4TQHLjamzQ",\
    "/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWG2xMrHB6Bck5ZP7idprtBB26RCH16bePxp1NkGsUNvxx",\
    "/ip4/65.109.51.37/udp/3003/quic-v1/p2p/12D3KooWB8BcfD96TTztJgmvBZ7thBS94LZxvGBiyAdGj5bLcRAU",\
    "/ip4/65.109.51.37/udp/3000/quic-v1/p2p/12D3KooWLzWAnx4b4inFDYkwS6j6YTffJYTjbLYvqQXcFgaQkaGq"\
  ],\
  "output": "/etc/logos/blockchain/node_config.yaml"\
}'
RUN nix shell nixpkgs#jq -c sh -c 'printf "%s\n" "$LOGOS_BLOCKCHAIN_PARAMETERS" | jq -e . >/dev/null'  # Validate JSON

# Entrypoint
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

CMD ["/entrypoint.sh"]

