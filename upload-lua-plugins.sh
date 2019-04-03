#!/bin/bash

REVISION=$(git rev-parse HEAD)
FILENAME="$PWD/plugins-$REVISION.tar.gz"
PLUGINS_DIRECTORY="./plugins"
GCS_BUCKET=ingress-nginx-lua-plugins


echo "Create archive..."
tar -czf $FILENAME -C $PLUGINS_DIRECTORY .

echo "Push archive to gcs"
gsutil cp $FILENAME gs://$GCS_BUCKET/

echo "Archive available at gs://$GCS_BUCKET/$(basename $FILENAME)"
