# Gazebo ROS VSLAM

A ROS 2 + Gazebo (gz-sim) simulation project to develop and progressively
validate a Visual SLAM (VSLAM) pipeline, moving from teleop sanity checks
through flat-land VSLAM to full autonomy on rough terrain with real obstacles.

## Objective

Build and test a ground robot capable of visual SLAM-based localization and
mapping in simulation, validated stage-by-stage against odometry, then
extended toward obstacle detection, path planning, and full autonomy. See
[`ROADMAP.md`](./ROADMAP.md) for the full staged test plan.

## Robot Spec

| Aspect | Spec |
|---|---|
| Drivetrain | 4-wheel differential (skid-steer) drive |
| Cameras | 2x (front + back), 1920x1080 @ 60fps |
| Payload | None (no EO/additional sensor payload beyond the two cameras) |

**Open decisions to settle early:**
1. Front/back camera placement and FOV — overlapping (for stitching / 360
   coverage) or strictly opposite-facing?
2. `gz-sim-diff-drive-system` models 2 "sides," not 4 independently driven
   wheels with true skid physics — decide whether that approximation is
   acceptable, or whether a dedicated skid-steer plugin is needed for
   realistic slip (this matters for the odometry-comparison test).
3. Any additional sensors (IMU, wheel encoders beyond what the diff-drive
   plugin provides) needed for the odometry baseline in Test 2?

## Suggested Repository Structure

```
gazebo-ros-vslam/
├── description/          # xacro/urdf
│   ├── robot.urdf.xacro
│   ├── links.xacro
│   ├── joints.xacro
│   ├── materials.xacro
│   ├── gazebo_materials.xacro
│   ├── gazebo_control.xacro
│   └── gazebo_sensors.xacro
├── launch/
│   ├── rsp.launch.py
│   └── launch_sim.launch.py
├── config/
│   ├── gz_bridge.yaml
│   └── view_bot.rviz
├── worlds/
│   └── flatland.world     # + terrain worlds added per test stage
├── vslam/                 # VSLAM node configs / launch (once framework chosen)
├── docs/
│   ├── ROADMAP.md
│   └── test_logs/         # one dated log per test run, see ROADMAP.md
├── package.xml
└── CMakeLists.txt
```

## Software Stack (proposed)

- ROS 2 (Jazzy/Humble — confirm which distro you're targeting)
- Gazebo (gz-sim), `ros_gz_bridge`, `ros_gz_image`
- VSLAM framework — not yet chosen. Candidates:
  - **RTAB-Map** — easiest ROS 2 integration, RGB-D + stereo, built-in
    loop closure and occupancy-grid output (good fit for the mapping test)
  - **ORB-SLAM3** — strong monocular/stereo/VIO accuracy, more integration work
  - **OpenVSLAM** — flexible but less actively maintained
  - Aruco-based VSLAM — useful for early flat-land tests with markers before
    moving to natural-feature tracking

## References

1. Edge-Deployed 3D Vision and Localization for Autonomous Systems Software — https://github.com/maleehabee22seecs-hue/Edge-Deployed-3D-Vision-and-localization-for-Autonomous-Systems-Software
2. husky-gazebo-image-capture — https://github.com/WikiGenius/husky-gazebo-image-capture
3. Mono-SLAM — https://github.com/engyasin/mono-slam
4. OpenVSLAM — https://github.com/LongruiDong/openvslam
5. Aruco-based Visual SLAM — https://github.com/jim0002/aruco-based-visual-slam
6. VSLAM-Navigation — https://github.com/tranquykien/visual-slam-navigation

> Before pulling code from any of these into the repo, check each one's
> license and confirm compatibility with your intended license for this
> project.
