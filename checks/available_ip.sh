#!/bin/bash
# This script checks if each agent pool in an AKS cluster has enough available IPs in its subnet
function run_check() {
    has_enough_ips="true"
    for ap in $AGENTPOOLS; do
        if [[ "${AGENTPOOL_SUBNET_AVAILABLE_IPS[${ap}]}" -lt ${AGENTPOOL_SURGEIP_REQUIRED[${ap}]} ]]; then
            break # If any agent pool does not have enough available IPs, we break the loop
        fi
    done

    if [[ "${has_enough_ips}" == "true" ]]; then
        echo 0 # OK status
    else
        echo 1 # Failed status
    fi
}