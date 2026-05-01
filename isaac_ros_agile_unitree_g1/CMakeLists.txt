# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0

cmake_minimum_required(VERSION 3.16)
project(isaac_ros_agile_unitree_g1)
find_package(ament_cmake REQUIRED)

# Download AGILE velocity policy ONNX model from the WBC-AGILE repo at a pinned commit.
set(MODEL_URL "https://github.com/nvidia-isaac/WBC-AGILE/raw/ad4ff6ee6b38da207592b3e71dcee4c118049f6d/agile/data/policy/velocity_g1/unitree_g1_velocity_e2e.onnx")
set(MODEL_DOWNLOAD_DIR "${CMAKE_CURRENT_BINARY_DIR}/models")
set(MODEL_FILE "agile_velocity.onnx")
set(MODEL_EXPECTED_HASH "SHA256=8995f2462ba2d0d83afe08905148f6373990d50018610663a539225d268ef33b")
file(MAKE_DIRECTORY ${MODEL_DOWNLOAD_DIR})

if(NOT EXISTS "${MODEL_DOWNLOAD_DIR}/${MODEL_FILE}")
  message(STATUS "Downloading ${MODEL_FILE} from WBC-AGILE...")
  file(DOWNLOAD
    "${MODEL_URL}"
    "${MODEL_DOWNLOAD_DIR}/${MODEL_FILE}"
    EXPECTED_HASH ${MODEL_EXPECTED_HASH}
    STATUS DOWNLOAD_STATUS
    SHOW_PROGRESS
  )
  list(GET DOWNLOAD_STATUS 0 STATUS_CODE)
  if(NOT STATUS_CODE EQUAL 0)
    list(GET DOWNLOAD_STATUS 1 ERROR_MESSAGE)
    message(FATAL_ERROR "Failed to download ${MODEL_FILE}: ${ERROR_MESSAGE}")
  endif()
else()
  message(STATUS "Skipping ${MODEL_FILE} (already downloaded)")
endif()

# Install downloaded model alongside config YAML.
install(DIRECTORY ${MODEL_DOWNLOAD_DIR}/
  DESTINATION share/${PROJECT_NAME}/data
)

install(DIRECTORY data/ DESTINATION share/${PROJECT_NAME}/data
  PATTERN ".gitignore" EXCLUDE
)
ament_package()
