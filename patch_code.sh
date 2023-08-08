#!/bin/bash
#Put any patches/custom code changes here
#Requires 1 argument - the path to the code

set -e

SRC=$1

if [[ -z "$SRC" ]]; then
    echo "No code path passed into $0"
    exit 1
fi

