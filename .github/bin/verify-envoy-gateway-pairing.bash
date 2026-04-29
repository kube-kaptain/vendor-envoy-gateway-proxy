#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2025-2026 Kaptain contributors (Fred Cooke)
#
# Verifies the full image URI this repo retags matches what Envoy Gateway
# at the release pinned in src/upstream/version declares as its
# DefaultEnvoyProxyImage. Any drift between src/upstream/version and the
# KaptainPM.yaml retag source (registry + namespace + name + tag) fails
# the build so the produced tag cannot become a lie.
set -euo pipefail

read -r full_version < src/upstream/version
gateway_version="${full_version%.*}"
registry=$(yq -r '.spec.main.docker.retag.sourceRegistry' KaptainPM.yaml)
namespace=$(yq -r '.spec.main.docker.retag.sourceNamespace' KaptainPM.yaml)
image_name=$(yq -r '.spec.main.docker.retag.sourceImageName' KaptainPM.yaml)
source_tag=$(yq -r '.spec.main.docker.retag.sourceTag' KaptainPM.yaml)
expected="${registry}/${namespace}/${image_name}:${source_tag}"

url="https://raw.githubusercontent.com/envoyproxy/gateway/v${gateway_version}/api/v1alpha1/shared_types.go"
upstream=$(curl -fsSL "$url" \
  | grep -E '^\s*DefaultEnvoyProxyImage\s*=' \
  | sed -E 's/.*"([^"]+)".*/\1/')

if [[ -z "$upstream" ]]; then
  echo "DefaultEnvoyProxyImage not found in upstream shared_types.go at v${gateway_version} - upstream layout may have changed" >&2
  exit 1
fi

if [[ "$upstream" != "$expected" ]]; then
  echo "Pairing mismatch:" >&2
  echo "  src/upstream/version + upstream source: ${upstream}" >&2
  echo "  KaptainPM.yaml retag source:            ${expected}" >&2
  exit 1
fi

echo "Upstream pairing verified: ${expected}"
