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
set -o pipefail  # Return value of a pipeline is the value of the last command to exit with non-zero status

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECKS_DIR="${SCRIPT_DIR}/checks"

# Load common functions and variables
source "${SCRIPT_DIR}/common.sh"

# results/output from certain checks are saved in STAGING_DIR to be upladed
# as pipeline artifacts
STAGING_DIR="${SCRIPT_DIR}/backup"
if [[ ! -d "${STAGING_DIR}" ]]; then
    mkdir -p "${STAGING_DIR}"
fi


# Default stage is precheck, can be set to "postcheck" for post-upgrade checks
# via command line
STAGE="precheck" 

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

FAILED_CHECKS=0

# Function to display script usage
function show_usage() {
    echo "Usage: $0 [options]"
    echo ""
    echo "Options:"
    echo "  -r, --resource-id      Resource ID of the AKS cluster"
    echo "  -t, --target-version   Target Kubernetes version for upgrade (optional)"
    echo "  -n, --node-os-upgrade  Upgrade node OS image on all nodepools to the latest version (optional)"
    echo "  -y, --yes              Skip confirmation prompts (not implemented yet)"
    echo "  -s, --stage            "precheck" or "postcheck". Default is precheck. "
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

# run all checks
function run_checks() {
    print_header "Running pre-upgrade checks..."
    
    # Source all check scripts from the checks directory
    for check_script in "${CHECKS_DIR}"/*.sh; do
        unset run_check
        check_script_name=$(basename "${check_script}")

        source "${check_script}"

        if [[  ! "$(type -t run_check)" == "function" ]]; then
            echo ""
            log_error "Check script ${check_script_name} does not define a valid run_check function."
            continue
        fi

        print_header "Run check in ${check_script_name}"
        run_check
        result=$?
        output="Running check: ${check_script_name} $(padding ${check_script_name})"
        echo -n $output
        case $result in
            0)
                echo -e "✅ \033[0;32m[PASSED]\033[0m"
                ;;
            1)
                echo -e "❌ \033[0;31m[FAILED]\033[0m"
                FAILED_CHECKS=$((FAILED_CHECKS + 1))     
                ;;
            2)
                echo -e "⚠️ \033[0;33m[WARN]\033[0m"
                ;;
            *)
                echo -e "❓ \033[0;33m[UNKNOWN]\033[0m"
                log_error "Unknown status for check: ${CHECK_RESULT_REASON}"
                ;;
        esac

    done
    if [[ ${FAILED_CHECKS} -gt 0 ]]; then
        log_error "Some pre-upgrade checks failed. Please review the output above."
        echo ""
        log_error "Please fix the issues and re-run the script."
        log_error "Exiting with error code 1."
        return 1
    fi
    log_success "All pre-upgrade checks passed."
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
        -s|--stage)
            STAGE="$2"
            shift 2
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
    log_info "    STAGE: ${STAGE}"
    if [ -n "${TARGET_VERSION}" ]; then
        log_info "    TARGET_VERSION: ${TARGET_VERSION}"
    else
        log_info "    TARGET_VERSION:  Not specified, will use latest available version."
    fi


    if [ -n "${NODE_OS_UPGRADE}" ]; then
        log_info "    NODE_OS_UPGRADE: ${NODE_OS_UPGRADE}"
    fi

    # exit immediately if neither target version nor node os upgrade is not specified
    if [ -z "${TARGET_VERSION}" ] && [ "${NODE_OS_UPGRADE}" != "true" ]; then
        log_info "Either TARGET_VERSION or NODE_OS_UPGRADE is set. Proceed with pre-upgrade checks only."
    fi


    # these functions are from common.sh
    get_cluster_info
    
    print_cluster_details

    print_agentpool_details

    # Run all checks
    run_checks
}


main