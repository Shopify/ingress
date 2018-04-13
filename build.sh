#!/bin/bash
set -ex

DOCKER_TAG=${1:-$PIPA_IMAGE_FULL_NAME}

if [[ -z "${DOCKER_TAG}" ]]; then
  echo "$0 [image]"
  exit 1
fi

GO_VERSION=1.9.3
PKG=k8s.io/ingress-nginx
TAG=0.10.2
ARCH=amd64

docker run -e CGO_ENABLED=0 -e GOOS=linux -e GOARCH=${ARCH} -v ${PWD}:/go/src/${PKG} -w /tmp/src golang:${GO_VERSION} go build -a -installsuffix cgo -ldflags "-s -w -X ${PKG}/version.RELEASE=${TAG} -X ${PKG}/version.COMMIT=${COMMIT} -X ${PKG}/version.REPO=${REPO_INFO}" -o /go/src/${PKG}/rootfs/nginx-ingress-controller ${PKG}/cmd/nginx

docker build -t "${DOCKER_TAG}" .
