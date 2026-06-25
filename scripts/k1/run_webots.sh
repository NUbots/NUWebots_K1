#!/usr/bin/env bash
#
# Open a K1 world in Booster's Webots R2023b build AND (unless K1_NO_MCK=1) start Booster's `mck` runner
# once the world has loaded. So `webots` brings up the full simulated robot — body (Webots) + firmware
# (mck) — and the only thing left to drive it is:  cd ~/NUbots_K1 && ./b run webots/keyboardwalk
#
#   webots                     # opens worlds/k1_robocup.wbt and drives K1_blue_1 with mck
#   K1_ROBOT=K1_red_1 webots   # drive the red robot instead
#   K1_NO_MCK=1 webots         # just open the world, don't start mck
# mck logs to /tmp/k1_mck.log and is stopped when you close Webots.
set -uo pipefail

WEBOTS_BOOSTER="${WEBOTS_BOOSTER:-$HOME/webots-booster}"
repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

export WEBOTS_HOME="$WEBOTS_BOOSTER/webots"
export LD_LIBRARY_PATH="$WEBOTS_HOME/lib/controller:${LD_LIBRARY_PATH:-}"

world="${1:-$repo_root/worlds/k1_robocup.wbt}"
[ -f "$world" ] || { echo "World not found: $world" >&2; exit 1; }

# Start mck in its own session once Webots's extern controller is listening (port 1234); kill it on exit.
if [ "${K1_NO_MCK:-0}" != 1 ]; then
  export K1_ROBOT="${K1_ROBOT:-K1_blue_1}"
  export K1_RUNNER="$repo_root/scripts/k1/run_runner.sh"
  setsid bash -c '
    for _ in $(seq 1 180); do
      (exec 3<>/dev/tcp/127.0.0.1/1234) 2>/dev/null && { exec 3>&-; break; }
      sleep 1
    done
    exec "$K1_RUNNER"
  ' >/tmp/k1_mck.log 2>&1 &
  mck_pgid=$!
  trap 'kill -- -"$mck_pgid" 2>/dev/null' EXIT INT TERM
  echo "==> Will start mck for '$K1_ROBOT' once the world loads (logs: /tmp/k1_mck.log)."
fi

# __NV_PRIME_RENDER_OFFLOAD forces the NVIDIA dGPU on PRIME laptops; harmless otherwise.
env __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia "$WEBOTS_HOME/webots" "$world"
