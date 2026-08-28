import os

from ament_index_python.packages import get_package_share_directory

from launch import LaunchDescription
from launch.actions import IncludeLaunchDescription, SetEnvironmentVariable
from launch.launch_description_sources import PythonLaunchDescriptionSource

from launch_ros.actions import Node


def generate_launch_description():

    package_name = 'ros2-gz-vslam-bot'

    # Tell Gazebo where to resolve model:// URIs from. ros_gz_sim rewrites the
    # URDF's package:// mesh paths into model://ros2-gz-vslam-bot/... when
    # converting to SDF, so Gazebo needs the *parent* of the installed share
    # directory on its resource path to find the "ros2-gz-vslam-bot" folder.
    gz_resource_path = SetEnvironmentVariable(
        'IGN_GAZEBO_RESOURCE_PATH',
        os.path.join(get_package_share_directory(package_name), '..')
    )

    # Include the robot_state_publisher launch file, provided by this package. Force sim time on.
    rsp = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([os.path.join(
            get_package_share_directory(package_name), 'launch', 'rsp.launch.py'
        )]), launch_arguments={'use_sim_time': 'true'}.items()
    )

    # Include ros_gz_sim's launch file to start the gz-sim server + GUI with a world
    world_path = os.path.join(
        get_package_share_directory(package_name), 'worlds', 'empty.world'
    )

    gz_sim = IncludeLaunchDescription(
        PythonLaunchDescriptionSource([os.path.join(
            get_package_share_directory('ros_gz_sim'), 'launch', 'gz_sim.launch.py'
        )]),
        launch_arguments={'gz_args': f'-r {world_path}'}.items()
    )

    # Spawn the robot into gz-sim from the /robot_description topic.
    # -z 0.05 gives a small clearance margin above the ground plane so the
    # first physics step doesn't resolve an interpenetrating contact.
    spawn_entity = Node(
        package='ros_gz_sim',
        executable='create',
        arguments=[
            '-topic', 'robot_description',
            '-name', 'my_bot',
            '-z', '0.05'
        ],
        output='screen'
    )

    # Bridge gz-transport <-> ROS 2 topics using config/gz_bridge.yaml
    bridge_config = os.path.join(
        get_package_share_directory(package_name), 'config', 'gz_bridge.yaml'
    )

    gz_bridge_node = Node(
        package='ros_gz_bridge',
        executable='parameter_bridge',
        parameters=[{
            'config_file': bridge_config,
            'use_sim_time': True,
        }],
        output='screen'
    )

    # Launch them all!
    return LaunchDescription([
        gz_resource_path,
        rsp,
        gz_sim,
        spawn_entity,
        gz_bridge_node,
    ])
