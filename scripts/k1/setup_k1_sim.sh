#!/usr/bin/env bash
#
# Installs Booster's K1 Webots simulation from the files downloaded off the Booster wiki.
# This is the SDK/DDS simulation path: Booster's `mck` runner is the Webots <extern> controller and
# exposes the Booster SDK over DDS, exactly like the real K1. NUbots connects to it from the NUbots_K1
# codebase (see docs/K1_WEBOTS_SETUP.md). It does NOT use this repo's NUgus TCP controllers.
#
# Prerequisites (download from the Booster wiki - see docs/K1_WEBOTS_SETUP.md):
#   - webots_updated.zip                          (Booster's Webots R2023b build, ~880 MB)
#   - k1_webots_simulation.zip                    (the K1 world + meshes)
#   - booster-runner-full-webots-k1-<ver>.run     (the K1 motion runner / mck)
#
# Usage:
#   scripts/k1/setup_k1_sim.sh
# Override locations with env vars:
#   DOWNLOADS=~/Downloads  WEBOTS_BOOSTER=~/webots-booster  K1_SIM_DIR=~/booster_k1_sim  scripts/k1/setup_k1_sim.sh
set -euo pipefail

DOWNLOADS="${DOWNLOADS:-$HOME/Downloads}"
WEBOTS_BOOSTER="${WEBOTS_BOOSTER:-$HOME/webots-booster}"
K1_SIM_DIR="${K1_SIM_DIR:-$HOME/booster_k1_sim}"

echo "==> Booster K1 Webots simulation setup"
echo "    Downloads     : $DOWNLOADS"
echo "    Webots build  : $WEBOTS_BOOSTER/webots"
echo "    Sim work dir  : $K1_SIM_DIR"

# --- sanity checks -----------------------------------------------------------
if [ "$(uname -m)" != "x86_64" ]; then
  echo "WARNING: expected x86_64 (the runner and Webots build are x86_64); found $(uname -m)." >&2
fi
if command -v lsb_release >/dev/null && ! lsb_release -rs | grep -q '^22'; then
  echo "WARNING: this is tested on Ubuntu 22.04; found $(lsb_release -ds 2>/dev/null)." >&2
fi

webots_zip="$DOWNLOADS/webots_updated.zip"
world_zip="$DOWNLOADS/k1_webots_simulation.zip"
runner_run="$(ls "$DOWNLOADS"/booster-runner-full-webots-k1-*.run 2>/dev/null | head -1 || true)"

missing=0
for f in "$webots_zip" "$world_zip"; do
  [ -f "$f" ] || { echo "MISSING: $f" >&2; missing=1; }
done
[ -n "$runner_run" ] || { echo "MISSING: $DOWNLOADS/booster-runner-full-webots-k1-*.run" >&2; missing=1; }
if [ "$missing" -ne 0 ]; then
  echo >&2
  echo "Download the missing file(s) from the Booster wiki, then re-run. See docs/K1_WEBOTS_SETUP.md." >&2
  exit 1
fi

# --- install Booster's Webots build (alongside any existing /usr/local/webots) ----
if [ -x "$WEBOTS_BOOSTER/webots/webots" ]; then
  echo "==> Webots build already present at $WEBOTS_BOOSTER/webots (skipping unzip)"
else
  echo "==> Unzipping Booster Webots build to $WEBOTS_BOOSTER (this is ~880 MB)"
  mkdir -p "$WEBOTS_BOOSTER"
  unzip -oq "$webots_zip" -d "$WEBOTS_BOOSTER"
fi
echo "    Webots version: $(cat "$WEBOTS_BOOSTER/webots/resources/version.txt" 2>/dev/null || echo '?')"

# --- stage the world + runner ------------------------------------------------
echo "==> Staging world + runner in $K1_SIM_DIR"
mkdir -p "$K1_SIM_DIR"
unzip -oq "$world_zip" -d "$K1_SIM_DIR"
cp -f "$runner_run" "$K1_SIM_DIR/"
chmod +x "$K1_SIM_DIR"/booster-runner-full-webots-k1-*.run

# --- drop the launchers next to the sim --------------------------------------
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp -f "$script_dir/run_webots.sh" "$script_dir/run_runner.sh" "$K1_SIM_DIR/"
chmod +x "$K1_SIM_DIR/run_webots.sh" "$K1_SIM_DIR/run_runner.sh"

echo
echo "==> Done. Next:"
echo "    1) Install build/runtime deps (needs sudo):"
echo "       sudo apt-get install -y cmake ninja-build libgtest-dev libgoogle-glog-dev libboost-dev \\"
echo "         libeigen3-dev liblua5.3-dev graphviz libgraphviz-dev python3-pip libcurl4-openssl-dev \\"
echo "         libsdl2-dev joystick libspdlog-dev"
echo "    2) Terminal A:  WEBOTS_BOOSTER=$WEBOTS_BOOSTER K1_SIM_DIR=$K1_SIM_DIR $K1_SIM_DIR/run_webots.sh"
echo "    3) Terminal B:  WEBOTS_BOOSTER=$WEBOTS_BOOSTER K1_SIM_DIR=$K1_SIM_DIR $K1_SIM_DIR/run_runner.sh"
echo "    The K1 should stand and balance. See docs/K1_WEBOTS_SETUP.md to drive it from NUbots_K1."
