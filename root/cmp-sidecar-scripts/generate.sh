#!/bin/bash

set -eu -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

VALUE_FILES=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "values-files").array | .[]' | xargs)
PARAMETERS=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "helm-parameters").map | to_entries | map("\(.key)=\(.value)") | .[] | "--set=" + .' | xargs) 
CLUSTER_NAME=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "cluster-name").string')
HELM_RELEASE_NAME=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "helm-release-name").string')
EXTERNAL_VALUES_FILES=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "external-values-files").array | .[]' | xargs)

echo "Helm Value Files: '${VALUE_FILES}'" >&2
echo "Helm Parameters: '${PARAMETERS}'" >&2
echo "Cluster Name: '${CLUSTER_NAME}'" >&2
echo "External Values Files: '${EXTERNAL_VALUES_FILES}'" >&2

mkdir -p "$EXTERNAL_FILES_DIR"

HELM_TEMPLATE_CMD_ARGS=()

HELM_TEMPLATE_CMD_ARGS+=("$HELM_RELEASE_NAME" . --namespace "$ARGOCD_APP_NAMESPACE")

if [ -n "$PARAMETERS" ]; then
    IFS=' ' read -r -a HELM_TEMPLATE_CMD_ARGS <<< "$PARAMETERS"
fi

if [ -n "$EXTERNAL_VALUES_FILES" ]; then
    "$SCRIPT_DIR/get-values-files.py" --output-dir "$EXTERNAL_FILES_DIR" "$EXTERNAL_VALUES_FILES"
fi

for value_files in $VALUE_FILES; do
    HELM_TEMPLATE_CMD_ARGS+=(--values "$value_files")
done

# append the external values files to the arguments. The external values files have to be converted to base64
for external_values_file in $EXTERNAL_VALUES_FILES; do
    base64_external_values_file=$(echo -n "$external_values_file" | base64 -w 0)
    HELM_TEMPLATE_CMD_ARGS+=(--values "$EXTERNAL_FILES_DIR/${base64_external_values_file}.yaml")
done

if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: cluster-name parameters is not set for AVP" >&2
    exit 1
else
    export AVP_PATH_VALIDATION="^argocd:k8s-(${CLUSTER_NAME}|global)\..+"
fi

echo "Helm Template Command Args: '${HELM_TEMPLATE_CMD_ARGS[*]}'" >&2

# Run helm template command and capture output
TEMPLATE_OUTPUT=$(helm template "${HELM_TEMPLATE_CMD_ARGS[@]}")

# Check if the template output is non-empty
if [ -z "$TEMPLATE_OUTPUT" ]; then
    echo "Error: Helm template output is empty" >&2
    exit 1
fi

echo "AVP_TYPE: '${AVP_TYPE}'" >&2
echo "AVP_PATH_VALIDATION: '${AVP_PATH_VALIDATION}'" >&2

# Pass the captured output to argocd-vault-plugin
echo "$TEMPLATE_OUTPUT" | argocd-vault-plugin generate -
