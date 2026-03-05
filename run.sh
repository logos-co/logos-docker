#!/bin/sh
set -eu

IMAGE_NAME="logos"

PRESET=""

DRY_RUN="${DRY_RUN:-0}"

# Container naming
CONTAINER_NAME=""
WITH_DEFAULT_CONTAINER_NAME=0

# Config mount
LB_DEFAULT_CONFIG_MOUNT_HOST="$PWD/.docker/volumes/etc/logos/blockchain"
LB_CONFIG_MOUNT_HOST=""
LB_WITH_DEFAULT_CONFIG_MOUNT=0

# Default ports
LB_DEFAULT_SWARM_PORT=3000
LB_DEFAULT_BLEND_PORT=3400
LB_DEFAULT_REST_PORT=8080

# Config paths
LB_DEPLOYMENT=""
LB_NODE_CONFIG=""

# Ports baseline
LB_WITH_DEFAULT_PORTS=1
LB_SWARM_PORT=""
LB_BLEND_PORT=""
LB_REST_PORT=""

NO_BUILD=0

usage() {
    cat << EOF
Usage:
  $(basename "$0") [options]

Container naming:

  --container-name NAME
  --with-default-container-name

Environment:

  DRY_RUN=1
EOF
}

run_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '+'
        printf ' %s' "$@"
        printf '\n'
    else
        "$@"
    fi
}

ensure_directory() {

    DIR="$1"

    [ -n "$DIR" ] || return 0

    if [ ! -d "$DIR" ]; then

        printf "Mount directory '%s' does not exist. Create it? [y/N] " "$DIR"

        CONFIRM=""
        read -r CONFIRM || CONFIRM=""

        case "$CONFIRM" in
            y | Y)
                run_cmd mkdir -p "$DIR"
                ;;
            *)
                echo "Aborted." >&2
                exit 1
                ;;
        esac

    else

        echo "Warning: mount directory '$DIR' already exists (reusing)." >&2

    fi

}

apply_preset() {

    case "$PRESET" in

        standalone)

            LB_WITH_DEFAULT_PORTS=0

            LB_DEPLOYMENT="/etc/logos/blockchain/standalone-deployment-config.yaml"
            LB_NODE_CONFIG="/etc/logos/blockchain/standalone-node-config.yaml"

            cat >&2 << EOF
[Preset: standalone]

Requires config mount.

EOF
            ;;

        "") ;;

        *)

            echo "Error: Unknown preset" >&2
            exit 2
            ;;

    esac

}

# Pass 1 preset extraction

SEEN_PRESET=0
ARGS_REMAINING=""

while [ $# -gt 0 ]; do

    case "$1" in

        --preset)

            [ $# -ge 2 ] || exit 2

            if [ "$SEEN_PRESET" -eq 1 ]; then
                exit 2
            fi

            SEEN_PRESET=1
            PRESET="$2"

            shift 2
            ;;

        *)

            ARGS_REMAINING="${ARGS_REMAINING}${1}
"
            shift
            ;;

    esac

done

apply_preset

IFS='
'
set -- $ARGS_REMAINING
unset IFS

# Pass 2 parsing

SEEN_LB_WITH_DEFAULT_PORTS=0
SEEN_LB_NO_DEFAULT_PORTS=0
SEEN_LB_MANUAL_PORTS=0

while [ $# -gt 0 ]; do

    case "$1" in

        -h | --help)

            usage
            exit 0
            ;;

        --container-name)

            [ $# -ge 2 ] || exit 2
            CONTAINER_NAME="$2"
            shift 2
            ;;

        --with-default-container-name)

            WITH_DEFAULT_CONTAINER_NAME=1
            shift
            ;;

        --lb-config-mount)

            [ $# -ge 2 ] || exit 2
            LB_CONFIG_MOUNT_HOST="$2"
            shift 2
            ;;

        --lb-with-default-config-mount)

            LB_WITH_DEFAULT_CONFIG_MOUNT=1
            shift
            ;;

        --lb-deployment)

            [ $# -ge 2 ] || exit 2
            LB_DEPLOYMENT="$2"
            shift 2
            ;;

        --lb-node-config)

            [ $# -ge 2 ] || exit 2
            LB_NODE_CONFIG="$2"
            shift 2
            ;;

        --lb-with-default-ports)

            SEEN_LB_WITH_DEFAULT_PORTS=1
            shift
            ;;

        --lb-no-default-ports)

            SEEN_LB_NO_DEFAULT_PORTS=1
            shift
            ;;

        --lb-swarm-port)

            [ $# -ge 2 ] || exit 2
            LB_SWARM_PORT="$2"
            SEEN_LB_MANUAL_PORTS=1
            shift 2
            ;;

        --lb-blend-port)

            [ $# -ge 2 ] || exit 2
            LB_BLEND_PORT="$2"
            SEEN_LB_MANUAL_PORTS=1
            shift 2
            ;;

        --lb-rest-port)

            [ $# -ge 2 ] || exit 2
            LB_REST_PORT="$2"
            SEEN_LB_MANUAL_PORTS=1
            shift 2
            ;;

        --no-build)

            NO_BUILD=1
            shift
            ;;

        *)

            echo "Unknown option: $1" >&2
            exit 2
            ;;

    esac

done

# Container name resolution

if [ "$WITH_DEFAULT_CONTAINER_NAME" -eq 1 ]; then
    CONTAINER_NAME="logos"
fi

# Port precedence

if [ "$SEEN_LB_MANUAL_PORTS" -eq 1 ]; then
    LB_WITH_DEFAULT_PORTS=0
elif [ "$SEEN_LB_NO_DEFAULT_PORTS" -eq 1 ]; then
    LB_WITH_DEFAULT_PORTS=0
elif [ "$SEEN_LB_WITH_DEFAULT_PORTS" -eq 1 ]; then
    LB_WITH_DEFAULT_PORTS=1
fi

# Mount resolution

if [ "$LB_WITH_DEFAULT_CONFIG_MOUNT" -eq 1 ]; then
    LB_CONFIG_MOUNT_HOST="$LB_DEFAULT_CONFIG_MOUNT_HOST"
fi

# Standalone validation

if [ "$PRESET" = "standalone" ] &&
    [ -z "$LB_CONFIG_MOUNT_HOST" ]; then
    echo "Error: standalone preset requires config mount." >&2
    exit 2
fi

# Build docker args

set -- run --rm

if [ -n "$CONTAINER_NAME" ]; then
    set -- "$@" --name "$CONTAINER_NAME"
fi

[ -n "$LB_DEPLOYMENT" ] &&
    set -- "$@" -e LOGOS_BLOCKCHAIN_DEPLOYMENT="$LB_DEPLOYMENT"

[ -n "$LB_NODE_CONFIG" ] &&
    set -- "$@" -e LOGOS_BLOCKCHAIN_CONFIG_PATH="$LB_NODE_CONFIG"

if [ "$LB_WITH_DEFAULT_PORTS" -eq 1 ]; then

    set -- "$@" \
        -p "$LB_DEFAULT_SWARM_PORT:$LB_DEFAULT_SWARM_PORT/udp" \
        -p "$LB_DEFAULT_BLEND_PORT:$LB_DEFAULT_BLEND_PORT/udp" \
        -p "$LB_DEFAULT_REST_PORT:$LB_DEFAULT_REST_PORT"

else

    [ -n "$LB_SWARM_PORT" ] &&
        set -- "$@" -p "$LB_SWARM_PORT:$LB_SWARM_PORT/udp"

    [ -n "$LB_BLEND_PORT" ] &&
        set -- "$@" -p "$LB_BLEND_PORT:$LB_BLEND_PORT/udp"

    [ -n "$LB_REST_PORT" ] &&
        set -- "$@" -p "$LB_REST_PORT:$LB_REST_PORT"

fi

[ -n "$LB_CONFIG_MOUNT_HOST" ] &&
    set -- "$@" -v "$LB_CONFIG_MOUNT_HOST:/etc/logos/blockchain"

# Execution

if [ -n "$CONTAINER_NAME" ] &&
    docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER_NAME"; then

    if [ "$DRY_RUN" -eq 1 ]; then

        echo "+ docker kill $CONTAINER_NAME"
        echo "+ docker rm $CONTAINER_NAME"

    else

        printf "Remove existing container '%s'? [y/N] " "$CONTAINER_NAME"

        CONFIRM=""
        read -r CONFIRM || CONFIRM=""

        case "$CONFIRM" in

            y | Y)

                docker kill "$CONTAINER_NAME" > /dev/null 2>&1 || true
                docker rm "$CONTAINER_NAME" > /dev/null 2>&1 || true
                ;;

            *)

                exit 1
                ;;

        esac

    fi

fi

if [ "$NO_BUILD" -eq 0 ]; then
    run_cmd docker build -t "$IMAGE_NAME" .
fi

ensure_directory "$LB_CONFIG_MOUNT_HOST"

if [ "$DRY_RUN" -eq 1 ]; then

    printf '+ docker'
    printf ' %s' "$@"
    printf ' %s\n' "$IMAGE_NAME"

else

    CID=$(docker "$@" "$IMAGE_NAME")

    NAME="$CONTAINER_NAME"

    if [ -z "$NAME" ]; then
        NAME=$(docker inspect --format '{{.Name}}' "$CID" | sed 's#^/##')
    fi

    echo "Container name: $NAME"

fi
