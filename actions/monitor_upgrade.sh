
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMMON_LIB="${SCRIPT_DIR}/../common.sh"

source ${COMMON_LIB}
# Function to monitor upgrade status
function monitor_upgrade() {
    log_info "Monitoring upgrade status..."
    
    local upgrade_complete=false
    local timeout_seconds=3600  # 1 hour timeout
    local start_time=$(date +%s)
    local current_time

    
    
    while [ "$upgrade_complete" = false ]; do
        current_time=$(date +%s)
        if [ $((current_time - start_time)) -gt $timeout_seconds ]; then
            log_error "Upgrade monitoring timed out after ${timeout_seconds} seconds."
            exit 1
        fi
        
        local status=$(az resource show --id ${cluster_resource_id} \
            --query "properties.provisioningState" --api-version=${AKS_API_VERSION} -o tsv)
        
        if [ "$status" = "Succeeded" ]; then
            local current_version=$(get_current_version)
            if [ "$current_version" = "$TARGET_VERSION" ]; then
                upgrade_complete=true
            else
                log_info "Cluster is in Succeeded state but version is still ${current_version}. Continuing to monitor..."
            fi
        elif [ "$status" = "Failed" ]; then
            log_error "Upgrade failed. Please check Azure portal for details."
            exit 1
        else
            log_info "Current status: ${status}. Waiting..."
        fi
        
        if [ "$upgrade_complete" = false ]; then
            sleep 30  # Check every 30 seconds
        fi
    done
    
    log_success "Upgrade completed successfully!"
}

cluster_resource_id=$1
monitor_upgrade "${cluster_resource_id}"

