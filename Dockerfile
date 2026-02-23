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
RUN mkdir modules \
    && ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-waku-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/waku_config.json .

# Logos Storage
RUN ./package-manager/bin/lgpm --modules-dir ./modules/ install logos-storage-module
ADD https://raw.githubusercontent.com/logos-co/node-configs/refs/heads/master/storage_config_test.json .


# Logos Blockchain
ENV LOGOS_BLOCKCHAIN_CONFIG_PATH=~/logos_blockchain_config/node_config.yaml
ENV LOGOS_BLOCKCHAIN_PARAMETERS={
  "initial_peers": [
    "/ip4/65.109.51.37/udp/3001/quic-v1/p2p/12D3KooWNzrYagh1S3EbmPpywFkLK2gGFApFaHYc4VgvqMGLLmeP",
    "/ip4/65.109.51.37/udp/3002/quic-v1/p2p/12D3KooWH5pQ7KeLEZJsc933UXBXPQDMHLa897opPP9YaS3kEMi1",
    "/ip4/65.109.51.37/udp/3003/quic-v1/p2p/12D3KooWGdkKHAQ6ZRQ7YW6zhMgMQjAaidyp4LuATNgKUtmB68GU",
    "/ip4/65.109.51.37/udp/3000/quic-v1"
  ],
  "output": $LOGOS_BLOCKCHAIN_CONFIG_PATH
}

# Run
CMD ./logos/bin/logoscore -m ./modules --load-modules "waku_module,storage_module, logos_blockchain_module" \
	-c "waku_module.initWaku(@waku_config.json)" \
	-c "waku_module.startWaku()" \
	-c "storage_module.init(@storage_config_test.json)" \
	-c "storage_module.start()" \
	-c "storage_module.importFiles('/tmp/storage_files')" \
	-c "logos_blockchain_module.generate_user_config_from_str($LOGOS_BLOCKCHAIN_PARAMETERS)" \
	-c "logos_blockchain_module.start($LOGOS_BLOCKCHAIN_CONFIG_PATH)"
