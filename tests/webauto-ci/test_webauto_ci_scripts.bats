#!/usr/bin/env bats
# shellcheck disable=SC2016
# Unit tests for .webauto-ci scripts
# Tests structure, required variables, and configuration logic.

SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

AUTOWARE_BUILD="$REPO_ROOT/.webauto-ci/main/autoware-build/run.sh"
AUTOWARE_SETUP="$REPO_ROOT/.webauto-ci/main/autoware-setup/run.sh"
ENVIRONMENT_SETUP="$REPO_ROOT/.webauto-ci/main/environment-setup/run.sh"

# --- autoware-build/run.sh tests ---

@test "autoware-build requires WEBAUTO_CI_SOURCE_PATH variable" {
    run grep 'WEBAUTO_CI_SOURCE_PATH.*is not set' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build requires WEBAUTO_CI_DEBUG_BUILD variable" {
    run grep 'WEBAUTO_CI_DEBUG_BUILD.*is not set' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build requires AUTOWARE_PATH variable" {
    run grep 'AUTOWARE_PATH.*is not set' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build sets Release build type when debug is false" {
    run grep 'build_type="Release"' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build sets RelWithDebInfo build type when debug is true" {
    run grep 'build_type="RelWithDebInfo"' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build configures ccache when CCACHE_DIR is set" {
    run grep -A5 'if \[ -n "\$CCACHE_DIR" \]' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
    [[ ${output} == *"USE_CCACHE=1"* ]]
}

@test "autoware-build uses parallel workers for colcon build" {
    run grep 'parallel-workers' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
    [[ ${output} == *'PARALLEL_WORKERS'* ]]
}

@test "autoware-build defaults PARALLEL_WORKERS to 4" {
    run grep 'PARALLEL_WORKERS.*4' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build defaults CCACHE_SIZE to 1G" {
    run grep 'CCACHE_SIZE.*1G' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build disables testing in cmake" {
    run grep 'BUILD_TESTING=off' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

@test "autoware-build uses symlink install" {
    run grep '\-\-symlink-install' "$AUTOWARE_BUILD"
    [ "$status" -eq 0 ]
}

# --- autoware-setup/run.sh tests ---

@test "autoware-setup installs ansible galaxy collections" {
    run grep 'ansible-galaxy collection install' "$AUTOWARE_SETUP"
    [ "$status" -eq 0 ]
}

@test "autoware-setup runs ansible-playbook for install_dev_env" {
    run grep 'ansible-playbook autoware.dev_env.install_dev_env' "$AUTOWARE_SETUP"
    [ "$status" -eq 0 ]
}

@test "autoware-setup uses ros-base installation type" {
    run grep 'ros2_installation_type=ros-base' "$AUTOWARE_SETUP"
    [ "$status" -eq 0 ]
}

@test "autoware-setup skips dev_tools tag" {
    run grep '\-\-skip-tags dev_tools' "$AUTOWARE_SETUP"
    [ "$status" -eq 0 ]
}

@test "autoware-setup sets rosdistro to humble" {
    run grep 'rosdistro=humble' "$AUTOWARE_SETUP"
    [ "$status" -eq 0 ]
}

@test "autoware-setup sets install_devel to false" {
    run grep 'install_devel=false' "$AUTOWARE_SETUP"
    [ "$status" -eq 0 ]
}

# --- environment-setup/run.sh tests ---

@test "environment-setup installs sudo" {
    run grep 'install.*sudo' "$ENVIRONMENT_SETUP"
    [ "$status" -eq 0 ]
}

@test "environment-setup installs ccache" {
    run grep 'ccache' "$ENVIRONMENT_SETUP"
    [ "$status" -eq 0 ]
}

@test "environment-setup installs ansible" {
    run grep 'ansible' "$ENVIRONMENT_SETUP"
    [ "$status" -eq 0 ]
}

@test "environment-setup creates autoware user" {
    run grep 'user=autoware' "$ENVIRONMENT_SETUP"
    [ "$status" -eq 0 ]
}

@test "environment-setup grants sudo to autoware user" {
    run grep 'NOPASSWD:ALL' "$ENVIRONMENT_SETUP"
    [ "$status" -eq 0 ]
}

@test "environment-setup adds universe repository" {
    run grep 'add-apt-repository universe' "$ENVIRONMENT_SETUP"
    [ "$status" -eq 0 ]
}

@test "all webauto-ci scripts have bash shebang" {
    for script in "$AUTOWARE_BUILD" "$AUTOWARE_SETUP" "$ENVIRONMENT_SETUP"; do
        first_line=$(head -1 "$script")
        [[ $first_line == "#!/bin/bash"* ]]
    done
}

@test "all webauto-ci scripts use bash with error exit" {
    for script in "$AUTOWARE_BUILD" "$AUTOWARE_SETUP" "$ENVIRONMENT_SETUP"; do
        # Scripts may use 'set -e' or '#!/bin/bash -e'
        run bash -c 'grep -q "set -e" "'"$script"'" || head -1 "'"$script"'" | grep -q "\-e"'
        [ "$status" -eq 0 ]
    done
}
