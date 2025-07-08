# This check verifies the outbound type configuration of the AKS cluster.
# If the outbound type is set to "loadBalancer", it indicates that an exception is required before upgrading the cluster.
# This is important to ensure that the upgrade process does not encounter issues related to the outbound connectivity configuration.
#
# For detailed information on the outbound type and its implications, please refer to the documentation: <insert_link>  

function run_check() {
    log_info "Checking outbound type for AKS cluster ${CLUSTER_NAME} in resource group ${CLUSTER_RESOURCE_GROUP}"
    outbound_type=$(echo $CLUSTER_JSON | jq -r '.properties.networkProfile.outboundType')

    if [[ $outbound_type == "loadBalancer" ]]; then
        log_warn "Outbound type is loadBalancer. Exception required before upgrade. Please see <insert_link> for more details."
        return 2 # Warning status for outboundType loadBalancer. we don't want to block the upgrade, but we need to warn the user.
    else
        return 0
    fi
}