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

## Running a node

`logos-node` runs a testnet node: it starts the daemon, loads the modules and
makes the calls from the [Run a Logos node](https://docs.logos.co/run-a-node)
guide, and serves OpenMetrics on port 9464.

```bash
docker run -d --name logos-node \
  -v logos-blockchain:/var/lib/logos/blockchain \
  -v logos-storage:/var/lib/logos/storage \
  -v logos-persistence:/var/lib/logos/persistence \
  -p 3000:3000/udp -p 8090:8090/udp -p 8091:8091/tcp -p 9000:9000/udp \
  -p 30303:30303/tcp -p 30303:30303/udp -p 127.0.0.1:9464:9464 \
  -e LOGOS_NODE_PUBLIC_IP=<public-ip> \
  logos logos-node
```

These are the ports the guide opens. On its first start the node generates
`user_config.yaml` and `keystore.yaml` in `/var/lib/logos/blockchain`, readable
by the node user only, and reuses them on every later start. Keep the volumes:
`logos-blockchain` holds the node's keys, chain state and hourly
`logos-blockchain.log.*` files, and `logos-storage` the storage node's identity
and data.

| Variable | Default | Meaning |
|---|---|---|
| `LOGOS_NODE_MODULES` | `blockchain_module storage_module delivery_module` | Modules to start, in order |
| `LOGOS_NODE_PEERS` | the `BLOCKCHAIN_PEERS` build arg, the testnet peers the guide lists | Blockchain bootstrap peers, space- or comma-separated, used when generating the config |
| `LOGOS_NODE_PUBLIC_IP` | unset | Public IPv4 delivery advertises; unset, delivery picks an address itself, which behind Docker's NAT is the container's own |
| `LOGOS_NODE_METRICS_PORT` | `9464` | OpenMetrics port; empty disables it |

Give the container time to stop: a node in the middle of starting can need more
than Docker's default 10 seconds, so use `docker stop -t 60` (or
`stop_grace_period: 60s` in Compose).

A module that fails to start is reported in `docker logs` and skipped. The
container's health check runs `logos-node health`, which also checks the
blockchain API when this container started the blockchain module. After a
restart the node replays its stored blocks before the API answers, about 10
minutes for 20,000 blocks, and the check passes while it does.

### Monitoring

[`monitoring/`](monitoring) runs the node with Prometheus and Grafana:

```bash
LOGOS_NODE_PUBLIC_IP=<public-ip> docker compose -f monitoring/compose.yaml up -d
```

Grafana is on http://localhost:3001 (user `admin`, password
`$GRAFANA_ADMIN_PASSWORD`, default `admin`) with the "Logos node" dashboard:
tip and finalized height, slots behind the wall clock, peers, blocks imported
and the delivery and storage modules. Prometheus is on http://localhost:9090,
with these alerts in [`alerts.yaml`](monitoring/prometheus/alerts.yaml):

| Alert | Fires when |
|---|---|
| `LogosNodeDown` | the metrics endpoint does not answer for 30 minutes; a restart keeps it dark while the blockchain module replays the stored chain, about 23 minutes for 93,000 blocks |
| `LogosModuleNotReporting` | a module that reported in the last 7 days stops reporting, while the endpoint is up |
| `LogosBlockchainBehind` | the tip is more than 300 slots (5 minutes) behind the wall clock and the gap has not shrunk in 15 minutes |
| `LogosNoPeers` | the blockchain, delivery or storage module has no peers for 5 minutes |

Prometheus evaluates them but sends them nowhere; add an Alertmanager to be
notified. The stack runs its own node with its own volumes, so stop a node
started with `docker run` first: both publish the same ports. The dashboard,
which asks for its Prometheus data source on import, and the alerts work for any
Prometheus that scrapes a node's openmetrics endpoint as `job="logos-node"`. Test
the alerts with `promtool test rules monitoring/prometheus/alerts.test.yaml`.

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

Setting `RLN_VERSION` adds [`liblogos_rln_module`](https://github.com/logos-co/logos-rln-modules)
(RLN membership management); its dependencies are installed with it, and
loading it loads them too:

```bash
docker exec logos logosctl module load liblogos_rln_module
```

Setting `LIBP2P_VERSION` adds [`libp2p_module`](https://github.com/logos-co/logos-libp2p-module),
which the delivery module uses to host Kademlia service discovery when its
config sets `"pluginKadDiscovery": true`.

Each module version is a build arg — `DELIVERY_VERSION`, `STORAGE_VERSION`,
`BLOCKCHAIN_VERSION`, `OPENMETRICS_VERSION`, `RLN_VERSION`, `LIBP2P_VERSION`.
Leave one empty to exclude that module. `RLN_VERSION` and `LIBP2P_VERSION` are
empty by default.

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
- `/var/lib/logos/storage/` — the storage node `logosctl` starts with the daemon
  (`~/.logos_storage` links here)
- `/var/lib/logos/daemon/` — daemon config and runtime state

The daemon logs to stdout, so `docker logs` has it; the blockchain module also
writes hourly log files next to its state.

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
