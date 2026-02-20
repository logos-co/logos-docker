# logos-docker

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git && docker run logos
```

or, from a local checkout:

```bash
docker build -t logos .
docker run logos
```

If need to override env vars. Please `cp .env.example .env` and adapt .env as you wish.

