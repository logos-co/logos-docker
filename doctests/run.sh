#!/usr/bin/env bash
#
# Execute the logos-docker openmetrics doc-test end-to-end and regenerate its Markdown.
#
# Spec:
#   - openmetrics.test.yaml   builds the logos image from this repo, runs it with
#                             the OpenMetrics port published, loads the bundled
#                             modules, initializes openmetrics, and scrapes
#                             /metrics from the host.
#
# The runner is the shared `doctest` CLI (https://github.com/logos-co/logos-doctest),
# invoked directly via its flake. `doctest run` executes every command in a temp
# directory and asserts on the output; `doctest generate` renders the spec to
# Markdown under outputs/; `doctest clean` strips build artifacts.
#
# To run against a local logos-doctest checkout instead of the published flake,
# set DOCTEST, e.g.:  DOCTEST="nix run path:../../logos-doctest --" ./run.sh
#
# Requires Docker and curl on the host.
#
set -euo pipefail

cd "$(dirname "$0")"

# The doctest CLI. Override by exporting DOCTEST (space-separated command).
read -r -a DOCTEST <<< "${DOCTEST:-nix run github:logos-co/logos-doctest --}"
OUTPUT_DIR="./outputs"
SPECS=(
  "openmetrics.test.yaml"
)

# The spec builds `github:logos-co/logos-docker#${LOGOS_DOCKER_REF}` (a docker
# build from the GitHub repo at this ref). Default to the current commit so a
# local run tests exactly what's checked out.
#
# Note: docker fetches the ref from the GitHub remote, so $LOGOS_DOCKER_REF must
# be pushed. A local-only / uncommitted HEAD won't resolve; export
# LOGOS_DOCKER_REF=master (or push first) in that case.
export LOGOS_DOCKER_REF="${LOGOS_DOCKER_REF:-$(git rev-parse HEAD)}"
echo "==> Building image from logos-docker ref ${LOGOS_DOCKER_REF}"

# Remove any container left over from a previous run so --name doesn't collide.
docker rm -f logos-doctest >/dev/null 2>&1 || true

echo "==> Clearing previous ${OUTPUT_DIR}/"
if [ -e "${OUTPUT_DIR}" ]; then
  chmod -R u+w "${OUTPUT_DIR}" 2>/dev/null || true
fi
rm -rf "${OUTPUT_DIR}"
mkdir -p "${OUTPUT_DIR}"

for SPEC in "${SPECS[@]}"; do
  name="$(basename "${SPEC%.test.yaml}")"
  spec_out="${OUTPUT_DIR}/${name}"
  mkdir -p "${spec_out}"

  echo "==> Running ${SPEC} into ${spec_out}/"
  "${DOCTEST[@]}" run "${SPEC}" \
    --verbose \
    --continue-on-fail \
    --output-dir "${spec_out}/"

  echo "==> Generating ${OUTPUT_DIR}/${name}.md"
  "${DOCTEST[@]}" generate "${SPEC}" \
    -o "${OUTPUT_DIR}/${name}.md"
done

echo "==> Cleaning build artifacts from ${OUTPUT_DIR}/"
"${DOCTEST[@]}" clean "${OUTPUT_DIR}" --verbose

echo "==> Done. Rendered docs are in ${OUTPUT_DIR}/"
