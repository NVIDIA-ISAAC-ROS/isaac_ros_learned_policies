#!/bin/bash
# SPDX-FileCopyrightText: Copyright (c) 2026 NVIDIA CORPORATION & AFFILIATES. All rights reserved.
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Download GR00T N1.7 Unitree G1 policy models from Hugging Face.
# Models and the LEAPP config are stored in the isaac_ros_assets directory.
# The script must be called with --eula before downloading.

set -e

ASSET_NAME="gr00t_unitree_g1"
VERSION="n17_apple_to_plate_0.0.2"

# Hugging Face source for the policy. The repository is public and downloads
# work anonymously.
#
# HF_REVISION is pinned to an immutable commit SHA for reproducibility: `main`
# would let any new commit or force-push silently swap the multi-GB policy that
# drives the physical G1. This SHA is the revision validated against NGC 0.0.2
# (identical checksums). Bump it together with the EXPECTED_SHA256 digests below
# only after re-validating a new revision.
HF_REPO="nvidia/GR00T-N1.7-ApplePnP-V1"
HF_REVISION="c3ba2c1dc19bd6543cc564702a8c23ca7e666659"
HF_RESOLVE_BASE_URL="https://huggingface.co/${HF_REPO}/resolve/${HF_REVISION}"
# shellcheck disable=SC2034
EULA_URL="https://huggingface.co/${HF_REPO}"

# Expected SHA256 digests for the essential policy files at HF_REVISION. The
# download is verified against these and fails fast on mismatch, so a corrupt
# CDN response (or a changed revision) never propagates to robot behavior.
# Metadata files (exported_leapp.png, log.txt) are intentionally omitted: they
# are best-effort and do not affect the policy.
declare -A EXPECTED_SHA256=(
  ["action_head.onnx"]="d7197cea807b237ae01949ef7513a237cdeddd6ef9befcd50915bfdf9d57e171"
  ["action_head.onnx.data"]="e089c3f6285bdd450d8713234320d80e532e5ed543ae05db392656e92c842457"
  ["backbone.onnx"]="c379156b18f4733b13ca03de537d0a44cddcef7a55fd2f7656651ad2808048c7"
  ["backbone.onnx.data"]="5ddea9f6b4efc6a22ea77e79c235db76848555482cef4d5d9e803167828a5a71"
  ["decode_action.onnx"]="9f96907df55558c09e11265b02bc97424f0b40ed57cac2d2f63b8c850b0e76c1"
  ["preprocess_state.onnx"]="81982f70fa8d62d36c3b47606c80dcc3c8cce08001e395348492ea7c402ffe6b"
  ["preprocess_video.onnx"]="1a86b4e215a09172e25fe02812c23d6b806b9065af71377832f60f3c841c612b"
  ["exported_leapp.yaml"]="40aecd3f6404f92e1578c1d7ca1596c8d7f9e4fb2cf227e1f1332230a987a43a"
)

if [ -z "$ISAAC_ROS_WS" ] && [ -n "$ISAAC_ROS_ASSET_MODEL_PATH" ]; then
  ISAAC_ROS_WS="$(readlink -f "$(dirname "${ISAAC_ROS_ASSET_MODEL_PATH}")/../../../..")"
fi

# Fail fast rather than resolving MODELS_DIR under the filesystem root ("/...")
# when neither ISAAC_ROS_WS nor ISAAC_ROS_ASSET_MODEL_PATH is set.
: "${ISAAC_ROS_WS:?ISAAC_ROS_WS is not set and could not be derived from ISAAC_ROS_ASSET_MODEL_PATH}"

MODELS_DIR="${ISAAC_ROS_WS}/isaac_ros_assets/models/${ASSET_NAME}"
ASSET_DIR="${MODELS_DIR}/${VERSION}"
# shellcheck disable=SC2034
ASSET_INSTALL_PATHS="${ASSET_DIR}/action_head.onnx ${ASSET_DIR}/action_head.onnx.data ${ASSET_DIR}/backbone.onnx ${ASSET_DIR}/backbone.onnx.data ${ASSET_DIR}/decode_action.onnx ${ASSET_DIR}/preprocess_state.onnx ${ASSET_DIR}/preprocess_video.onnx ${ASSET_DIR}/exported_leapp.yaml ${ASSET_DIR}/exported_leapp.png ${ASSET_DIR}/log.txt ${ASSET_DIR}/gr00t_n17_apple_to_plate.yaml"

# shellcheck disable=SC1090
source "${ISAAC_ROS_ASSET_EULA_SH:-isaac_ros_asset_eula.sh}"

# Verify a downloaded file against its recorded SHA256 digest. Files without a
# recorded digest (best-effort metadata) pass.
verify_sha256() {
  local file_path=$1
  local file_name=$2
  local expected=${EXPECTED_SHA256[$file_name]:-}
  if [[ -z ${expected} ]]; then
    return 0
  fi
  if ! echo "${expected}  ${file_path}" | sha256sum --check --status -; then
    echo "ERROR: SHA256 mismatch for ${file_name} (expected ${expected})." >&2
    return 1
  fi
}

download_hf_file() {
  local file_name=$1
  local output_path=$2
  local url="${HF_RESOLVE_BASE_URL}/${file_name}"
  # Download to a temporary path and only move it into place after a successful,
  # verified download, so a network drop mid-file never leaves a truncated file
  # that the cache check (-f) and the runtime would treat as valid.
  local tmp_path="${output_path}.part"
  local -a curl_args=(--fail --location --retry 3 --retry-delay 5 --progress-bar)

  if ! curl "${curl_args[@]}" "${url}" -o "${tmp_path}"; then
    rm -f "${tmp_path}"
    return 1
  fi
  if ! verify_sha256 "${tmp_path}" "${file_name}"; then
    rm -f "${tmp_path}"
    return 1
  fi
  mv -f "${tmp_path}" "${output_path}"
}

download_model() {
  local file_name=$1
  local cache_env=$2
  local output_path="${ASSET_DIR}/${file_name}"
  local cache_path="${!cache_env:-}"

  if [[ -n ${cache_path} && -f ${cache_path} ]]; then
    echo "Copying artifact from ${cache_path} to ${output_path}."
    cp "${cache_path}" "${output_path}"
    if ! verify_sha256 "${output_path}" "${file_name}"; then
      rm -f "${output_path}"
      return 1
    fi
    return 0
  fi

  echo "Downloading ${file_name} from ${HF_REPO}."
  if ! download_hf_file "${file_name}" "${output_path}"; then
    echo "ERROR: Failed to download ${file_name}." >&2
    return 1
  fi

  return 0
}

# Essential policy files: any failure (including a hash mismatch) aborts.
download_result=0
download_model "action_head.onnx" "ISAAC_ROS_GR00T_UNITREE_G1_ACTION_HEAD_ONNX" || download_result=$?
download_model "action_head.onnx.data" "ISAAC_ROS_GR00T_UNITREE_G1_ACTION_HEAD_ONNX_DATA" || download_result=$?
download_model "backbone.onnx" "ISAAC_ROS_GR00T_UNITREE_G1_BACKBONE_ONNX" || download_result=$?
download_model "backbone.onnx.data" "ISAAC_ROS_GR00T_UNITREE_G1_BACKBONE_ONNX_DATA" || download_result=$?
download_model "decode_action.onnx" "ISAAC_ROS_GR00T_UNITREE_G1_DECODE_ACTION_ONNX" || download_result=$?
download_model "preprocess_state.onnx" "ISAAC_ROS_GR00T_UNITREE_G1_PREPROCESS_STATE_ONNX" || download_result=$?
download_model "preprocess_video.onnx" "ISAAC_ROS_GR00T_UNITREE_G1_PREPROCESS_VIDEO_ONNX" || download_result=$?
download_model "exported_leapp.yaml" "ISAAC_ROS_GR00T_UNITREE_G1_EXPORTED_LEAPP_YAML" || download_result=$?

# Non-essential metadata: best-effort, so a trivial hiccup does not sink the
# whole multi-GB install.
download_model "exported_leapp.png" "ISAAC_ROS_GR00T_UNITREE_G1_EXPORTED_LEAPP_PNG" \
  || echo "WARNING: Failed to download exported_leapp.png (non-essential metadata); continuing." >&2
download_model "log.txt" "ISAAC_ROS_GR00T_UNITREE_G1_LOG" \
  || echo "WARNING: Failed to download log.txt (non-essential metadata); continuing." >&2

if [[ ${download_result} -ne 0 ]]; then
  exit ${download_result}
fi

# Expose the N1.7 export under the runtime config name expected by the launch files.
cp "${ASSET_DIR}/exported_leapp.yaml" "${ASSET_DIR}/gr00t_n17_apple_to_plate.yaml"

if [[ -n ${ISAAC_ROS_ASSETS_TEST:-} ]]; then
  exit 0
fi

echo "GR00T Unitree G1 assets installed in ${ASSET_DIR}."
