# Roadmap

Staged test plan. Each stage lists a goal, prerequisites, and success
criteria so you can tell when it's actually done and not just "ran once."
Log results under `docs/test_logs/`.

## Stage 0 — Robot Description
**Goal:** Build the URDF/xacro for the target robot: 4-wheel diff drive,
front + back cameras at 1080p/60fps, no additional payload.
**Success criteria:**
- Robot spawns in Gazebo without warnings/errors
- `ros2 topic hz /camera_front/image` and `/camera_back/image` both hold
  steady near 60Hz
- `ros2 topic echo /odom` shows sane values while teleop-driving in a straight
  line and while turning

## Test 1 — Gazebo + Joystick Control
**Goal:** Confirm the robot drives correctly via joystick/teleop in a basic
world.
**Prerequisites:** Stage 0 complete.
**Success criteria:**
- Straight-line drive, in-place rotation, and combined motion all behave as
  expected with no visual jitter or joint errors
- `joy` → `cmd_vel` → `DiffDrive` plugin path confirmed end-to-end
- Sim real-time factor logged with both cameras streaming (early warning for
  whether 1080p/60fps dual-camera is sim-performance-viable)

## Test 2 — Recording + Pose Comparison
**Goal:** Record odometry and camera data while driving a known path, and
establish a baseline pose-drift measurement to compare later VSLAM output
against.
**Prerequisites:** Test 1 passing.
**Success criteria:**
- Bag captures `/odom`, `/tf`, both camera topics, `/joint_states` at
  expected rates
- Drift (end-position error vs. known ground-truth path) is measured and
  recorded as the baseline number for later comparison

## Test 3 — Basic Map Generation (2D or 3D)
**Goal:** Produce a first map from a driven run, validating the mapping
pipeline mechanics.
**Prerequisites:** Test 1 passing.
**Success criteria:**
- A 2D occupancy grid or 3D point-cloud map is produced from a teleop run
- Map is visually recognizable (features/shapes at correct relative
  positions)

## Test 4 — VSLAM on Flatland with Shapes
**Goal:** First VSLAM run — flat ground plane, simple high-contrast shapes
as visual features, no obstacles to avoid yet.
**Prerequisites:** VSLAM framework chosen and built; Test 1 passing.
**Success criteria:**
- VSLAM produces a pose estimate that tracks without losing localization
  over a full driven loop
- Estimated trajectory compared against the Test 2 odometry baseline and
  against Gazebo ground-truth pose — record error metrics (e.g. ATE/RPE)

## Test 5 — + Obstacle Detection
**Goal:** Add obstacles to the flatland world; detect them (not yet avoid).
**Prerequisites:** Test 4 passing.
**Success criteria:**
- Obstacles appear correctly in the generated map/point cloud
- Detection pipeline flags obstacle presence within a defined range with an
  acceptable false-positive/negative rate on a fixed obstacle set

## Test 6 — + Path Planning (goal-directed)
**Goal:** Given a specified goal pose, plan and execute a path around known
obstacles.
**Prerequisites:** Test 5 passing; a planner (e.g. Nav2) integrated with the
VSLAM-derived map/costmap.
**Success criteria:**
- Robot reaches a specified goal without collision across several
  goal/obstacle configurations

## Test 7 — + Auto Path Planning (autonomous goal selection)
**Goal:** Robot selects its own goals (e.g. frontier exploration) rather
than being given a fixed target.
**Prerequisites:** Test 6 passing.
**Success criteria:**
- Robot autonomously explores and maps the environment without a
  human-specified goal, terminating when a defined coverage threshold is met

## Test 8 — Full Autonomy, Real Terrain, Multiple Obstacles
**Goal:** Combine everything on a non-flat terrain world with multiple,
varied obstacles — the integration test.
**Prerequisites:** Tests 4–7 all passing individually.
**Success criteria:**
- Robot completes autonomous exploration/navigation on terrain without
  manual intervention, with mapping and localization error within the
  bounds established in Test 4

---

## Open Decisions to Log Before Starting
- ROS 2 distro and Gazebo version pin
- VSLAM framework choice (see README references)
- Ground-truth source for pose error measurement (Gazebo's own pose
  publisher is the simplest option)
- Definition of "sufficient coverage" for Test 7's termination condition
