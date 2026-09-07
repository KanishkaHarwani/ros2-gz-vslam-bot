# Handoff — ros2-gz-vslam-bot Sim Debugging

Project: 4-wheel skid-steer robot, ROS 2 Humble + Ignition Gazebo Fortress,
being built for a staged VSLAM test plan (see `Roadmap.md`). This doc covers
a debugging pass through spawn physics, collision geometry, wheel joints,
and teleop control. Currently stuck on two open issues (bottom of doc) —
pick up there.

---

## Files changed so far (all fixes applied and confirmed working, except where noted)

### `description/links.xacro`
- Replaced all mesh-based `<collision>` geometry with primitives (visuals
  untouched — still the original STLs):
  - Chassis: box `1.35 x 0.75 x 0.30`, origin at inertial origin
    `xyz="0.000973 0.000007 0.486096"`.
  - Each wheel: cylinder `radius=0.225 length=0.125`, oriented
    `rpy="1.5708 0 0"` (axis along wheel's rotation axis), origin offset
    to match each wheel's own `<inertial>` Y-offset (`±0.11207`) — the
    joint/link origin is at the wheel's inner mounting face, not its
    geometric center, so collision origin ≠ `0 0 0`.
  - Each camera: box `0.045 x 0.15 x 0.045`, origin `z=0.0225`.
  - Each lidar: cylinder `radius=0.05 length=0.075`, origin `z=0.0375`.
  - Front bumper: box `0.12 x 0.95 x 0.5`, origin at inertial origin.
- **Correction made mid-conversation:** originally shifted the chassis
  collision box up to `z=0.61` to avoid overlapping the wheels — this was
  based on a wrong assumption. Parent link and its directly-jointed child
  links (wheels are children of `base_link` via wheel joints) are excluded
  from self-collision checks **by default** in Gazebo's physics backends,
  so the box was reverted to the inertial origin. No further action needed
  here unless new geometric overlap issues appear elsewhere.

### `description/joints.xacro`
- All four wheel joints' `<axis>` unified to `xyz="0.0 1.0 0.0"`.
  Originally front pair (`l_f`, `r_f`) used `+Y` and rear pair (`l_r`, `r_r`)
  used `-Y` — this made front and rear wheels on the same side spin
  opposite physical directions under the same DiffDrive command. Confirmed
  fixed by user (wheels now visibly move correctly).

### `description/gazebo_controls.xacro`
- `wheel_radius` corrected from `0.075` to `0.225` (was wildly mismatched
  from the actual wheel geometry — confirmed via inertia back-calculation:
  `r = sqrt(2 * Iyy / m)`).
- Added the `JointStatePublisher` plugin (was missing entirely — `/joint_states`
  was bridged in `gz_bridge.yaml` but nothing published it):
  ```xml
  <plugin filename="libignition-gazebo-joint-state-publisher-system.so"
          name="ignition::gazebo::systems::JointStatePublisher">
    <topic>joint_states</topic>
  </plugin>
  ```
- **NOT YET APPLIED (see open issue #1 below):** `wheel_separation` still
  reads `0.65`, needs updating to `0.874` (`2 × (0.325 + 0.11207)`, the true
  physical track width now that wheel collision origins are corrected).
  This was identified as the likely cause of the current wobble but hasn't
  been confirmed to fix it — see below.

### `launch/launch_sim.launch.py`
- Added `-z 0.05` to the spawn node's arguments — small clearance margin
  above the ground plane so the first physics step doesn't resolve an
  interpenetrating contact at spawn.
- Added `SetEnvironmentVariable('IGN_GAZEBO_RESOURCE_PATH', ...)` pointed
  at the parent of the installed package share directory. This was
  required for Gazebo to resolve the `model://ros2-gz-vslam-bot/...` URIs
  that `ros_gz_sim` rewrites from the URDF's `package://` mesh paths —
  without it, all visual meshes failed to load (confirmed fixed; meshes
  render correctly now).

---

## Confirmed working end-to-end
- Spawn is stable (no launch-into-orbit / physics explosion).
- All visual meshes render.
- `/joint_states`, `/odom`, `/tf`, camera and lidar bridges all create
  without error per `gz_bridge.yaml`.
- `joy_node` → `/joy` confirmed publishing real controller data.
- `teleop_node` (note: **not** `teleop_twist_joy_node` — that name doesn't
  exist in this install; the correct executable is `teleop_node`) → `/cmd_vel`
  confirmed publishing, with working `enable_button` dead-man's switch.
- Forward/backward driving works correctly and wheels spin the correct
  physical direction on all four corners.
- Robot does rotate in place when given a yaw command (confirms `/cmd_vel`
  angular.z is reaching the DiffDrive plugin correctly) — see open issue #1
  for the quality problem with this rotation.

Working teleop launch command reference:
```bash
ros2 run joy joy_node
ros2 run teleop_twist_joy teleop_node --ros-args \
  -p axis_linear.x:=1 \
  -p axis_angular.yaw:=0 \
  -p scale_linear.x:=0.5 \
  -p scale_angular.yaw:=1.0 \
  -p enable_button:=0
```
(Axis/button indices were confirmed correct for the user's specific
controller via `ros2 topic echo /joy` — button/axis numbers are
controller-specific, re-verify if switching controllers.)

---

## OPEN ISSUE #1 — Robot wobbles/rocks front-to-back while rotating in place

**Symptom:** Commanding pure yaw (`angular.z` nonzero, `linear.x = 0`) does
rotate the chassis, but it visibly rocks/swings front-to-back while doing so
instead of pivoting cleanly.

**Diagnosis so far, not yet confirmed fixed:**
`gazebo_controls.xacro`'s `<wheel_separation>` is still `0.65`, but the true
physical track width (center-to-center distance between left and right wheel
contact points) is `0.874` now that wheel collision origins have been
corrected to match each wheel's real center (`±0.11207` offset from the
joint origin — see `links.xacro` notes above). The DiffDrive plugin uses
`wheel_separation` to convert commanded angular velocity into per-side wheel
speeds; a mismatch between this kinematic parameter and the real contact
geometry is a very plausible cause of an unclean pivot.

**Next step:** update `gazebo_controls.xacro`:
```xml
<wheel_separation>0.874</wheel_separation>
```
Rebuild, relaunch, retest pure-yaw rotation. **This has not been tried yet
in this conversation — do this first in the new chat.**

**If wobble persists after that fix**, next suspects in priority order:
1. **Joint damping** — none of the four wheel joints in `joints.xacro` have
   a `<dynamics>` block. Try adding:
   ```xml
   <axis xyz="0.0 1.0 0.0"/>
   <dynamics damping="1.0" friction="0.1"/>
   ```
   to each wheel joint. No point trying this before the wheel_separation
   fix — don't tune damping against an already-wrong kinematic parameter.
2. **Ground friction coefficients** — no `<surface><friction>` values are
   set anywhere on the wheel collisions; Gazebo is using ODE defaults.
   Skid-steer turning fundamentally relies on lateral friction to pivot the
   chassis; if defaults are inadequate for this robot's mass (185 kg) this
   could produce instability. Would need explicit `<ode><mu>/<mu2></ode>`
   tuning on wheel `<collision><surface>` blocks — not yet attempted.
3. Possible remaining chassis mass/inertia mismatch — the chassis box's
   inertia only matched the stated `<inertial>` values to ~8% in earlier
   back-calculation (see conversation history); worth revisiting if 1 and 2
   don't resolve it.

---

## OPEN ISSUE #2 — Lidar and camera depth output not working

**Symptom:** Reported at the same time as issue #1 — lidar and the depth
portion of the RGBD cameras aren't producing data. Not yet diagnosed in
this conversation at all — this is a fresh problem to start on.

**Not yet checked, do these first:**
1. Confirm topics are actually publishing at the Gazebo level before
   assuming a bridge problem:
   ```bash
   gz topic -l | grep -E "camera|lidar"
   gz topic -echo -t /lidar/front/scan -n 1
   gz topic -echo -t /camera/front/depth_image -n 1
   ```
   If nothing publishes here, the problem is in the sensor plugin
   config (`gazebo_sensors.xacro`) or the render engine, not the ROS bridge.
2. If Gazebo-side topics ARE publishing but ROS-side (`ros2 topic echo
   /lidar/front/scan`, `/camera/front/depth_image`) are empty, the problem
   is in `gz_bridge.yaml` — check `gz_type_name`/`ros_type_name` pairings
   match exactly, and check `parameter_bridge` node's terminal output for
   bridge creation errors at launch (was clean on last confirmed run, but
   re-check after any changes).
3. **Rendering engine note:** earlier in this conversation, the launch log
   showed `libEGL warning: egl: failed to create dri2 screen` — i.e. this
   machine appears to be running Gazebo's GUI on software rendering rather
   than a GPU. Depth cameras and GPU lidar sensors (`gpu_lidar` sensor type,
   as configured in `gazebo_sensors.xacro`) are more likely to fail or
   produce empty output under software rendering than plain RGB cameras.
   This is a strong candidate root cause and hasn't been investigated yet —
   check `glxinfo | grep "direct rendering"` and confirm whether proper GPU
   acceleration is available to the Gazebo process.
4. If GPU rendering isn't available, options are: fix the GPU/driver setup,
   or accept CPU-based rendering fallback if gz-sim supports it for these
   sensor types (needs research — not yet confirmed either way).

---

## Deferred items (raised earlier, not urgent, still outstanding)

- **Filename check:** confirm the actual xacro file on disk is named
  `robot.urdf.xacro` (dot) — `rsp.launch.py` expects this exact name.
  Uploaded project file was named `robot_urdf.xacro` (underscore); never
  confirmed which is actually correct on the user's filesystem.
- **Package rename:** `ros2-gz-vslam-bot` uses hyphens, not valid ROS 2
  package-name convention. Works today but will break if any Python node
  is added later (can't `import` a hyphenated package name). Would require
  updating `package.xml`, `CMakeLists.txt`, every `package://` mesh URI,
  and `package_name` in the launch file.
- **`flatland.world`:** contains a dangling absolute mesh path
  (`/home/kanishka/.ignition/fuel/...`) that won't resolve on this machine,
  plus an entire unrelated baked-in robot model (`explorer_r2_sensor_config_1`)
  left over from what looks like a stale Gazebo-classic scene export. Only
  matters once the project reaches Roadmap.md's Stage 5+ obstacle tests,
  which need an obstacle world — `empty.world` (currently used) has none.
  Needs cleanup before use.
- **Sensor `<visualize>` flags:** all four sensors in `gazebo_sensors.xacro`
  have `<visualize>true</visualize>`, adding GUI render overhead. Worth
  flipping to `false` once sensor data is confirmed flowing correctly
  (relevant once Open Issue #2 above is resolved).
- **GUI segfault on Gazebo close:** seen once in an early launch log,
  traced to Qt/QML teardown during process exit, correlated with the
  software-rendering warning above. Did not affect the running simulation.
  Only worth chasing if it becomes disruptive — may resolve itself once
  proper GPU rendering is sorted out for Open Issue #2.

---

## Suggested order of attack in the new chat

1. Apply `wheel_separation` fix (Open Issue #1) — quick, high-confidence.
2. Retest rotation. If fixed, move to #2. If not, try joint damping, then
   friction tuning.
3. Start Open Issue #2 with the `gz topic` checks above to isolate
   Gazebo-side vs. bridge-side vs. rendering-side.
4. Once both are resolved, the robot should be ready for `Roadmap.md`'s
   Test 1 success criteria (straight-line, in-place rotation, combined
   motion all clean; RTF logged with both cameras streaming).
