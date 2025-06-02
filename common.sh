AKS_API_VERSION=2025-03-01

declare -A AGENTPOOL_SUBNETS   # associative array to store agentpool subnet details
declare -A AGENTPOOL_SURGEIP_REQUIRED # associative array to store surge IPs required for each agentpool
declare -A SUBNET_AVAILABLE_IPS_COUNT   # associative array to store number of available IPs in each subnet
declare -A AGENTPOOL_SUBNET_NAME # associative array to store agentpool subnet names
declare -A AGENTPOOL_SUBNET_VNET # associative array to store agentpool subnet vnet names
declare -A AGENTPOOL_SUBNET_AVAILABLE_IPS # associative array to store available IPs in each agentpool subnet
declare -A AGENTPOOL_SUBNET_CIDR # associative array to store agentpool subnet CIDR
declare -A SUBNET_SIZE  # associative array to store size of each subnet
declare -A SUBNET_IP_IN_USE  # associative array to store number of IPs in use in each subnet
declare -A SUBNET_CIDR # associative array to store CIDR of each subnet


# dependency checks - ensure required commands are available
function check_dependencies() {
    local missing_deps=()
    
    # Check for required commands
    for cmd in jq az bc awk column; do
        if ! command -v $cmd &>/dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_error "Please install the required dependencies and try again."
        exit 1
    fi
}

function log() {
    local log_level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo -e "${timestamp} [${log_level}]: ${message}" # | tee -a "${LOG_FILE}"
}

function log_error() {
    log "ERROR" "${1}"
}


function log_info() {
    log "INFO" "${1}"
}

function log_success() {
    log "SUCCESS" "${1}"
}

function log_debug() {
    log "DEBUG" "${1}"
}

function print_header() {
    local message=$1
    echo -e "\n\e[1m\e[36m${message}\e[0m\n"
}

function print_subheader() {
    local message=$1
    echo -e "\n\e[1m\e[34m${message}\e[0m\n"
}


# function get AKS cluster and nodepool details
function get_cluster_info() {
    local output
    print_header "Fetching AKS cluster details..."

    if [ -n "${DEBUG}" ] && [ ${DEBUG} == "true" ]; then
        output=$(<'.cluster.json')
    else
        if ! output=$(az resource show --ids ${CLUSTER_RESOURCE_ID} --api-version=${AKS_API_VERSION}); then
            log_error "Failed to fetch AKS cluster details. Please check the resource ID."
            exit 1
        fi

        echo "$output" > .cluster.json
    fi

    CLUSTER_JSON=$output

    CLUSTER_NAME=$(echo $CLUSTER_JSON | jq -r '.name')
    CLUSTER_RESOURCE_GROUP=$(echo $CLUSTER_JSON | jq -r '.resourceGroup')
    CLUSTER_NETWORK_PLUGIN=$(echo $CLUSTER_JSON | jq -r '.properties.networkProfile.networkPlugin')
    CLUSTER_POWERSTATE=$(echo $CLUSTER_JSON | jq -r '.properties.powerState.code')
    CLUSTER_LOCATION=$(echo $CLUSTER_JSON | jq -r '.location')
    CLUSTER_PROVISIONING_STATE=$(echo $CLUSTER_JSON | jq -r '.properties.provisioningState')
    CLUSTER_NETWORK_PLUGIN_MODE=$(echo $CLUSTER_JSON | jq -r '.properties.networkProfile.networkPluginMode')
    CLUSTER_NETWORK_DATAPLANE=$(echo $CLUSTER_JSON | jq -r '.properties.networkProfile.networkDataplane')
    CLUSTER_NETWORK_POLICY=$(echo $CLUSTER_JSON | jq -r '.properties.networkProfile.networkPolicy')
    CLUSTER_REGION=$(echo $CLUSTER_JSON | jq -r '.location')
    CLUSTER_CURRENT_VERSION=$(echo $CLUSTER_JSON | jq -r '.properties.currentKubernetesVersion')

    CLUSTER_NODE_RESOURCE_GROUP=$(echo $CLUSTER_JSON | jq -r '.properties.nodeResourceGroup')

    AGENTPOOLS=$(echo $CLUSTER_JSON | jq -r '.properties.agentPoolProfiles[] | .name')

    get_agentpool_subnet
}

function get_agentpool_subnet() {
    local output
    print_header "Fetching AKS agentpool subnet details..."

    # get agentpool VMSS under AKS's node resource group
    if ! output=$(az vmss list --resource-group ${CLUSTER_NODE_RESOURCE_GROUP} -o json); then
        log_error "Failed to fetch VMSS details. Please check permission"
        exit 1
    fi

    # find the associated VMSS for each agentpool and get the subnet id
    for ap in $AGENTPOOLS; do

        subnet_id=$(echo "$output" | jq -r --arg ap "$ap" '
            .[] 
            | select(.tags["aks-managed-poolName"] == $ap)
            | .virtualMachineProfile.networkProfile.networkInterfaceConfigurations[0].ipConfigurations[0].subnet.id
        ')
    
        log_info "Agentpool: $ap, Subnet ID: $subnet_id"
        AGENTPOOL_SUBNETS[$ap]=$subnet_id

        # get agentpool's subnet name and size and store in arrays
        local subnet_name=$(echo "$subnet_id" | cut -d '/' -f 11)
        local subnet_vnet=$(echo "$subnet_id" | cut -d '/' -f 9)
        log_info "Agentpool: $ap, Subnet Name: $subnet_name"
        AGENTPOOL_SUBNET_NAME[$ap]=$subnet_name
        AGENTPOOL_SUBNET_VNET[$ap]=$subnet_vnet

        # Check if the key exists in the associative array before accessing it
        if [ ! ${SUBNET_AVAILABLE_IPS_COUNT[$subnet_name]+_} ]; then
            # Key doesn't exist, process this subnet
            local subnet_cidr=$(az network vnet subnet show --ids $subnet_id --query "addressPrefix" -o tsv)
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet CIDR: $subnet_cidr"

            local subnet_size=$(cidr_to_ips $subnet_cidr)
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet Size: $subnet_size"

            local subnet_ip_in_use=$(az network vnet subnet show --ids $subnet_id | jq '.ipConfigurations | length')
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet IPs in Use: $subnet_ip_in_use"

            SUBNET_CIDR[$subnet_name]=$subnet_cidr
            SUBNET_SIZE[$subnet_name]=$subnet_size
            SUBNET_IP_IN_USE[$subnet_name]=$subnet_ip_in_use
            SUBNET_AVAILABLE_IPS_COUNT[$subnet_name]=$(($subnet_size-$subnet_ip_in_use-4)) # 4 IPs are reserved for Azure services


            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet Available IPs: ${SUBNET_AVAILABLE_IPS_COUNT[$subnet_name]}"
        else
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} already processed. Showing data from cache."
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet Size: ${SUBNET_SIZE[$subnet_name]}"
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet IPs in Use: ${SUBNET_IP_IN_USE[$subnet_name]}"
            log_info "Agentpool: $ap, Subnet Name: ${subnet_name} Subnet Available IPs: ${SUBNET_AVAILABLE_IPS_COUNT[$subnet_name]}"
            
        fi

        AGENTPOOL_SUBNET_AVAILABLE_IPS[$ap]=${SUBNET_AVAILABLE_IPS_COUNT[$subnet_name]} # Copy from subnet cache
        AGENTPOOL_SUBNET_CIDR[${ap}]=${SUBNET_CIDR[${subnet_name}]} # Copy from subnet cache
    done

    # Loop through each agent pool to calculate surge IP requirements
    for ap in $AGENTPOOLS; do
        # Get the maxSurge value for the agent pool from the cluster JSON
        local maxSurge=$(echo "$CLUSTER_JSON" | jq -r --arg ap "$ap" '
            .properties.agentPoolProfiles[] 
            | select(.name == $ap)
            | .upgradeSettings.maxSurge
        ')

        # Get the node count for the agent pool
        local count=$(echo "$CLUSTER_JSON" | jq -r --arg ap "$ap" '
            .properties.agentPoolProfiles[] 
            | select(.name == $ap)
            | .count
        ')

        # If maxSurge is not set, default to 1 extra node
        if [[ "${maxSurge}" == "null" ]]; then
            maxSurge=1    # default surge value is one extra node
        # If maxSurge is a percentage, convert it to an integer value
        elif [[ "${maxSurge}" == *% ]]; then
            local surge=$(percent_to_float $maxSurge)
            maxSurge=$(echo "$count * $surge + 1" | bc | cut -d'.' -f 1)  # round up to nearest integer
        fi

        # Get the max pods per node for the agent pool
        local max_pods_per_node=$(echo "$CLUSTER_JSON" | jq -r --arg ap "$ap" '
            .properties.agentPoolProfiles[] 
            | select(.name == $ap)
            | .maxPods
        ')

        # If using Azure CNI and network plugin mode is null, calculate surge IPs as (maxSurge * (maxPods-1) + maxSurge)
        if [[ "${CLUSTER_NETWORK_PLUGIN}" == "azure" && "${CLUSTER_NETWORK_PLUGIN_MODE}" == "null" ]]; then
            AGENTPOOL_SURGEIP_REQUIRED[$ap]=$(($maxSurge * $(($max_pods_per_node-1))+$maxSurge))
        else
            # Otherwise, surge IPs required is just maxSurge
            AGENTPOOL_SURGEIP_REQUIRED[$ap]=$maxSurge
        fi
    done
}

function cidr_to_ips() {
  local prefix=${1##*/}
  echo $((2**(32 - prefix)))
}

function percent_to_float(){
    local percent=$1
    echo "$percent" | sed 's/%//' | awk '{printf "%.6f", $1/100}'
}


# this function creates a padding string of dots to align output to 65 characters
function padding() {
    local str="$1"
    local len=${#str}
    local pad=$((65 - len))

    if (( pad > 0 )); then
        # create a string of ‘pad’ dots and append
        local dots
        dots=$(printf '%*s' "$pad" '' | tr ' ' '.')
        echo "$dots "
    else
        # if already ≥80 chars, truncate to 80
        echo " "
    fi
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
        output="${output}\n${ap},${AGENTPOOL_SUBNET_VNET[${ap}]},${AGENTPOOL_SUBNET_NAME[${ap}]},${AGENTPOOL_SUBNET_CIDR[${ap}]},${AGENTPOOL_SUBNET_AVAILABLE_IPS[${ap}]},${AGENTPOOL_SURGEIP_REQUIRED[${ap}]},${has_enough_ips}"
    done
    echo -e "$output" | column -t -s','
    echo ""
}