#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031
# cspell:ignore procmem
# Unit tests for ansible/roles/telegraf/files/get_telegraf_procmem_json.sh

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
SCRIPT_UNDER_TEST="$REPO_ROOT/ansible/roles/telegraf/files/get_telegraf_procmem_json.sh"

setup() {
    export TMPDIR="${BATS_TEST_TMPDIR}"
    export MOCK_BIN_DIR="${BATS_TEST_TMPDIR}/bin"
    mkdir -p "$MOCK_BIN_DIR"
}

teardown() {
    rm -rf "$MOCK_BIN_DIR"
}

create_mock_ps() {
    local output="$1"
    cat >"$MOCK_BIN_DIR/ps" <<EOF
#!/bin/bash
echo "  RSS COMMAND"
cat <<'PS_OUTPUT'
$output
PS_OUTPUT
EOF
    chmod +x "$MOCK_BIN_DIR/ps"
}

@test "produces valid JSON structure with opening and closing braces" {
    create_mock_ps "50000 /usr/bin/test_proc"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    first_line="${lines[0]}"
    last_line="${lines[${#lines[@]} - 1]}"
    [ "$first_line" = "{" ]
    [ "$last_line" = "}" ]
}

@test "filters out processes with RSS less than 30000 KB" {
    create_mock_ps "10000 /usr/bin/small_proc
50000 /usr/bin/big_proc"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} != *"small_proc"* ]]
    [[ ${output} == *"big_proc"* ]]
}

@test "replaces spaces with underscores in command names" {
    create_mock_ps "50000 /usr/bin/proc with spaces"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} == *"_"* ]]
}

@test "replaces equals signs with underscores in command names" {
    create_mock_ps "50000 /usr/bin/proc=value"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} != *"proc=value"* ]]
}

@test "truncates command names to 50 characters" {
    local long_cmd="/usr/bin/this_is_a_very_long_command_name_that_exceeds_fifty_characters_total"
    create_mock_ps "50000 $long_cmd"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    local json_key
    json_key=$(echo "$output" | grep -oP '(?<=")[^"]+(?=":)' | grep -v "^z$" | head -1)
    [ "${#json_key}" -le 50 ]
}

@test "always includes sentinel z:0 entry" {
    create_mock_ps "50000 /usr/bin/test_proc"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} == *'"z":0'* ]]
}

@test "outputs empty JSON when no processes exceed threshold" {
    create_mock_ps "1000 /usr/bin/tiny_proc"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} == *'"z":0'* ]]
    [[ ${output} != *"tiny_proc"* ]]
}

@test "reports correct RSS values in output" {
    create_mock_ps "65536 /usr/bin/big_proc"
    run bash -c 'export PATH="'"$MOCK_BIN_DIR"':$PATH"; bash '"$SCRIPT_UNDER_TEST"''
    [ "$status" -eq 0 ]
    [[ ${output} == *"65536"* ]]
}
