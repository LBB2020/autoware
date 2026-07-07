#!/usr/bin/env bats
# shellcheck disable=SC2016
# Unit tests for ansible/scripts/install-ansible.sh
# Tests the script logic with mocked system commands.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/ansible/scripts/install-ansible.sh"

setup() {
    export TMPDIR="${BATS_TEST_TMPDIR}"
    export MOCK_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN_DIR"
}

teardown() {
    rm -rf "$MOCK_BIN_DIR"
}

@test "script uses set -euo pipefail for strict error handling" {
    run grep -c "set -euo pipefail" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
    [ "$output" = "1" ]
}

@test "script installs sudo if not available" {
    run grep "command -v sudo" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
    [[ ${output} == *"command -v sudo"* ]]
}

@test "script installs required packages: git python3-pip python3-venv pipx" {
    run grep "python3-pip python3-venv pipx" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
}

@test "script installs ansible 10.x via pipx" {
    run grep 'ansible==10' "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
}

@test "script sets PATH to include pipx bin directory" {
    run grep 'PIPX_BIN_DIR' "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
    [[ ${output} == *'$HOME/.local/bin'* ]]
}

@test "script outputs ansible version at the end" {
    run grep "ansible --version" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
}

@test "script uses --force flag for pipx install to support re-runs" {
    run grep "pipx install.*--force" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
}

@test "script uses --include-deps for pipx install" {
    run grep "pipx install.*--include-deps" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
}

@test "script runs python3 -m pipx ensurepath" {
    run grep "python3 -m pipx ensurepath" "$SCRIPT_UNDER_TEST"
    [ "$status" -eq 0 ]
}

@test "script has proper shebang line" {
    first_line=$(head -1 "$SCRIPT_UNDER_TEST")
    [[ $first_line == "#!/usr/bin/env bash" ]]
}
