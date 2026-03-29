# logos-docker

## Quick start

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git && \
docker run \
  -p 3000:3000/udp \
  -p 3400:3400/udp \
  -p 8080:8080 \
  logos
```

Or, from a local checkout:

```bash
docker build -t logos .
docker run \
  -p 3000:3000/udp \
  -p 3400:3400/udp \
  -p 8080:8080 \
  logos
```

---

## Dev helper: `run.sh`

For development, the repository provides a helper script that wraps `docker build` and `docker run`:

```bash
./run.sh
```

See available options:

```bash
./run.sh --help
```

Preview commands without executing:

```bash
DRY_RUN=1 ./run.sh
```

Note: `run.sh` is a developer convenience script. It is not a final or stable interface and may change.

