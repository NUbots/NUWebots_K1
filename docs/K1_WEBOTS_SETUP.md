# Booster K1 — Webots Simulation Setup

How to run the **Booster Robotics K1** in Webots and drive it from the NUbots codebase.

Based on Booster's wiki: <https://booster.feishu.cn/wiki/E3q5wF5SnitXZgkY18Uc8odBnXb>
(the downloads below are gated behind that wiki — you need access to fetch them).

---

## How it works (read this first)

The K1 uses a **different architecture** from the old NUgus Webots setup. The NUgus sim used this
repo's C++ controllers (`controllers/nugus_controller`) talking the RoboCup TC protobuf protocol over
**TCP** (ports 10001+). The K1 does **not** use that path.

Instead the K1 is driven through the **Booster SDK over DDS** — the same interface in simulation and on
the real robot:

```
Webots (K1_v1.wbt, robot controller "<extern>")
        │  libController (Webots IPC)
        ▼
  mck  (Booster's "motion" runner: whole-body controller, planner, state estimator)
        │  Booster SDK over FastDDS (domain 0, localhost)
        ▼
  NUbots_K1  platform::Booster::HardwareIO   (B1LocoClient: Move / RotateHead / GetUp / …)
```

- **Webots** just simulates the K1 body. The robot's controller is `"<extern>"`, so Webots waits for
  an external controller to attach.
- **`mck`** (the `booster-runner-*.run`) is that external controller. It runs the K1's real motion stack
  and exposes the Booster SDK over DDS — identical to talking to the real robot's firmware.
- **NUbots** (`NUbots_K1` repo) connects over DDS and sends high-level commands (walk velocity, head
  angles, get-up, kick). The K1 firmware/`mck` does the actual gait — NUbots does **not** compute joint
  trajectories for the K1.

Because sim and real share the SDK, NUbots roles are the same in both: e.g. `roles/webots/keyboardwalk.role`
uses `platform::Booster::HardwareIO` + `skill::K1Walk`, not the old `platform::Webots` (TCP) path.

---

## 1. Requirements

| | |
| --- | --- |
| OS | **Ubuntu 22.04** |
| Arch | **x86_64** (the runner and Webots build are x86_64; the K1's onboard Orin NX is aarch64) |
| RAM | 16 GB recommended |
| GPU | any; an NVIDIA dGPU helps Webots rendering |

Build/runtime packages (Booster's list):

```bash
sudo apt-get update && sudo apt-get install -y cmake ninja-build libgtest-dev libgoogle-glog-dev \
  libboost-dev libeigen3-dev liblua5.3-dev graphviz libgraphviz-dev python3-pip libcurl4-openssl-dev \
  libsdl2-dev joystick libspdlog-dev
```

## 2. Download the Booster files

From the Booster wiki (link above), download into `~/Downloads`:

| File | What it is |
| --- | --- |
| `webots_updated.zip` (~880 MB) | Booster's **Webots R2023b** build, with all PROTO assets bundled |
| `k1_webots_simulation.zip` | the K1 world (`K1_v1.wbt`) + meshes |
| `booster-runner-full-webots-k1-<ver>.run` | the K1 motion runner (`mck`) |

> **Why Booster's Webots build and not the one you already have?** The K1 world is R2023b and the stock
> Cyberbotics R2023b tarball is asset-light (it fetches PROTOs remotely), so `TexturedBackground`/`Floor`
> fail to load and the K1 falls through the missing floor. Webots **R2022b** can't load it at all (no
> `Pose` node). `webots_updated.zip` bundles everything and matches the runner's extern-controller ABI.

## 3. Install

```bash
# from this repo
scripts/k1/setup_k1_sim.sh
```

This installs Booster's Webots to `~/webots-booster/` (it does **not** touch `/usr/local/webots`, so the
NUgus R2022b worlds keep working), stages the world + runner in `~/booster_k1_sim/`, and copies the launch
scripts there. Override locations with `DOWNLOADS=`, `WEBOTS_BOOSTER=`, `K1_SIM_DIR=`.

## 4. Run the simulation

Two terminals:

```bash
# Terminal A — Webots + the K1 world
scripts/k1/run_webots.sh
#   wait for the console:  'K1_v1' extern controller: Waiting for ... connection ... port 1234

# Terminal B — the Booster motion runner (mck attaches as the extern controller)
scripts/k1/run_runner.sh
```

The K1 should **stand and balance**. `No joystick found` from the runner is harmless — that's Booster's
optional gamepad teleop, which we don't use. At this point the SDK simulator is fully working.

## 5. Drive the K1 from NUbots (`NUbots_K1` repo)

The robot code lives in the separate **`NUbots_K1`** repo. With the sim running (steps above):

```bash
cd ~/NUbots_K1
./b target generic           # x86_64 image  (NOT orinnx — that's the aarch64 Jetson build)
./b configure
./b build webots/keyboardwalk
./b run webots/keyboardwalk   # focus this terminal, drive the K1 with the keyboard
```

`./b run` launches the container with `--network host` **and `--ipc=host`** (see patch 9 below), so its DDS
reaches `mck` on the host (domain 0). The role connects to `mck`, receives `LowState`, and your keypresses
become walk velocity commands.

---

## Building `NUbots_K1` `generic` from scratch — required patches

**OS:** **Ubuntu 22.04 LTS, x86_64.** `generic` is the native x86_64 build (for Webots on your desktop).
`orinnx` is a separate aarch64 cross-compile for the robot's Jetson Orin NX — do **not** use it for sim.

**Why patches are needed:** `./b target generic` is renamed internally to `generic_k1` so the K1 image
(which adds the Booster SDK) doesn't overwrite the published NUgus `nubots/nubots:generic`. But that
platform was never finished and **no `generic_k1` image is published**, so building it locally from scratch
surfaces a chain of latent bugs. The team normally *pulls* a prebuilt image; from scratch you need all of
the following (every change is in **`NUbots_K1`**, and all are worth PR-ing upstream):

**Docker image build (`./b target generic`):**

1. Add `docker/usr/local/toolchain/generate_generic_k1_toolchain.py` — a copy of
   `generate_generic_toolchain.py` (both native x86_64). The Dockerfile runs
   `generate_${platform}_toolchain.py`; `generic_k1` had no generator → `No such file`.
2. In `docker/Dockerfile` (×3), `docker/usr/local/bin/container_setup.sh`, and
   `docker/usr/local/bin/install-cuda.sh`, change every `if [ "${platform}" != "generic" ]` to
   `if [ "${platform}" = "orinnx" ]`. These gate the ARM/Jetson sysroot steps; under the `generic_k1`
   rename they wrongly ran on the native build (writing into a non-existent `/l4t/targetfs` sysroot).
3. In `docker/Dockerfile`, right after the toolchain-generation step, add:
   `RUN if [ "${platform}" != "orinnx" ]; then mkdir -p /l4t && ln -s / /l4t/targetfs; fi`.
   Several libraries (ALSA, OpenCL, OpenCV, espeak) build from source into `/l4t/targetfs/${prefix}`
   unconditionally; on a native build this symlink makes them land in `/usr/local`, where CMake's
   `find_package` looks (otherwise `configure` fails with `Could NOT find ALSA`).

**Build tooling (`./b target` / `./b run`):**

4. `tools/target.py` — tag the *built* image (`generic_k1`) as `selected_k1`, not `generic`. Otherwise it
   tags the NUgus `:generic` image as selected and `./b configure` resolves the wrong platform and crashes.
   Compute `built = "generic_k1" if target == "generic" else target` before the `docker image tag`.
5. `tools/utility/dockerise/platform.py` — in `selected()`, change `list(sorted(names))[0]` to
   `sorted(names)[0]`; the module defines its own `def list()` which shadows the builtin → `TypeError:
   list() takes 0 positional arguments`.
6. `tools/run.py` — change `from tools.utility import processor_check` to
   `from utility import processor_check` (consistent with the other imports; `./b` puts `tools/` itself on
   `sys.path`, not its parent) → otherwise `ModuleNotFoundError: No module named 'tools.utility'`.
7. `tools/utility/processor_check.py` — normalise the binary arch string from `"x86-64"` (what `file`
   prints) to `"x86_64"` (what `platform.machine()` returns); otherwise `./b run` false-errors with
   `compiled for x86-64 but running on x86_64`.

**Code compile:**

8. `shared/utility/vision/TensorRT.cpp` — the Dockerfile's **unpinned** `libnvinfer-dev` installs
   **TensorRT 11**, which removed `IBuilder::platformHasFastFp16()` *and* `BuilderFlag::kFP16`. Guard the
   FP16 block with `#if defined(NV_TENSORRT_MAJOR) && NV_TENSORRT_MAJOR < 10` and skip setting the flag on
   TRT 10+. (Better long-term: pin TensorRT, or drop it — Yolo vision moved to OpenVINO.)

**Runtime (for sim DDS — not the build):**

9. `tools/utility/dockerise/run.py` — add `--ipc=host` to the `docker run` args, so FastDDS shared-memory
   transport works between the container (NUbots) and the host (`mck`). Without it the role connects but
   gets no `LowState` and the K1 doesn't move.

After these, `./b target generic && ./b configure && ./b build webots/keyboardwalk` builds
`<user>/nubots:generic_k1` cleanly, separate from any NUgus image.

## Opening a K1 world with `webots`

Booster's **Webots R2023b** is installed at `~/webots-booster/` (by `setup_k1_sim.sh`), so it never touches
a `/usr/local/webots` (R2022b) install used for the NUgus worlds. `scripts/k1/run_webots.sh` opens a K1
world in the R2023b build with the correct `WEBOTS_HOME`/`LD_LIBRARY_PATH`:

```bash
scripts/k1/run_webots.sh                  # opens worlds/k1_robocup.wbt
scripts/k1/run_webots.sh worlds/foo.wbt   # opens a specific world
```

To make **`webots` open the K1 world automatically from this repo**, replace the old `alias webots=…` in
`~/.bashrc` with this function (so in `~/NUWebots_K1` it uses R2023b, and elsewhere the normal R2022b):

```bash
unalias webots 2>/dev/null   # so re-sourcing ~/.bashrc doesn't clash with the old alias
webots() {
  local repo="$HOME/NUWebots_K1"
  if [[ -z "$1" && "$PWD" == "$repo"* && -x "$repo/scripts/k1/run_webots.sh" ]]; then
    "$repo/scripts/k1/run_webots.sh"
  else
    __NV_PRIME_RENDER_OFFLOAD=1 __GLX_VENDOR_LIBRARY_NAME=nvidia command webots "$@"
  fi
}
```

Open a **new terminal** (or `unalias webots; source ~/.bashrc`), then in `~/NUWebots_K1` just run `webots`.

---

## Troubleshooting

- **Any `NUbots_K1` `generic` build/run error** (`generate_generic_k1_toolchain.py: No such file`,
  `Could NOT find ALSA`, `No module named 'tools.utility'`, `compiled for x86-64 but running on x86_64`,
  `'kFP16' is not a member`, the `list()` `TypeError`, etc.) — see **"Building `NUbots_K1` `generic` from
  scratch — required patches"** above; they're all facets of the unfinished `generic_k1` platform.

- **K1 falls through the floor / `Skipped PROTO 'Floor'` / `unknown 'Pose' node`.**
  You're not using Booster's Webots build. Use `webots_updated.zip` via `setup_k1_sim.sh` (see §2).

- **`webots/keyboardwalk` connects but the K1 doesn't move / no `LowState`.**
  FastDDS shared-memory transport may not cross the Docker/host boundary even with `--network host`
  (separate `/dev/shm`). Fix by running with `--ipc=host`, or point both sides at a UDP-only FastDDS
  profile via `FASTRTPS_DEFAULT_PROFILES_FILE`.

- **Extern controller never connects.** Make sure Webots (Terminal A) is fully loaded and showing the
  "Waiting for connection … K1_v1" line *before* starting the runner (Terminal B).

---

## Known limitations / not done yet

- **No camera in the K1 sim.** `K1_v1.wbt` is a motion-only model (IMU/GPS/joints, no `Camera`), and `mck`
  doesn't forward images. So the full `robocup` role (vision → ball/field detection) has nothing to see in
  sim yet. Options: add a Webots `Camera` + bridge, or feed ground-truth ball/robot poses via a supervisor.
- **Single robot only.** The K1 world has one robot on DDS domain 0. A 1v1/4v4 world needs one `mck` per
  robot, each on a separate DDS domain, with `HardwareIO` taking the domain as config (currently hardcoded
  to `Init(0)`).
- **RoboCup field.** The K1 world is an empty office floor. Porting this repo's `RobocupSoccerField` /
  ball to the R2023b K1 world is straightforward and tracked as a follow-up.
