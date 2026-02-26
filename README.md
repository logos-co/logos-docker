# logos-docker

```bash
docker build -t logos https://github.com/logos-co/logos-docker.git && docker run -p 3000:3000/udp 3400:3400/udp 8080:8080 logos
```

or, from a local checkout:

```bash
docker build -t logos .
docker run \
  -p 3000:3000/udp \
  -p 3400:3400/udp \
  -p 8080:8080 \
  logos
```
