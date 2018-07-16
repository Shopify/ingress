#!/bin/bash -x

# Copyright 2018 The Kubernetes Authors.
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
set -o nounset
set -o pipefail

if [ -z "${PKG}" ]; then
    echo "PKG must be set"
    exit 1
fi

rm -rf coverage.txt
for d in `go list ${PKG}/... | grep -v vendor | grep -v '/test/e2e' | grep -v images`; do
    t=$(date +%s);
    go test -coverprofile=cover.out -covermode=atomic $d || exit 1;
    echo "Coverage test $d took $(($(date +%s)-$t)) seconds";
    if [ -f cover.out ]; then
        cat cover.out >> coverage.txt;
        rm cover.out;
    fi;
done
