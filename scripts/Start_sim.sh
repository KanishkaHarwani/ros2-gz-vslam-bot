#!/usr/bin/env bash
#
# start_sim.sh — bring up the full ros2-gz-vslam-bot stack in one shot:
#   1. launch_sim.launch.py   (gz-sim + robot_state_publisher + spawn + ros_gz_bridge)
#   2. rviz2                  (using config/view_bot.rviz)
#   3. joy_node                (raw joystick input)
#   4. teleop_twist_joy         (joystick -> /cmd_vel)
#
# Usage:
#   chmod +x start_sim.sh
#   ./start_sim.sh
#
# Ctrl+C once will stop everything this script started.

set -u

# ---- Adjust these if your setup differs ------------------------------
ROS_DISTRO_SETUP="/opt/ros/humble/setup.bash"
WORKSPACE_SETUP="$HOME/ros2_ws/install/setup.bash"
PACKAGE_NAME="ros2-gz-vslam-bot"
RVIZ_CONFIG="$HOME/learn_ws/src/${PACKAGE_NAME}/config/view_bot.rviz"

# teleop_twist_joy axis/button mapping — controller-specific, re-check
# with `ros2 topic echo /joy` if you switch controllers (see HANDOFF_VSLAM.md)
AXIS_LINEAR=1
AXIS_ANGULAR=0
SCALE_LINEAR=0.5
SCALE_ANGULAR=1.0
ENABLE_BUTTON=0
# ------------------------------------------------------------------------

echo "==> Sourcing ROS 2 environment"
if [ ! -f "$ROS_DISTRO_SETUP" ]; then
    echo "ERROR: $ROS_DISTRO_SETUP not found. Is ROS 2 Humble installed?"
    exit 1
fi
source "$ROS_DISTRO_SETUP"

if [ ! -f "$WORKSPACE_SETUP" ]; then
    echo "ERROR: $WORKSPACE_SETUP not found. Build the workspace first:"
    echo "  cd ~/ros2_ws && colcon build --packages-select ${PACKAGE_NAME}"
    exit 1
fi
source "$WORKSPACE_SETUP"

# Track child PIDs so we can clean up on exit
PIDS=()

cleanup() {
    echo ""
    echo "==> Shutting down..."
    for pid in "${PIDS[@]}"; do
        kill "$pid" 2>/dev/null
    done
    wait 2>/dev/null
    echo "==> Done."
}
trap cleanup INT TERM EXIT

echo "==> Launching Gazebo + robot_state_publisher + spawn + bridge"
ros2 launch "${PACKAGE_NAME}" launch_sim.launch.py &
PIDS+=($!)

# Give gz-sim + robot_description a few seconds before spawning RViz/teleop
# (per Runbook.md: a startup race here is normal on first boot)
echo "==> Waiting for sim to come up..."
sleep 8

if [ -f "$RVIZ_CONFIG" ]; then
    echo "==> Launching RViz2"
    rviz2 -d "$RVIZ_CONFIG" &
    PIDS+=($!)
else
    echo "WARNING: RViz config not found at $RVIZ_CONFIG — launching RViz2 with defaults"
    rviz2 &
    PIDS+=($!)
fi

echo "==> Launching joystick node"
ros2 run joy joy_node &
PIDS+=($!)

echo "==> Launching teleop_twist_joy"
ros2 run teleop_twist_joy teleop_node --ros-args \
    -p axis_linear.x:="${AXIS_LINEAR}" \
    -p axis_angular.yaw:="${AXIS_ANGULAR}" \
    -p scale_linear.x:="${SCALE_LINEAR}" \
    -p scale_angular.yaw:="${SCALE_ANGULAR}" \
    -p enable_button:="${ENABLE_BUTTON}" &
PIDS+=($!)

echo ""
echo "==> All nodes launched. Press Ctrl+C to stop everything."
wait
