# Get all pods in the AKS cluster and save the output for further analysis
function run_check() {
    log_info "Retrieving all pods in the AKS cluster..."

    shell_output=$(az aks command invoke -n ${CLUSTER_NAME} -g ${CLUSTER_RESOURCE_GROUP} --command "kubectl get pods -A" -o json)

    if [ $(echo $shell_output | jq -r .exitCode) == 0 ] ; then
        echo "$shell_output" | jq -r '.logs' > ${STAGING_DIR}/pods.json
        echo "$shell_output" | jq -r '.logs'
    fi

    return 0 # always return 0, as this is just a check to gather information
}