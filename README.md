# AKS Cluster Upgrade Automation

This project provides a Bash script to automate the process of upgrading Azure Kubernetes Service (AKS) clusters to newer Kubernetes versions.

## Overview

The `aks_upgrade.sh` script automates the following tasks:
- Verifying prerequisites (Azure CLI installed and user logged in)
- Gathering information about your AKS cluster
- Checking available Kubernetes versions
- Validating the target version for upgrade compatibility
- Executing the upgrade process
- Monitoring the upgrade status until completion
- Providing detailed logging throughout the process

## Project Structure

```
aks-upgrade-automation/
├── aks_upgrade.sh          # Main script
├── checks/                 # Directory containing modular check scripts
│   ├── check_prerequisites.sh        # Checks Azure CLI and login status
│   ├── check_cluster_exists.sh       # Verifies cluster exists
│   ├── check_current_version.sh      # Gets current Kubernetes version
│   ├── check_available_versions.sh   # Gets available versions
│   ├── check_target_version.sh       # Validates target version
│   ├── check_cluster_health.sh       # Checks cluster health status
│   └── check_user_permissions.sh     # Verifies user permissions
└── README.md               # Documentation
```

## Prerequisites

- Azure CLI installed on your system
- User must be logged in to Azure with appropriate permissions
- Permissions to perform AKS cluster upgrades

## Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/aks-upgrade-automation.git
   cd aks-upgrade-automation
   ```

2. Make the script executable:
   ```bash
   chmod +x aks_upgrade.sh
   ```

3. Make the check scripts executable:
   ```bash
   chmod +x checks/*.sh
   ```

## Usage

### Basic Usage

```bash
./aks_upgrade.sh -g <resource-group> -c <cluster-name>
```

This will upgrade your AKS cluster to the latest available Kubernetes version.

### Specifying a Target Version

```bash
./aks_upgrade.sh -g <resource-group> -c <cluster-name> -v <target-version>
```

### Available Options

| Option | Long Option | Description |
|--------|-------------|-------------|
| `-g` | `--resource-group` | Resource group of the AKS cluster (required) |
| `-c` | `--cluster-name` | Name of the AKS cluster (required) |
| `-v` | `--version` | Target Kubernetes version for upgrade (optional) |
| `-y` | `--yes` | Skip confirmation prompts |
| `-l` | `--log-file` | Specify log file name (default: aks_upgrade_YYYYMMDD_HHMMSS.log) |
| `-V` | `--verbose` | Enable verbose output |
| `-h` | `--help` | Display help message |

## Examples

### Upgrade to Latest Version

```bash
./aks_upgrade.sh -g myResourceGroup -c myAKSCluster
```

### Upgrade to Specific Version

```bash
./aks_upgrade.sh -g myResourceGroup -c myAKSCluster -v 1.25.6
```

### Upgrade Without Confirmation

```bash
./aks_upgrade.sh -g myResourceGroup -c myAKSCluster -y
```

### Specify Log File and Enable Verbose Output

```bash
./aks_upgrade.sh -g myResourceGroup -c myAKSCluster -l my_upgrade.log -V
```

## Modular Check System

The script uses a modular check system where each verification is performed by a separate script in the `checks/` directory. This approach offers several benefits:

1. **Maintainability**: Each check can be updated independently
2. **Extensibility**: New checks can be added without modifying the main script
3. **Reusability**: Check scripts can be reused in other projects
4. **Clarity**: Each check has a single responsibility

To add a new check, simply create a script in the `checks/` directory that defines a `run_check()` function which returns 0 for success or non-zero for failure.

## Logs

The script creates detailed logs of the upgrade process. By default, logs are written to a file named `aks_upgrade_YYYYMMDD_HHMMSS.log` in the current directory. You can specify a custom log file using the `-l` option.

## Error Handling

The script includes comprehensive error handling to:
- Validate command-line arguments
- Check prerequisites
- Verify version compatibility
- Monitor upgrade status
- Handle timeouts and failures

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Disclaimer

This script is provided as-is with no warranties. Always test in a development environment before using in production.

