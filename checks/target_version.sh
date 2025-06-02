# check if TARGET_VERSION is available in the AKS cluster

function run_check() {
    if [[ -z "$TARGET_VERSION" ]]; then
        log_error "Error: TARGET_VERSION is not set. Please provide a valid Kubernetes version." >&2
        return 2
    fi

    log_info "Checking if TARGET_VERSION $TARGET_VERSION is available in the AKS cluster..."
    
    # Check if the version is available in the AKS cluster
    local available_versions=$(az aks get-versions --location ${CLUSTER_LOCATION} --query "values[*].patchVersions[]" -o json | jq -r '.[] | keys[]')
    
    if echo "$available_versions" | grep -q "$TARGET_VERSION"; then
        log_info "TARGET_VERSION $TARGET_VERSION is available."
        return 0
    else
        log_error "TARGET_VERSION $TARGET_VERSION is not available for AKS upgrade."
        return 1
    fi
}