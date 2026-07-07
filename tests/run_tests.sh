#!/usr/bin/env bash
# Run all bats unit tests for the Autoware meta-repository.
# Prerequisites: bats-core (https://github.com/bats-core/bats-core)
#
# Usage:
#   ./tests/run_tests.sh          # run all tests
#   ./tests/run_tests.sh telegraf # run only telegraf tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats >/dev/null 2>&1; then
    echo "ERROR: bats-core is not installed." >&2
    echo "Install it via: git clone https://github.com/bats-core/bats-core.git && sudo bats-core/install.sh /usr/local" >&2
    exit 1
fi

if [ $# -ge 1 ]; then
    target_dir="$SCRIPT_DIR/$1"
    if [ ! -d "$target_dir" ]; then
        echo "ERROR: Test directory '$target_dir' not found." >&2
        exit 1
    fi
    echo "Running tests in: $target_dir"
    bats --recursive "$target_dir"
else
    echo "Running all tests in: $SCRIPT_DIR"
    bats --recursive "$SCRIPT_DIR"
fi
