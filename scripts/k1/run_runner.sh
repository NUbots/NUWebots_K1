#!/usr/bin/env bash
#
# Run Booster's K1 motion runner (`mck`) as the Webots <extern> controller.
# It attaches to the running Webots (run_webots.sh) via libController and exposes the Booster SDK over
# DDS (domain 0) - the same interface the real K1 firmware provides. NUbots_K1 connects to this over DDS.
#
# WEBOTS_HOME/LD_LIBRARY_PATH are pinned to Booster's R2023b build so the runner's libwebots_interface.so
# loads the matching libCppController.so.
#
#   WEBOTS_BOOSTER=~/webots-booster  K1_SIM_DIR=~/booster_k1_sim  scripts/k1/run_runner.sh
set -euo pipefail

WEBOTS_BOOSTER="${WEBOTS_BOOSTER:-$HOME/webots-booster}"
K1_SIM_DIR="${K1_SIM_DIR:-$HOME/booster_k1_sim}"

export WEBOTS_HOME="$WEBOTS_BOOSTER/webots"
export LD_LIBRARY_PATH="$WEBOTS_HOME/lib/controller:${LD_LIBRARY_PATH:-}"

# When the world has more than one <extern> robot (e.g. worlds/k1_robocup.wbt with K1_blue_1 + K1_red_1),
# mck must be told which one to drive. Set K1_ROBOT to that robot's `name`. For a single-robot world
# (e.g. K1_v1.wbt) leave K1_ROBOT unset so the controller auto-connects to the only robot.
if [ -n "${K1_ROBOT:-}" ]; then
  export WEBOTS_CONTROLLER_URL="ipc://1234/${K1_ROBOT}"
fi

runner="$(ls "$K1_SIM_DIR"/booster-runner-full-webots-k1-*.run 2>/dev/null | head -1 || true)"
[ -n "$runner" ] || { echo "Runner not found in $K1_SIM_DIR (run scripts/k1/setup_k1_sim.sh first)" >&2; exit 1; }

cd "$K1_SIM_DIR"
# --nox11 keeps it in this terminal instead of spawning a new GUI terminal.
exec "$runner" --nox11 "$@"
