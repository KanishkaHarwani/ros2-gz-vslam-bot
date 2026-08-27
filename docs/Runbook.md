# Runbook — ros2-gz-vslam-bot (Ignition Fortress + ROS 2 Humble)

Commands assume ROS 2 Humble and Ignition Fortress are already installed
system-wide, and your workspace is at `~/ros2_ws` (adjust paths as needed).

---

## 1. One-time setup

### 1.1 Install required packages
```bash
sudo apt update
sudo apt install -y \
  ros-humble-ros-gz \
  ros-humble-ros-gz-sim \
  ros-humble-ros-gz-bridge \
  ros-humble-ros-gz-image \
  ros-humble-robot-state-publisher \
  ros-humble-xacro \
  ros-humble-rviz2
```

### 1.2 Place the package in your workspace
```bash
cd ~/ros2_ws/src
# copy or clone ros2-gz-vslam-bot here so the tree looks like:
# ~/ros2_ws/src/ros2-gz-vslam-bot/{package.xml, CMakeLists.txt, description/, launch/, config/, worlds/}
```

### 1.3 Confirm mesh files are in place
```bash
ls ~/ros2_ws/src/ros2-gz-vslam-bot/description/meshes/
# Expect: base_link.stl, left_front_wheel_link.stl, right_front_wheel_link.stl,
# left_rear_wheel_link.stl, right_rear_wheel_link.stl, front_bumper_link.stl,
# front_rgbd_camera_link.stl, rear_rgbd_camera_link.stl,
# front_livox_lidar_link.stl, rear_livox_lidar_link.stl
```

### 1.4 Resolve dependencies and build
```bash
cd ~/ros2_ws
rosdep install --from-paths src --ignore-src -r -y
colcon build --packages-select ros2-gz-vslam-bot
```

---

## 2. Every-session boot sequence

### 2.1 Source your environment (every new terminal)
```bash
source /opt/ros/humble/setup.bash
source ~/ros2_ws/install/setup.bash
```

### 2.2 Launch the full sim stack
This one command starts `robot_state_publisher`, gz-sim with your world,
spawns the robot, and starts the ROS↔Gazebo bridge:
```bash
ros2 launch ros2-gz-vslam-bot launch_sim.launch.py
```

If gz-sim opens with an empty world and no robot, wait a few seconds —
`robot_description` needs to publish before the `create` node can spawn
against it; a race here is normal on first boot.

---

## 3. Verifying it's actually working

Open new terminals (each needs step 2.1 sourced) and check:

### 3.1 Gazebo-side topics
```bash
gz topic -l | grep -E "camera|lidar|odom|cmd_vel"
```
Confirm you see `camera/front/*`, `camera/rear/*`, `lidar/front/scan`,
`lidar/front/scan/points`, `lidar/rear/scan`, `lidar/rear/scan/points`.

### 3.2 ROS-side topics (after the bridge)
```bash
ros2 topic list
```
Confirm `/odom`, `/tf`, `/joint_states`, `/camera/front/image`,
`/camera/front/points`, `/lidar/front/scan`, `/lidar/front/points`, etc.
all appear.

### 3.3 Sanity-check odometry
```bash
ros2 topic echo /odom --once
```

### 3.4 Sanity-check a lidar scan
```bash
ros2 topic echo /lidar/front/scan --once
```

---

## 4. Driving the robot

### 4.1 One-off velocity command
```bash
ros2 topic pub --once /cmd_vel geometry_msgs/msg/Twist \
  "{linear: {x: 0.3}, angular: {z: 0.0}}"
```

### 4.2 Keyboard teleop (if installed)
```bash
sudo apt install -y ros-humble-teleop-twist-keyboard   # one-time
ros2 run teleop_twist_keyboard teleop_twist_keyboard
```

---

## 5. Visualizing in RViz2

```bash
rviz2 -d ~/ros2_ws/src/ros2-gz-vslam-bot/config/view_bot.rviz
```
(Adjust the path if `view_bot.rviz` ends up somewhere other than `config/`
in your final layout — see the open question in section 6.)

Fixed Frame is set to `odom`; enable/disable the point cloud and image
displays from the Displays panel as needed — they're off by default to
keep initial render load light.

---

## 6. Known open items (not yet resolved in this conversation)

- **`gz_bridge.yaml` location**: referenced throughout as `config/gz_bridge.yaml`
  per the README's suggested structure — confirm this matches where the
  file actually sits in your repo, or `launch_sim.launch.py`'s bridge node
  won't find it.
- **World staging**: `worlds/empty.world` only covers Stage 0 / Test 1–4
  (flat ground, no obstacles). Tests 5 onward in `Roadmap.md` need
  obstacle worlds; Test 8 needs rough terrain — neither exists yet.
- **4-wheel diff-drive approximation**: `gazebo_controls.xacro`'s DiffDrive
  plugin treats front+rear wheels per side as one "side" — no true
  independent 4-wheel skid-steer physics. Flagged in your own README as
  an open decision; revisit if Test 2's odometry-drift baseline looks off.

---

## 7. Troubleshooting quick reference

| Symptom | Likely cause |
|---|---|
| Robot doesn't spawn / gz-sim errors on mesh load | `package://` path mismatch — confirm `ros2-gz-vslam-bot` resolves via `ros2 pkg prefix ros2-gz-vslam-bot` and meshes are under `description/meshes/` |
| No camera/lidar data on any topic | Sensors system plugin missing `ogre2` render engine, or bridge node not running — check `gz topic -l` first to isolate Gazebo-side vs. bridge-side |
| Robot doesn't move on `/cmd_vel` | Check wheel joint names in `gazebo_controls.xacro` match `joints.xacro` exactly (`l_f_wheel_joint`, etc.) |
| RViz shows nothing under Fixed Frame `odom` | `/tf` not bridging — check `gz_bridge.yaml` has the `tf` entry and `gz topic -l` shows `/tf` being published |
