#!/bin/bash

set -eu -o pipefail

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

# we xargs the output to make them space separated vs new line
ARGUMENTS=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "values-files").array | .[] | "--values=" + .' | xargs)
PARAMETERS=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "helm-parameters").map | to_entries | map("\(.key)=\(.value)") | .[] | "--set=" + .' | xargs) 
CLUSTER_NAME=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "cluster-name").string')
HELM_RELEASE_NAME=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "helm-release-name").string')
EXTERNAL_VALUES_FILES=$(echo "$ARGOCD_APP_PARAMETERS" | jq -r '.[] | select(.name == "external-values-files").array | .[]' | xargs)

echo "Helm Arguments: '${ARGUMENTS}'" >&2
echo "Helm Parameters: '${PARAMETERS}'" >&2
echo "Cluster Name: '${CLUSTER_NAME}'" >&2
echo "External Values Files: '${EXTERNAL_VALUES_FILES}'" >&2

mkdir -p "$EXTERNAL_FILES_DIR"

if [ -n "$EXTERNAL_VALUES_FILES" ]; then
    "$SCRIPT_DIR/get-values-files.py" --output-dir "$EXTERNAL_FILES_DIR" "$EXTERNAL_VALUES_FILES"
fi

# append the external values files to the arguments. The external values files have to be converted to base64
for external_values_file in $EXTERNAL_VALUES_FILES; do
    base64_external_values_file=$(echo -n "$external_values_file" | base64 -w 0)
    ARGUMENTS="$ARGUMENTS --values $EXTERNAL_FILES_DIR/${base64_external_values_file}.yaml"
done

if [ -z "$CLUSTER_NAME" ]; then
    echo "Error: cluster-name parameters is not set for AVP" >&2
    exit 1
else
    export AVP_PATH_VALIDATION="^argocd:k8s-(${CLUSTER_NAME}|global)\..+"
fi

HELM_TEMPLATE_CMD="helm template --debug \"$HELM_RELEASE_NAME\" . --namespace \"$ARGOCD_APP_NAMESPACE\""

if [ -n "$ARGUMENTS" ]; then
    HELM_TEMPLATE_CMD="$HELM_TEMPLATE_CMD $ARGUMENTS"
fi

if [ -n "$PARAMETERS" ]; then
    HELM_TEMPLATE_CMD="$HELM_TEMPLATE_CMD $PARAMETERS"
fi

echo "Helm Template Command: '${HELM_TEMPLATE_CMD}'" >&2

# Run helm template command and capture output
TEMPLATE_OUTPUT=$(eval "$HELM_TEMPLATE_CMD")

# Check if the template output is non-empty
if [ -z "$TEMPLATE_OUTPUT" ]; then
    echo "Error: Helm template output is empty" >&2
    exit 1
fi

echo "AVP_TYPE: '${AVP_TYPE}'" >&2
echo "AVP_PATH_VALIDATION: '${AVP_PATH_VALIDATION}'" >&2

# Pass the captured output to argocd-vault-plugin
echo "$TEMPLATE_OUTPUT" | argocd-vault-plugin generate -