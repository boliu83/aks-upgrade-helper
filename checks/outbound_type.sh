#!/bin/bash
# This script checks if a Kubernetes cluster is using loadBalancer as its outbound type.
# If so, it returns a warning status (2) indicating that an exception is required before upgrading.
# Otherwise, it returns an ok status (0).

explain="Output type is loadBalancer. Create exception before upgrade."

function run_check() {
    outbound_type=$(echo $CLUSTER_JSON | jq -r '.properties.networkProfile.outboundType')

    if [[ $outbound_type == "loadBalancer" ]]; then
        explain="Outbound type is loadBalancer. Exception required before upgrade. Please see <insert_link> for more details."
        echo 2 # Warning status
    else
        explain="Outbound type is not loadBalancer. No exception required."
        echo 0
    fi
}