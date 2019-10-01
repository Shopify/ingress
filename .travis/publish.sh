#!/usr/bin/env bash

# Copyright 2019 The Kubernetes Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -o errexit
set -o pipefail

function docker_tag_exists() {
    TAG=${2//\"/}
    TOKEN=$( curl -s -H "Content-Type: application/json" -X POST -d '{"username": "'${DOCKER_USERNAME}'", "password": "'${DOCKER_PASSWORD}'"}' https://hub.docker.com/v2/users/login | jq -r ".token" )
    RES=$(curl -sH "Authorization: JWT $TOKEN" "https://hub.docker.com/v2/repositories/$1-$3/tags/$TAG/" | jq .detail)

    if [ "$RES" == "\"Not found\"" ];
    then
        return 1
    fi

    return 0
}

ARCH=$1

echo "$DOCKER_PASSWORD" | docker login -u "$DOCKER_USERNAME" --password-stdin

IMAGE=$(make -s image-info)
if docker_tag_exists "shopify/nginx-ingress-controller" $(echo $IMAGE | jq .tag) "$ARCH"; then
  echo "Image was already published, skipping: ${IMAGE}"
  exit 0
fi

make sub-container-$ARCH
make sub-push-$ARCH
