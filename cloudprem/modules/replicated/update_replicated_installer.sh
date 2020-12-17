#!/bin/bash
set -eoxu pipefail

mkdir -p './replicated'
GENERATE_SCRIPT='./replicated/kubernetes-yml-generate'
REPLICATED_YAML='./replicated/replicated.yaml'
REPLICATED_HCL='replicated.tf'
REPLICATED_VERSION='2.40.4'

curl -s "https://get.replicated.com/kubernetes-yml-generate?replicated_tag=$REPLICATED_VERSION" \
 -o "$GENERATE_SCRIPT"

chmod +x "$GENERATE_SCRIPT"

$GENERATE_SCRIPT \
 ui_bind_port=32001 \
 storage_class=gp2 \
 > "$REPLICATED_YAML"

k2tf -f "$REPLICATED_YAML" -o $REPLICATED_HCL

rm -r replicated
