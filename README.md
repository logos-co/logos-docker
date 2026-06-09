# logos-docker

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git && docker run logos
```

or, from a local checkout:

```bash
docker build -t logos .
docker run logos
```

The default `CMD` is `logoscore -D -m /home/ubuntu/modules --persistence-path /etc/logos/persistence`.

## What's inside

Three CLIs are installed and reachable on `$PATH`:

- `logoscore` — Logos core runtime
- `lgpm` — Logos package manager
- `lgpd` — Logos package downloader

The image ships with the delivery, storage, and blockchain modules plus the
[`openmetrics`](https://github.com/logos-co/openmetrics-module) scraper
pre-installed under `/home/ubuntu/modules`.

## Runtime user and layout

The container runs as the unprivileged `ubuntu` user. `/app` is root-owned and holds the extracted binaries; everything writable at runtime lives elsewhere:

- `/home/ubuntu/packages/` — downloaded `.lgx` packages
- `/home/ubuntu/modules/` — installed modules (passed to `logoscore` via `-m`)
- `/etc/logos/blockchain/` — blockchain state written at runtime
- `/etc/logos/persistence/` — logoscore module instance persistence (passed via `--persistence-path`)

## Serving OpenMetrics

The bundled [`openmetrics`](https://github.com/logos-co/openmetrics-module)
module serves a Prometheus-scrapeable `/metrics` endpoint. Run the container with
the port published, load the modules, then load and `start` `openmetrics`:

```bash
docker run -d -p 9090:9090 --name logos logos
docker exec logos logoscore load-module delivery_module
docker exec logos logoscore load-module storage_module
docker exec logos logoscore load-module liblogos_blockchain_module
docker exec logos logoscore load-module openmetrics
docker exec logos logoscore call openmetrics start '{"port":9090,"modules":["delivery_module","storage_module","liblogos_blockchain_module"]}'
curl http://localhost:9090/metrics
```

For a complete, runnable walkthrough — build, run, load the modules, initialize
`openmetrics`, and scrape `/metrics` from the host — see the doc-test in
[`doctests/`](doctests/) ([rendered](doctests/outputs/openmetrics.md); run it with
`cd doctests && ./run.sh`).

## Persisting state across restarts

Mount named volumes to keep state across container restarts:

- `/etc/logos/blockchain` — blockchain state
- `/etc/logos/persistence` — logoscore module instance data (`--persistence-path`)

```bash
docker run \
  -v logos-blockchain:/etc/logos/blockchain \
  -v logos-persistence:/etc/logos/persistence \
  logos
```

Use **named volumes** (as above) rather than host bind mounts. The container runs
as the unprivileged `ubuntu` user (uid 1000), and these paths are created
`ubuntu`-owned in the image — so a fresh named volume inherits that ownership and
is writable with no `chown`. A host bind mount instead keeps the host path's
ownership, which may not be writable by the in-container `ubuntu` user; if you
must bind-mount, `chown 1000:1000` the host directory first.
