# Webots

This is the Webots world, models and controllers for simulating the NUbots robots.
It also contains a fork of the [TC Webots fork](https://github.com/RoboCup-Humanoid-TC/webots), with some changes. This allows us to run the Official RoboCup Webots simulation environment with our robot.

The field environment was developed by Cyberbotics and the Humanoid TC for RoboCup 2021 (Humanoid League).

## Booster K1 simulation

The team is moving to the **Booster K1** platform. The K1 does **not** use this repo's NUgus TCP
controllers — it is driven through the **Booster SDK over DDS**, with Booster's `mck` runner acting as the
Webots `<extern>` controller (the same interface as the real robot). NUbots connects from the
[`NUbots_K1`](https://github.com/NUbots/NUbots_K1) repo.

- **Requirements:** Ubuntu 22.04, x86_64.
- **Setup + run:** see **[docs/K1_WEBOTS_SETUP.md](docs/K1_WEBOTS_SETUP.md)**.
- **Scripts:** `scripts/k1/setup_k1_sim.sh` (install from the downloaded Booster files), then
  `scripts/k1/run_webots.sh` and `scripts/k1/run_runner.sh`.

The NUgus worlds/controllers below remain for the legacy RoboCup (R2022b) setup.

## File System

| Folder         | Description                                                                                                                          |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| controllers    | Controller files written in C++. These connect to a model, eg the robot model, and determine how it works.                           |
| protos         | Proto files, which define the models for objects.                                                                                    |
| worlds         | World files, which are opened in Webots and define what is in the environment and how the environment initialises.                   |
| shared/utility | C++ utility functions.                                                                                                               |
| scripts        | Scripts to make certain tasks easier (like creating new controllers).                                                                |
| webots         | The Webots simulator and RoboCup environment, from [the TC Webots fork](https://github.com/RoboCup-Humanoid-TC/webots) with changes. |

## Set Up

For set up information, visit the [Webots NUbook page](https://nubook.nubots.net/guides/tools/webots-setup).