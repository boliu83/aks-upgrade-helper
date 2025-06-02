

function run_check() {
    # Get the number of tags on the AKS resource
    num_tags=$(echo $CLUSTER_JSON | jq -r '.tags | length')
    log_info "Number of tags on AKS resource: ${num_tags}. Max allowed is 20."
    if [[ $num_tags -gt 20 ]]; then
        return 1 # error status
    else
        return 0 # OK status
    fi
}