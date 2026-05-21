# logos-docker

OCI container image for Logos, built deterministically with Nix.

## Build and run

```bash
nix build github:logos-co/logos-docker
docker load < result
docker run logos:latest
```

Or, from a local checkout:

```bash
nix build
docker load < result
docker run logos:latest
```

The default `CMD` is `logoscore -D -m /modules`.

## What's inside

Three CLIs are installed and reachable on `$PATH`:

- `logoscore` — Logos core runtime
- `lgpm` — Logos package manager
- `lgpd` — Logos package downloader

The image ships with the delivery, storage, and blockchain modules pre-installed under `/modules`.

## Image layout

```
/app/logos/bin/   — CLI binaries (logoscore, lgpm, lgpd)
/app/logos/lib/   — bundled shared libraries
/modules/         — installed module plugins
/etc/logos/blockchain/ — blockchain state (volume mount point)
```

## Persisting blockchain state

Mount a named volume on `/etc/logos/blockchain` to keep state across container restarts:

```bash
docker run -v logos-blockchain:/etc/logos/blockchain logos:latest
```

## How it works

The image is built entirely within Nix using `dockerTools.buildLayeredImage`. Each CLI
tool is included as a self-contained directory bundle (`#cli-bundle-dir` output), and
modules are pre-installed via `#install-portable` outputs. No Dockerfile, no AppImage
extraction, no runtime downloads during build.

## Updating pinned versions

Edit `flake.nix` to update the pinned revisions of `logos-logoscore-cli`,
`logos-package-manager`, `logos-package-downloader`, and the module repos. Then run:

```bash
nix flake update
nix build
```
