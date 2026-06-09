# Running the Logos image: load modules and serve OpenMetrics

The `logos-docker` image bundles the three Logos CLIs (`logoscore`, `lgpm`,
`lgpd`) and ships a set of modules pre-installed under
`/home/ubuntu/modules` — `delivery_module`, `storage_module`,
`liblogos_blockchain_module`, and the [`openmetrics`](https://github.com/logos-co/openmetrics-module)
scraper. The container's default `CMD` starts a `logoscore` daemon over that
modules directory; everything else is done by talking to that daemon.

This doc-test drives the image end-to-end:

1. **Build** the image and **run** it as a detached container, publishing the
   OpenMetrics port so it is reachable from the host.
2. **Load** the bundled modules into the running daemon.
3. **Initialize** `openmetrics` — load it and `start` its HTTP server with a
   config JSON naming the modules to scrape.
4. **Scrape** `/metrics` from outside the container and check `/health`.

> **About the metrics output.** `openmetrics` is a pure passthrough: on each
> scrape it calls every listed module's `collectMetrics()` and renders the
> aggregated result. None of the modules bundled in this image implement
> `collectMetrics()` yet, so `/metrics` currently serves only the OpenMetrics
> framing and ends with `# EOF` — no series. The moment a bundled module starts
> implementing `collectMetrics()`, its series appear here automatically with a
> `module="<name>"` label. For a worked provider example, see the
> [openmetrics-module doc-test](https://github.com/logos-co/openmetrics-module/tree/master/doctests).

**What you'll build:** The `logos-docker` image, run as a container with its OpenMetrics endpoint published to the host; the bundled modules loaded and `openmetrics` serving `/metrics`.

**What you'll learn:**

- How to build and run the image from the Dockerfile in this repo
- How to publish the OpenMetrics port so the endpoint is reachable from outside the container
- How to load the pre-installed modules into the running `logoscore` daemon
- How to initialize `openmetrics` (`load-module` + `call openmetrics start`) and scrape `/metrics`

## Prerequisites

- **Docker** — to build and run the image.
- **curl** — to scrape the published endpoint from the host.
- A network connection — the first build downloads the Nix builder layer and builds the CLIs, which can take several minutes.

---

## Step 1: Build and run the image

The image is built straight from this repo. The Dockerfile is a multi-stage
build: a `nixos/nix` stage builds the three CLIs as AppImages, and an
`ubuntu` stage extracts them, downloads the module packages with `lgpd`, and
installs them with `lgpm`. The default `CMD` is
`logoscore -D -m /home/ubuntu/modules --persistence-path /etc/logos/persistence`.

### 1.1 Build the image

Build from the repo URL (the same command the README documents). The
doc-test runner pins the ref to the commit under test via
`$LOGOS_DOCKER_REF`.

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git
```

Confirm the image was built (it's a Linux image):

```bash
docker image inspect logos --format '{{.Os}}/{{.Architecture}}'
```

### 1.2 Run the container with the OpenMetrics port published

Run it detached (`-d`) and publish the port `openmetrics` will listen on
(`-p 9090:9090`) so the endpoint is reachable from the host. The daemon
starts via the image's `CMD`.

```bash
docker run -d -p 9090:9090 --name logos logos
```

```bash
sleep 5
```

### 1.3 Confirm the daemon is up

```bash
docker exec logos logoscore status
```

---

## Step 2: Load the modules

The modules ship pre-installed under `/home/ubuntu/modules`. Loading a
module makes it live in the running daemon (dependencies are resolved
automatically).

### 2.1 List what's installed

```bash
docker exec logos lgpm --modules-dir /home/ubuntu/modules list
```

### 2.2 Load the bundled modules

```bash
docker exec logos logoscore load-module delivery_module
docker exec logos logoscore load-module storage_module
docker exec logos logoscore load-module liblogos_blockchain_module
```

---

## Step 3: Initialize OpenMetrics

Load the `openmetrics` module, then `start` its HTTP server with a config
JSON: the port to listen on and the modules to scrape. The JSON is passed as
a single argument so it reaches the module intact.

### 3.1 Load the openmetrics module

```bash
docker exec logos logoscore load-module openmetrics
```

### 3.2 Start the OpenMetrics server

Bind it to `9090` — the port we published — so the endpoint is reachable
from the host. `start` returns `1` on success.

```bash
docker exec logos logoscore call openmetrics start '{"port":9090,"modules":["delivery_module","storage_module","liblogos_blockchain_module"]}'
```

```bash
sleep 1
```

### 3.3 getInfo reports what it's serving

`getInfo()` returns its status as a JSON string, so `logoscore` delivers
it as an escaped string inside the `result` field.

```bash
docker exec logos logoscore call openmetrics getInfo
```

---

## Step 4: Scrape /metrics from the host

Because the port is published, Prometheus — or a plain `curl` from the host
— can scrape the endpoint without entering the container.

### 4.1 Scrape /metrics

The document is valid OpenMetrics and ends with `# EOF`. There are no
series yet because none of the bundled modules implement
`collectMetrics()` — once one does, its series appear here automatically.

```bash
curl http://localhost:9090/metrics
```

### 4.2 Check /health

```bash
curl http://localhost:9090/health
```

---

## Step 5: Clean up

Stop and remove the container (this also stops the daemon and the
OpenMetrics server inside it).

### 5.1 Remove the container

```bash
docker rm -f logos
```

---

## Recap

| Step | Command | What it proves |
| ---- | ------- | -------------- |
| Build & run | `docker build` / `docker run -d -p 9090:9090` | the image builds and the daemon comes up with the metrics port published |
| Load | `logoscore load-module <name>` | the bundled modules load into the running daemon |
| Initialize | `logoscore call openmetrics start '{…}'` | `openmetrics` stands up its HTTP server on the published port |
| Scrape | `curl http://localhost:9090/metrics` | the endpoint is reachable from outside the container and serves valid OpenMetrics |

The `openmetrics` endpoint is now reachable from the host on `:9090`. Point a
Prometheus scrape at it, and as the bundled modules grow `collectMetrics()`
implementations their series will show up automatically, each labelled with
`module="<name>"`.
