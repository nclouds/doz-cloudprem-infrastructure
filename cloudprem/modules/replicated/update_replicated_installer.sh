#!/bin/bash
set -eoxu pipefail

GENERATE_SCRIPT='./kubernetes-yml-generate'
REPLICATED_VERSION='2.40.4'

curl -s "https://get.replicated.com/kubernetes-yml-generate?replicated_tag=$REPLICATED_VERSION" -o "$GENERATE_SCRIPT"

chmod +x "$GENERATE_SCRIPT"

$GENERATE_SCRIPT \
 ui_bind_port=32001 \
 storage_class=gp2 \
 > "charts/replicated/templates/replicated.yaml"

rm "$GENERATE_SCRIPT"
