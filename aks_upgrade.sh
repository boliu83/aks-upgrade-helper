#!/bin/bash
#####################################################################
# AKS Cluster Upgrade Automation Script
# 
# Description: This script automates the process of upgrading an
#              Azure Kubernetes Service (AKS) cluster to a specified version
#              or upgrade node OS image on all nodepools to the latest version. 
#
# Prerequisites:
#   - Azure CLI installed and configured
#   - User logged into Azure account with appropriate permissions
#
# Usage: ./aks_upgrade.sh [options]
#
# Options:
#   -r, --resource-id      Resource ID of the AKS cluster
#   -t, --target-version    Target Kubernetes version for upgrade (optional)
#   -n, --node-os-upgrade   Upgrade node OS image on all nodepools to the latest version (optional)
#   -y, --yes               Skip confirmation prompts (not implemented yet)
#   -l, --log-file          Specify custom log file path
#   -V, --verbose           Enable verbose output
#   -h, --help              Display help message
#####################################################################

set -u  # Treat unset variables as an error
set -e  # Exit immediately if a command exits with a non-zero status
set -o pipefail  # Return value of a pipeline is the value of the last command to exit with non-zero status

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="${SCRIPT_DIR}/checks"

# Load common functions and variables
source "${SCRIPT_DIR}/common.sh"

STAGING_DIR="${SCRIPT_DIR}/s"
if [[ ! -d "${STAGING_DIR}" ]]; then
    mkdir -p "${STAGING_DIR}"
fi


STAGE="precheck" # Default stage is precheck, can be set to postcheck for post-upgrade checks


# check for required dependencies
check_dependencies

# Default values
CLUSTER_RESOURCE_ID=""
RESOURCE_GROUP=""
CLUSTER_NAME=""
TARGET_VERSION=""
SKIP_CONFIRMATION=false # not implemented yet
LOG_FILE="aks_upgrade_$(date +%Y%m%d_%H%M%S).log"
VERBOSE=false
NODE_OS_UPGRADE=false
DEBUG=false

# Function to display script usage
function show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -r, --resource-id      Resource ID of the AKS cluster"
    echo "  -t, --target-version   Target Kubernetes version for upgrade (optional)"
    echo "  -n, --node-os-upgrade  Upgrade node OS image on all nodepools to the latest version (optional)"
    echo "  -y, --yes              Skip confirmation prompts (not implemented yet)"
    echo "  -V, --verbose          Enable verbose output"
    echo "  -h, --help             Display this help message"
    echo ""
    echo -e "Examples:"
    echo "  - Cluster upgrade: "
    echo "    $0 -r /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.ContainerService/managedClusters/{aks-cluster} --target-version <target-version>"
    echo ""
    echo "  - Node OS image upgrade: "
    echo "    $0 -r /subscriptions/{subscription-id}/resourceGroups/{resource-group}/providers/Microsoft.ContainerService/managedClusters/{aks-cluster} --node-os-upgrade"
    echo ""

}

# Function to show cluster and nodepool details
function print_cluster_details() {
cat <<EOF | column -t -s','
Cluster Name:,${CLUSTER_NAME}
Resource Id:,${CLUSTER_RESOURCE_ID}
Region:,${CLUSTER_REGION}
Cluster Power State:,${CLUSTER_POWERSTATE}
Cluster Current Version:,${CLUSTER_CURRENT_VERSION}
Cluster Provisioning State:,${CLUSTER_PROVISIONING_STATE}
Network Plugin:,${CLUSTER_NETWORK_PLUGIN}
Network Plugin Mode:,${CLUSTER_NETWORK_PLUGIN_MODE}
Network Dataplane:,${CLUSTER_NETWORK_DATAPLANE}
Network Policy:,${CLUSTER_NETWORK_POLICY}
EOF
}

function print_agentpool_details() {
    print_header "Agentpool Details"
    echo $CLUSTER_JSON | jq -r '
        "Name,ProvisioningState,NodeOSImage,Version,Count,MaxPods,MaxSurge,Zones",
        "----,-----------------,-----------,-------,-----,-------,--------,-----",
        (.properties.agentPoolProfiles[] |
            "\(.name),\(.provisioningState),\(.nodeImageVersion),\(.currentOrchestratorVersion),\(.count),\(.maxPods),\(.upgradeSettings.maxSurge),\(.availabilityZones)"
        )
    ' | column -t -s','

    print_header "Agentpool Subnet Details"
    local output="Agentpool,Vnet,Subnet,CIDR,AvailableIPs,SurgeIPsRequired,HasEnoughIP\n--------,----,------,----,-------------,-----------------,-------"
    for ap in $(echo "${AGENTPOOLS}"); do

        local has_enough_ips=false
        [[ ${AGENTPOOL_SUBNET_AVAILABLE_IPS[${ap}]} -gt ${AGENTPOOL_SURGEIP_REQUIRED[${ap}]} ]] && has_enough_ips=true
        # Use the correct variable name for subnet available IPs
        output="${output}\n${ap},${AGENTPOOL_SUBNET_VNET[${ap}]},${AGENTPOOL_SUBNET_NAME[${ap}]},${AGENTPOOL_SUBNET_CIDR[${ap}]},${AGENTPOOL_SUBNET_AVAILABLE_IPS[${ap}]},${AGENTPOOL_SURGEIP_REQUIRED[${ap}]},${has_enough_ips}"
    done
    echo -e "$output" | column -t -s','
    echo "==================================================================="
}


# run all checks
function run_checks() {
    print_header "Running pre-upgrade checks..."
    
    # Source all check scripts from the checks directory
    for check_script in "${CHECKS_DIR}"/*.sh; do
        if [ -f "${check_script}" ]; then
        
            check_name=$(basename "${check_script}")

            # Source the check script
            unset explain
            unset run_check

            source "${check_script}"
            if [[  ! "$(type -t run_check)" == "function" ]]; then
                echo ""
                log_error "Check script ${check_name} does not define a valid run_check function."
                continue
            fi

            result=$(run_check)
            output="Running check: ${check_name} $(padding ${check_name})"
            echo -n $output
            case $result in
                0)
                    echo -e "✅ \033[0;32m[PASSED]\033[0m"
                    ;;
                1)
                    echo -e "❌ \033[0;31m[FAILED]\033[0m"
                    echo "    > ${explain}"
                    ;;
                2)
                    echo -e "⚠️ \033[0;33m[WARN]\033[0m"
                    echo "    > ${explain}"
                    ;;
                *)
                    echo -e "❓ \033[0;33m[UNKNOWN]\033[0m"
                    log_error "Unknown status for check: ${result}"
                    ;;
            esac
        fi
        echo "" # Print a new line for better readability
    done
    
    log_success "All pre-upgrade checks passed. "
    return 0
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -r|--resource-id)
            CLUSTER_RESOURCE_ID="$2"
            shift 2
            ;;
        -t|--target-version)
            TARGET_VERSION="$2"
            shift 2
            ;;
        -n|--node-os-upgrade)
            NODE_OS_UPGRADE=true
            shift
            ;;
        -y|--yes)
            SKIP_CONFIRMATION=true
            shift
            ;;
        -l|--log-file)
            LOG_FILE="$2"
            shift 2
            ;;
        -V|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

# Main execution
function main() {
    echo "==================================================================="
    echo "         AKS Cluster Upgrade Helper"
    echo "==================================================================="

    # Check for required parameters
    if [ -z "${CLUSTER_RESOURCE_ID}" ]; then
        log_error "Cluster resource ID is required."
        show_usage
        exit 1
    fi
    
    log_info "Script started with:"
    log_info "    CLUSTER_RESOURCE_ID: ${CLUSTER_RESOURCE_ID}"
    if [ -n "${TARGET_VERSION}" ]; then
        log_info "    TARGET_VERSION: ${TARGET_VERSION}"
    else
        log_info "    TARGET_VERSION:  Not specified, will use latest available version."
    fi


    if [ -n "${NODE_OS_UPGRADE}" ]; then
        log_info "    NODE_OS_UPGRADE: ${NODE_OS_UPGRADE}"
    fi

    # exit immediately if neither target version nor node os upgrade is not specified
    if [ -z ${TARGET_VERSION} ] && [ -z ${NODE_OS_UPGRADE} != "true" ]; then
        log_error "Either TARGET_VERSION or NODE_OS_UPGRADE must be specified."
        exit 1
    fi


    get_cluster_info
    print_cluster_details
    print_agentpool_details

    # Run all checks
    if ! run_checks; then
        log_error "Pre-upgrade checks failed. Exiting."
        exit 1
    fi

    
    log_info "Pre-upgrade checks passed. Proceeding with upgrade."
}

# Run main function
main