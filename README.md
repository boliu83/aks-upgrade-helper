# AKS Upgrade Helper

A comprehensive tool for validating and preparing Azure Kubernetes Service (AKS) clusters for version upgrades and node OS image updates.

## Overview

The AKS Upgrade Helper automates pre-upgrade validation checks to ensure your AKS clusters are ready for Kubernetes version upgrades or node OS image updates. It helps identify potential issues that could cause upgrade failures by running a series of checks on your cluster configuration.

Key features:
- Pre-upgrade validation checks to identify potential issues
- Support for both Kubernetes version upgrades and node OS image updates
- Extensible architecture for adding custom checks
- Detailed reporting of check results with clear pass/fail/warning indicators

## Prerequisites

- Azure CLI installed and configured
- User logged into Azure with appropriate permissions to:
  - View AKS cluster properties
  - Execute AKS commands (using `az aks command invoke`)
  - List VMSS/VMAS details

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/aks-upgrade-helper.git
   cd aks-upgrade-helper
   ```

2. Make the scripts executable:
   ```bash
   chmod +x aks-upgrade-helper.sh
   ```

## Usage

### Basic Usage

```bash
./aks-upgrade-helper.sh --resource-id <cluster-resource-id> [--target-version <version> | --node-os-upgrade]
```

### Command Line Options

| Option | Description |
|--------|-------------|
| `-r, --resource-id` | Resource ID of the AKS cluster (required) |
| `-t, --target-version` | Target Kubernetes version for upgrade (optional) |
| `-n, --node-os-upgrade` | Upgrade node OS image on all nodepools (optional) |
| `-s, --stage` | "precheck" (default) or "postcheck" |
| `-y, --yes` | Skip confirmation prompts (not implemented yet) |
| `-l, --log-file` | Custom log file path |
| `-V, --verbose` | Enable verbose output |
| `-h, --help` | Display help message |

### Examples

Run pre-upgrade checks for a Kubernetes version upgrade:
```bash
./aks-upgrade-helper.sh \
  --resource-id /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.ContainerService/managedClusters/{cluster-name} \
  --target-version 1.31.0
```

Run pre-upgrade checks for a node OS image upgrade:
```bash
./aks-upgrade-helper.sh \
  --resource-id /subscriptions/{sub-id}/resourceGroups/{rg-name}/providers/Microsoft.ContainerService/managedClusters/{cluster-name} \
  --node-os-upgrade
```

## Check System Architecture

The script uses a modular check system where each validation is performed by a separate script in the `checks/` directory. Each check script is automatically discovered and executed by the main script.

### How Checks Work

Each check script in the `checks` directory follows a simple pattern:

1. It must define a `run_check()` function that performs the validation
2. The function should return:
   - `0` for success (check passed ✅)
   - `1` for failure (check failed ❌, upgrade should not proceed)
   - `2` for warning (potential issue ⚠️, but upgrade can proceed)

The main script handles loading all checks, running them, and displaying the results.

## Adding Custom Checks

You can easily extend the tool by adding new check scripts to the `checks` directory:

1. Create a new Bash script in the `checks` directory
2. Define a `run_check()` function in your script
3. Return the appropriate status code based on check results

### Example: Creating a Custom Check

Here's a simple example of a check that verifies if there are enough available IPs in the subnet:

```bash
#!/bin/bash
# filepath: checks/available_ip.sh

function run_check() {
    log_info "Checking available IPs in subnet..."
    
    # Get subnet ID from the cluster
    local subnet_id=$(az aks show --ids "${CLUSTER_RESOURCE_ID}" \
        --query "networkProfile.networkPlugin" -o tsv)
    
    # Skip check if not using Azure CNI
    if [[ "${subnet_id}" != "azure" ]]; then
        log_info "Cluster is not using Azure CNI, skipping available IP check"
        return 0  # Success
    fi
    
    # Get subnet information and check available IPs
    local subnet_id=$(az aks show --ids "${CLUSTER_RESOURCE_ID}" \
        --query "networkProfile.networkConfig.podCidr" -o tsv)
    
    if [[ -n "${subnet_id}" ]]; then
        # Query for available IPs
        local available_ips=$(az network vnet subnet show \
            --ids "${subnet_id}" \
            --query "addressPrefix" -o tsv)
        
        # Perform check logic
        # ...logic to calculate available IPs...
        
        local min_required_ips=20
        if [[ ${available_ips} -lt ${min_required_ips} ]]; then
            log_error "Not enough available IPs in subnet. Found ${available_ips}, minimum required: ${min_required_ips}"
            return 1  # Failure
        else
            log_success "Sufficient IPs available in subnet: ${available_ips}"
            return 0  # Success
        fi
    else
        log_warn "Could not determine subnet configuration, skipping IP check"
        return 2  # Warning
    fi
}
```

Make it executable:
```bash
chmod +x checks/available_ip.sh
```

Now when you run the main script, it will automatically find and execute your new check.

## Project Structure

```
aks-upgrade-helper/
├── aks-upgrade-helper.sh       # Main script
├── common.sh                 # Common functions and utilities
├── README.md                 # Documentation
├── actions/                  # Action scripts for upgrade operations
│   └── monitor_upgrade.sh    # Script to monitor upgrade progress
├── checks/                   # Pre-upgrade validation checks
│   ├── available_ip.sh       # Check for available IPs in subnet
│   ├── check_pdb.sh          # Validate PodDisruptionBudgets
│   ├── msi_on_vmas.sh        # Check for MSI on VMAS clusters
│   ├── nginx_ingress_version.sh  # Validate NGINX ingress compatibility
│   ├── number_of_tags.sh     # Check for resource tag limits
│   ├── outbound_connectivity.sh  # Validate outbound connectivity
│   └── outbound_type.sh      # Check outbound type configuration
└── s/                        # Staging directory for outputs (used by ADO pipeline)
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request with new checks or improvements.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

