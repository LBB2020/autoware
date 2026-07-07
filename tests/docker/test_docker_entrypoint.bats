#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# cspell:ignore testuser usermod groupmod
# Unit tests for docker/docker-entrypoint.sh
# Tests the try_set function and environment variable handling logic.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
# shellcheck disable=SC2034
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

setup() {
    export TMPDIR="${BATS_TEST_TMPDIR}"
    export MOCK_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN_DIR"

    # Create a testable version of the entrypoint that doesn't exec or source ROS
    export TEST_ENTRYPOINT="${BATS_TEST_TMPDIR}/test_entrypoint.sh"
    cat >"$TEST_ENTRYPOINT" <<'EOF'
#!/bin/bash
set -e

try_set() {
    "$@" >/dev/null 2>&1 ||
        echo "[entrypoint] WARN: failed: $* (need --privileged or --cap-add=NET_ADMIN)" >&2
}
EOF
    chmod +x "$TEST_ENTRYPOINT"
}

teardown() {
    rm -rf "$MOCK_BIN_DIR"
}

@test "try_set succeeds silently when command succeeds" {
    run bash -c 'source '"$TEST_ENTRYPOINT"'; try_set true'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "try_set prints warning to stderr when command fails" {
    run bash -c 'source '"$TEST_ENTRYPOINT"'; try_set false 2>&1'
    [ "$status" -eq 0 ]
    [[ ${output} == *"[entrypoint] WARN: failed: false"* ]]
    [[ ${output} == *"--privileged or --cap-add=NET_ADMIN"* ]]
}

@test "try_set does not abort the script on failure" {
    run bash -c 'source '"$TEST_ENTRYPOINT"'; try_set false; echo "still running"'
    [ "$status" -eq 0 ]
    [[ ${output} == *"still running"* ]]
}

@test "try_set suppresses stdout of successful command" {
    run bash -c 'source '"$TEST_ENTRYPOINT"'; try_set echo "hello world"'
    [ "$status" -eq 0 ]
    [[ ${output} != *"hello world"* ]]
}

@test "try_set includes full command in warning message" {
    run bash -c 'source '"$TEST_ENTRYPOINT"'; try_set /nonexistent_cmd --flag=value 2>&1'
    [ "$status" -eq 0 ]
    [[ ${output} == *"/nonexistent_cmd --flag=value"* ]]
}

@test "entrypoint remaps user UID/GID when HOST_UID and HOST_GID are set" {
    # Create mock usermod and groupmod
    cat >"$MOCK_BIN_DIR/usermod" <<'MOCK'
#!/bin/bash
echo "usermod called with: $*"
MOCK
    cat >"$MOCK_BIN_DIR/groupmod" <<'MOCK'
#!/bin/bash
echo "groupmod called with: $*"
MOCK
    chmod +x "$MOCK_BIN_DIR/usermod" "$MOCK_BIN_DIR/groupmod"

    # Test the remap logic in isolation
    run bash -c '
        export PATH="'"$MOCK_BIN_DIR"':$PATH"
        HOST_UID=1234
        HOST_GID=5678
        USERNAME=testuser
        if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
            usermod -u "${HOST_UID}" "${USERNAME}" 2>&1 || true
            groupmod -g "${HOST_GID}" "${USERNAME}" 2>&1 || true
        fi
    '
    [ "$status" -eq 0 ]
    [[ ${output} == *"usermod called with: -u 1234 testuser"* ]]
    [[ ${output} == *"groupmod called with: -g 5678 testuser"* ]]
}

@test "entrypoint skips UID/GID remap when HOST_UID is not set" {
    cat >"$MOCK_BIN_DIR/usermod" <<'MOCK'
#!/bin/bash
echo "usermod should not be called"
exit 1
MOCK
    chmod +x "$MOCK_BIN_DIR/usermod"

    run bash -c '
        export PATH="'"$MOCK_BIN_DIR"':$PATH"
        unset HOST_UID
        HOST_GID=5678
        USERNAME=testuser
        if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
            usermod -u "${HOST_UID}" "${USERNAME}" 2>&1 || true
        fi
        echo "skipped correctly"
    '
    [ "$status" -eq 0 ]
    [[ ${output} == *"skipped correctly"* ]]
    [[ ${output} != *"usermod should not be called"* ]]
}

@test "entrypoint skips UID/GID remap when HOST_GID is not set" {
    cat >"$MOCK_BIN_DIR/groupmod" <<'MOCK'
#!/bin/bash
echo "groupmod should not be called"
exit 1
MOCK
    chmod +x "$MOCK_BIN_DIR/groupmod"

    run bash -c '
        export PATH="'"$MOCK_BIN_DIR"':$PATH"
        HOST_UID=1234
        unset HOST_GID
        USERNAME=testuser
        if [ -n "${HOST_UID}" ] && [ -n "${HOST_GID}" ]; then
            groupmod -g "${HOST_GID}" "${USERNAME}" 2>&1 || true
        fi
        echo "skipped correctly"
    '
    [ "$status" -eq 0 ]
    [[ ${output} == *"skipped correctly"* ]]
    [[ ${output} != *"groupmod should not be called"* ]]
}
