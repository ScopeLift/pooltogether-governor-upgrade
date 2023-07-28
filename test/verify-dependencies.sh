#!/bin/bash

DIR="lib/flexible-voting"
EXPECTED_VERSION="v1.1.0"

cd $DIR
TAG=$(git describe --tags)

if [ "$TAG" != "$EXPECTED_VERSION" ]; then
  echo "Error: The '$DIR dependency' is not on tag '$EXPECTED_VERSION'"
  exit 1
fi

echo "Versions match!"
