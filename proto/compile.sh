#!/bin/bash

#* Before the event: Need login gcloud service account

# Init color
RED='\033[0;31m'
NC='\033[0m'

# Check out env GITHUB_REPOSITORY
if [ -z "$GITHUB_REPOSITORY" ]; then
    echo "You must define ENV GITHUB_REPOSITORY or run via Github Actions..."
    echo "Try to get GITHUB_REPOSITORY from git config..."
    GITHUB_REPOSITORY=$(git config --get remote.origin.url | sed 's/https:\/\/github.com\///' | sed 's/\.git//')
fi
echo -e "@ GITHUB_REPOSITORY = ${RED}$GITHUB_REPOSITORY${NC}"

# Check out env COMPILE_MODE
# Default -> single-compile
# Multi -> multi-compile
if [ "$COMPILE_MODE" == "Multi" ] || [ "$COMPILE_MODE" == "MULITI" ] || [ "$COMPILE_MODE" == "multi" ]; then
    SCRIPT_FILE="build-protoc2.sh"
elif [ "$COMPILE_MODE" == "v3" ]; then
    SCRIPT_FILE="build-protoc3.sh"
elif [ "$COMPILE_MODE" == "v4" ]; then
    SCRIPT_FILE="build-protoc4.sh"
elif [ "$COMPILE_MODE" == "old" ]; then
    SCRIPT_FILE="build-protoc.sh"
else
    SCRIPT_FILE="build-neo.sh"
fi
echo -e "@ ENV / COMPILE_MODE = ${COMPILE_MODE:-Default} : SCRIPT_FILE = ${RED}$SCRIPT_FILE${NC}"

if [ "$COMPILE_MODE" == "Multi" ] || [ "$COMPILE_MODE" == "MULITI" ] || [ "$COMPILE_MODE" == "multi" ] || [ "$COMPILE_MODE" == "v3" ] || [ "$COMPILE_MODE" == "v4" ] || [ "$COMPILE_MODE" == "old" ]; then
    echo "--- default ---"
    # Download script
    curl -sLJO "https://raw.githubusercontent.com/lctech-tw/util_scripts/main/proto/$SCRIPT_FILE"
    curl -sLJO "https://raw.githubusercontent.com/lctech-tw/util_scripts/main/proto/build-protoc-node.sh"
    # Auth
    if [ ! "$(whoami)" == "lctech-zeki" ]; then
        # GCP
        gcloud auth activate-service-account docker-puller@lc-shared-res.iam.gserviceaccount.com --key-file=.github/auth/puller.json
        gcloud auth configure-docker -q
        # Docker
        cat <./.github/auth/puller.json | docker login -u _json_key --password-stdin https://asia.gcr.io
    fi
    # Run build-protoc via docker
    docker pull asia.gcr.io/lc-shared-res/proto-compiler:node &
    docker pull asia.gcr.io/lc-shared-res/proto-compiler:latest
    docker run --rm -v "$(pwd)":/workdir asia.gcr.io/lc-shared-res/proto-compiler:latest ./"$SCRIPT_FILE" build github.com/"$GITHUB_REPOSITORY"
    docker run --rm -v "$(pwd)":/workdir asia.gcr.io/lc-shared-res/proto-compiler:node ./build-protoc-node.sh build
    # Remove script
    rm -f ./build-protoc*
else
    echo "--- neo stable ---"
    rm -rf dist
    cd ./src || exit
    if [ ! -f "buf.yaml" ]; then
        curl -sLJO "https://raw.githubusercontent.com/lctech-tw/util_scripts/main/proto/buf.yaml"
    fi
    if [ ! -f "buf.gen.yaml" ]; then
        curl -sLJO "https://raw.githubusercontent.com/lctech-tw/util_scripts/main/proto/buf.gen.yaml"
    fi
    mkdir dist
    docker run --volume "$(pwd):/workspace" --workdir /workspace bufbuild/buf generate
    mv dist ../dist && rm -rf buf.yaml buf.gen.yaml
    # golang
    sudo mv ../dist/go/github.com/"$GITHUB_REPOSITORY"/dist/go/* ../dist/go/
    # README
    sudo mv ../dist/docs/docs.md ../README.md
fi
