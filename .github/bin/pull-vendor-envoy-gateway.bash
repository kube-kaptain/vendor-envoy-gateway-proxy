#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# postVersionsAndNaming hook: pulls the pinned vendor-envoy-gateway release
# (full version in src/upstream/version) and unpacks its manifests zip
# under ${OUTPUT_SUB_PATH}/vendor-envoy-gateway/. Then regenerates
# src/kubernetes/role-infra-manager.yaml and
# src/kubernetes/rolebinding-infra-manager.yaml from the pulled upstream
# manifests, swapping upstream identity labels for ours and pointing the
# rolebinding subject at ${RunPlatform}. Fails if those regenerated files
# differ from what's committed in src/kubernetes/.
#
set -euo pipefail

read -r full_tag < src/upstream/version

OWNER="kube-kaptain"
REPO="vendor-envoy-gateway"

asset_name="${REPO}-${full_tag}-manifests.zip"
asset_url="https://github.com/${OWNER}/${REPO}/releases/download/${full_tag}/${asset_name}"

target_dir="${OUTPUT_SUB_PATH}/vendor-envoy-gateway"
mkdir -p "${target_dir}"

echo "Pulling ${asset_name} from ${asset_url}..."
curl -fsSL "${asset_url}" -o "${target_dir}/${asset_name}"
unzip -q "${target_dir}/${asset_name}" -d "${target_dir}"
echo "Extracted ${asset_name} to ${target_dir}"

extracted_dir="${target_dir}/vendor-envoy-gateway"
modified_dir="${target_dir}/modified"
dest_dir="src/kubernetes"

mkdir -p "${modified_dir}"

transform_labels() {
  sed -E '
    s|^([[:space:]]+)app\.kubernetes\.io/instance: vendor-envoy-gateway$|\1app.kubernetes.io/upstream-instance: vendor-envoy-gateway\
\1app.kubernetes.io/instance: ${ProjectName}|
    s|^([[:space:]]+)app\.kubernetes\.io/version: (.*)$|\1app.kubernetes.io/upstream-version: \2\
\1app.kubernetes.io/version: "${Version}"|
  '
}

transform_labels < "${extracted_dir}/role-infra-manager.yaml" \
  > "${modified_dir}/role-infra-manager.yaml"

transform_labels < "${extracted_dir}/rolebinding-infra-manager.yaml" \
  | sed -E '/^subjects:/,$ s|namespace: '"'"'\$\{Environment\}'"'"'|namespace: '"'"'${RunPlatform}'"'"'|' \
  > "${modified_dir}/rolebinding-infra-manager.yaml"

cp "${modified_dir}/role-infra-manager.yaml" "${dest_dir}/role-infra-manager.yaml"
cp "${modified_dir}/rolebinding-infra-manager.yaml" "${dest_dir}/rolebinding-infra-manager.yaml"

if ! git diff --quiet -- "${dest_dir}"; then
  echo "ERROR: ${dest_dir} drifted from upstream-derived expected output." >&2
  echo "Run this hook locally and commit the regenerated files." >&2
  git --no-pager diff -- "${dest_dir}" >&2
  exit 1
fi

echo "src/kubernetes/ matches upstream-derived expected output"
