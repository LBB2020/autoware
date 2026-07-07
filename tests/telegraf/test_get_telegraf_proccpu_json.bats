#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# cspell:ignore proccpu pidstat PIDSTAT
# Unit tests for ansible/roles/telegraf/files/get_telegraf_proccpu_json.sh

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/ansible/roles/telegraf/files/get_telegraf_proccpu_json.sh"

# Helper: create a mock pidstat that returns controlled output
setup() {
    export TMPDIR="${BATS_TEST_TMPDIR}"
    export MOCK_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN_DIR"
}

teardown() {
    rm -rf "$MOCK_BIN_DIR"
}

create_mock_pidstat() {
    local output="$1"
    cat >"$MOCK_BIN_DIR/pidstat" <<EOF
#!/bin/bash
cat <<'PIDSTAT_OUTPUT'
Linux 5.15.0 (host)    07/07/2026

# Time   UID  PID  %usr %system %guest %wait %CPU  CPU  Command
$output
PIDSTAT_OUTPUT
EOF
    chmod +x "$MOCK_BIN_DIR/pidstat"
}

@test "produces valid JSON structure with opening and closing braces" {
    create_mock_pidstat "1234  1000  100  5.00  3.00  0.00  0.00  8.00  0  /usr/bin/test_proc"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    # Check JSON structure: starts with { and ends with }
    first_line="${lines[0]}"
    last_line="${lines[${#lines[@]} - 1]}"
    [ "$first_line" = "{" ]
    [ "$last_line" = "}" ]
}

@test "filters out processes with 0% CPU" {
    create_mock_pidstat '1234  1000  100  0.00  0.00  0.00  0.00  0.00  0  /usr/bin/idle_proc
1234  1000  101  5.00  3.00  0.00  0.00  8.00  0  /usr/bin/active_proc'
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    # Should not contain idle_proc
    [[ ${output} != *"idle_proc"* ]]
    # Should contain active_proc
    [[ ${output} == *"active_proc"* ]]
}

@test "replaces spaces with underscores in command names" {
    create_mock_pidstat '1234  1000  100  5.00  3.00  0.00  0.00  8.00  0  /usr/bin/test proc with spaces'
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    # Spaces should be replaced with underscores
    [[ ${output} != *" proc"* ]] || [[ ${output} == *"_proc"* ]]
}

@test "replaces equals signs with underscores in command names" {
    create_mock_pidstat '1234  1000  100  5.00  3.00  0.00  0.00  8.00  0  /usr/bin/test=proc'
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    # Equals should be replaced with underscores
    [[ ${output} != *"test=proc"* ]]
}

@test "truncates command names to 50 characters" {
    # Create a command name longer than 50 chars
    local long_cmd="/usr/bin/this_is_a_very_long_command_name_that_exceeds_fifty_characters_total"
    create_mock_pidstat "1234  1000  100  5.00  3.00  0.00  0.00  8.00  0  $long_cmd"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    # Extract the key from JSON output (between quotes)
    local json_key
    json_key=$(echo "$output" | grep -oP '(?<=")[^"]+(?=":)' | grep -v "^z$" | head -1)
    # Key should be <= 50 characters
    [ "${#json_key}" -le 50 ]
}

@test "always includes sentinel z:0 entry" {
    create_mock_pidstat '1234  1000  100  5.00  3.00  0.00  0.00  8.00  0  /usr/bin/test_proc'
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} == *'"z":0'* ]]
}

@test "outputs empty JSON when no processes exceed 0% CPU" {
    create_mock_pidstat '1234  1000  100  0.00  0.00  0.00  0.00  0.00  0  /usr/bin/idle_proc'
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    # Should still have valid JSON with just z:0
    [[ ${output} == *'"z":0'* ]]
    [[ ${output} != *"idle_proc"* ]]
}
