# NUWebots K1

Webots simulation for the **Booster Robotics K1** humanoid, used by [NUbots](https://nubots.net) for
RoboCup development. Forked from [NUWebots](https://github.com/NUbots/NUWebots) (the NUgus simulation),
whose worlds and controllers remain here for the legacy R2022b setup.

<img width="1824" height="1578" alt="Screenshot from 2026-06-25 23-17-30" src="https://github.com/user-attachments/assets/d2fc64cd-0cc9-497d-aa42-38583c0da04a" />


## How it works

The K1 is **not** driven by this repo's NUgus TCP controllers. It uses the **Booster SDK over DDS** — the
same interface as the real robot:

```
Webots (K1 robot, controller "<extern>")
   |  libController
   v
 mck   Booster's runner: the K1's motion firmware (balancing/walking), run on your PC in sim
   |  Booster SDK over FastDDS (domain 0)
   v
 NUbots_K1   your robot code (walk / behaviour), sends high-level commands
```

- **Webots** simulates the K1's body; **`mck`** is the robot's onboard controller, run as a separate
  program in simulation; **NUbots** (the [`NUbots_K1`](https://github.com/NUbots/NUbots_K1) repo) sends
  high-level commands. NUbots talks the **same** SDK/DDS interface in sim and on the real robot.

## Quick start

Requirements: **Ubuntu 22.04, x86_64**. Full instructions — including the `NUbots_K1` build patches and the
`webots` launcher — are in **[docs/K1_WEBOTS_SETUP.md](docs/K1_WEBOTS_SETUP.md)**.

1. Download Booster's Webots files (their Webots build, the K1 world, the runner) — see the doc.
2. Install + stage them: `scripts/k1/setup_k1_sim.sh`
3. Open the K1 RoboCup world (this also starts `mck`): `scripts/k1/run_webots.sh`
   (or add the `webots` shell function from the doc and just run `webots` in this directory).
4. Drive it from `NUbots_K1`: `./b run webots/keyboardwalk`

## Layout

| Path | Description |
| --- | --- |
| `protos/robot/K1/` | The Booster K1 robot model (PROTO + meshes). |
| `worlds/k1_robocup.wbt` | RoboCup field + ball + goals + K1 robots (R2023b, for Booster's Webots). |
| `scripts/k1/` | Install/launch helpers: `setup_k1_sim.sh`, `run_webots.sh`, `run_runner.sh`. |
| `docs/K1_WEBOTS_SETUP.md` | Full setup, the `NUbots_K1` build patches, and troubleshooting. |
| `protos/`, `worlds/`, `controllers/` | Legacy NUgus models, worlds (`1v1.wbt`, `4v4.wbt`, …) and TCP controllers. |

## Legacy NUgus simulation

The original NUgus worlds and controllers remain for the R2022b RoboCup environment (a fork of the
[TC Webots fork](https://github.com/RoboCup-Humanoid-TC/webots)). For that setup, see the
[Webots NUbook page](https://nubook.nubots.net/guides/tools/webots-setup).
