function run_check() {
    lb_sku=$(az network lb list --resource-group "${CLUSTER_NODE_RESOURCE_GROUP}" --query "[?contains(name, 'kubernetes')].sku.name" -o tsv)

    # Check if the SKU is non-empty and not "Standard"
    # use case insensitive comparison
    lb_sku=$(echo "${lb_sku}" | tr '[:upper:]' '[:lower:]')
    if [[ -n "${lb_sku}" && "${lb_sku}" != "standard" ]]; then
        log_info "Warning: The load balancer SKU is set to '${lb_sku}'. It is recommended to use 'Standard' SKU for better performance and features."
        log_info "Azure Basic Load Balancer will be retired on 30 September 2025."
        return 2  # Return warning status
    fi

    log_info "Load balancer SKU is Standard. No action needed."
    return 0  # Return success status
}