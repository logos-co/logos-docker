# logos-docker

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git && docker run logos
```

or, from a local checkout:

```bash
docker build -t logos .
docker run logos
```

The default `CMD` is `logoscore -D -m /home/ubuntu/modules`.

## What's inside

Three CLIs are installed and reachable on `$PATH`:

- `logoscore` — Logos core runtime
- `lgpm` — Logos package manager
- `lgpd` — Logos package downloader

The image ships with the delivery, storage, and blockchain modules pre-installed under `/home/ubuntu/modules`.

## Runtime user and layout

The container runs as the unprivileged `ubuntu` user. `/app` is root-owned and holds the extracted binaries; everything writable at runtime lives elsewhere:

- `/home/ubuntu/packages/` — downloaded `.lgx` packages
- `/home/ubuntu/modules/` — installed modules (passed to `logoscore` via `-m`)
- `/etc/logos/blockchain/` — blockchain state written at runtime

## Persisting blockchain state

Mount a named volume on `/etc/logos/blockchain` to keep state across container restarts:

```bash
docker run -v logos-blockchain:/etc/logos/blockchain logos
```
