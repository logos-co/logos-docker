# logos-docker

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git && docker run logos
```

or, from a local checkout:

```bash
docker build -t logos .
docker run logos
```

The default `CMD` is `logosctl daemon start`.

## What's inside

The image ships [`logosctl`](https://github.com/logos-co/logos-logoscore-cli/blob/master/docs/logosctl.md)
on `$PATH` — the Logos module runtime with package management built in. Its
release is the `LOGOSCTL_VERSION` build arg.

`LOGOSCTL_CONFIG_DIR` is set to `/var/lib/logos`, so every `logosctl` command,
including `docker exec`, acts on that session without extra flags. Its daemon
config is [`config.yaml`](config.yaml).

The image ships with the delivery, storage, and blockchain modules plus the
[`openmetrics`](https://github.com/logos-co/openmetrics-module) scraper
pre-installed under `/var/lib/logos/modules`:

```bash
docker exec logos logosctl package ls
```

RLN comes in two generations. Set the one named in your delivery_module's
`optional_dependencies`, never both (the build fails if both are set):

- `RLN_MODULE_VERSION` adds [`rln_module`](https://github.com/logos-co/logos-rln-module),
  the RLN module of delivery_module 0.4.0-rc.2 and later, together with its
  dependencies `rln_lez_module` and `membership_allocation_client_module`.
  Those come at the catalog's default versions unless `RLN_LEZ_MODULE_VERSION`
  or `MEMBERSHIP_ALLOCATION_CLIENT_VERSION` pins them; both pins are ignored
  without `RLN_MODULE_VERSION`. These modules are only in
  [`logos-modules-dev`](#building-against-another-catalog), so set
  `MODULES_REPO` too. Loading `delivery_module` loads `rln_module` with it,
  as an optional dependency.
- `RLN_VERSION` adds [`liblogos_rln_module`](https://github.com/logos-co/logos-rln-modules),
  which delivery_module used before 0.4.0-rc.2; its dependencies are installed
  with it, and loading it loads them too:

```bash
docker exec logos logosctl module load liblogos_rln_module
```

Setting `LIBP2P_VERSION` adds [`libp2p_module`](https://github.com/logos-co/logos-libp2p-module),
which the delivery module uses to host Kademlia service discovery when its
config sets `"pluginKadDiscovery": true`.

Each module version is a build arg — `DELIVERY_VERSION`, `STORAGE_VERSION`,
`BLOCKCHAIN_VERSION`, `OPENMETRICS_VERSION`, `RLN_VERSION`,
`RLN_MODULE_VERSION`, `LIBP2P_VERSION`. Leave one empty to exclude that
module. The RLN and libp2p ones are empty by default.

## Building against another catalog

`MODULES_REPO` selects the catalog every module is pulled from; it is the only
catalog left enabled in the image. Point it at
[`logos-modules-dev`](https://github.com/logos-co/logos-modules-dev), which
publishes one build per commit, to get a continuous build instead of a release:

```bash
docker build \
  --build-arg MODULES_REPO=https://raw.githubusercontent.com/logos-co/logos-modules-dev/refs/heads/main/logos-repo.json \
  -t logos .
```

## Runtime user and layout

The container runs as the unprivileged `ubuntu` user (uid 10000). `/app` is
root-owned and holds the extracted `logosctl`; everything writable at runtime
lives in the session:

- `/var/lib/logos/modules/` — installed modules
- `/var/lib/logos/persistence/` — per-module instance persistence (`dirs.data`)
- `/var/lib/logos/blockchain/` — blockchain state
- `/var/lib/logos/daemon/` — daemon config and runtime state

The daemon logs to stdout only, so `docker logs` has everything.

## Serving OpenMetrics

The bundled [`openmetrics`](https://github.com/logos-co/openmetrics-module)
module serves a Prometheus-scrapeable `/metrics` endpoint. Run the container with
the port published, load the modules, then load and `start` `openmetrics`:

```bash
docker run -d -p 9090:9090 --name logos logos
docker exec logos logosctl module load delivery_module
docker exec logos logosctl module load storage_module
docker exec logos logosctl module load blockchain_module
docker exec logos logosctl module load openmetrics
docker exec logos logosctl call openmetrics start '{"port":9090,"modules":["delivery_module","storage_module","blockchain_module"]}'
curl http://localhost:9090/metrics
```

For a complete, runnable walkthrough — build, run, load the modules, initialize
`openmetrics`, and scrape `/metrics` from the host — see the doc-test in
[`doctests/openmetrics.test.yaml`](doctests/openmetrics.test.yaml). Run it with
`cd doctests && ./run.sh`, which also renders it to `doctests/outputs/openmetrics.md`.

## Persisting state across restarts

Mount named volumes to keep state across container restarts:

- `/var/lib/logos/blockchain` — blockchain state
- `/var/lib/logos/persistence` — module instance data

```bash
docker run \
  -v logos-blockchain:/var/lib/logos/blockchain \
  -v logos-persistence:/var/lib/logos/persistence \
  logos
```

Do not mount a volume over `/var/lib/logos` itself: it would hide the
pre-installed modules.

Use **named volumes** (as above) rather than host bind mounts. These paths are
created `ubuntu`-owned in the image, so a fresh named volume inherits that
ownership and is writable with no `chown`. A host bind mount instead keeps the
host path's ownership; if you must bind-mount, `chown 10000:10000` the host
directory first.
