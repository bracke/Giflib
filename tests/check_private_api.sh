#!/bin/sh
set -eu

output="$(gprbuild -q -p -P private_api_rejection.gpr 2>&1)" && status=0 || status=$?
if [ "$status" -eq 0 ]; then
    echo "private API check failed: Giflib.Internal was importable" >&2
    exit 1
fi

case "$output" in
    *"private child unit"*) exit 0 ;;
    *)
        echo "$output" >&2
        echo "private API check failed for an unexpected reason" >&2
        exit 1
        ;;
esac
