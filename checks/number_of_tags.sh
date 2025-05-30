
explain="Number of tags on this AKS resource is more than 20. Please remove some tags before upgrade."

function run_check() {
    # Get the number of tags on the AKS resource
    num_tags=$(echo $CLUSTER_JSON | jq -r '.tags | length')

    if [[ $num_tags -gt 0 ]]; then
        echo 1 # Warning status
    else
        echo 0 # OK status
    fi
}