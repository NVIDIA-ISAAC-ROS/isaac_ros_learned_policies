# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.22.1)
project(isaac_ros_gr00t_unitree_g1_install)

find_package(ament_cmake_auto REQUIRED)
ament_auto_find_build_dependencies()

install_isaac_ros_asset(install_gr00t_unitree_g1)
install(PROGRAMS asset_scripts/install_gr00t_unitree_g1.sh DESTINATION lib/${PROJECT_NAME})

# Embed versioning information into installed files.
ament_index_get_resource(ISAAC_ROS_COMMON_CMAKE_PATH isaac_ros_common_cmake_path isaac_ros_common)
include("${ISAAC_ROS_COMMON_CMAKE_PATH}/isaac_ros_common-version-info.cmake")
generate_version_info(${PROJECT_NAME})

ament_auto_package(INSTALL_TO_SHARE)
