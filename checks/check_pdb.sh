function run_check() {

    local shell_output kubectl_output backup_file exit_code failed=0

    log_info "Running \"az aks command invoke ...\" to get PDBs in cluster ${CLUSTER_NAME} in resource group ${CLUSTER_RESOURCE_GROUP}"
    shell_output=$(az aks command invoke -n "${CLUSTER_NAME}" -g "${CLUSTER_RESOURCE_GROUP}" --command "kubectl get pdb -A -o json" -o json)

    # Check if command was successful
    exit_code=$(echo "$shell_output" | jq -r .exitCode)

    if [ "$exit_code" -ne 0 ]; then
        log_warn "Error: kubectl command failed with exit code ${exit_code} \nError details: $(echo "$OUTPUT" | jq -r .logs)"
        return 2
    fi

    kubectl_output=$(echo "${shell_output}" | jq -r .logs)

    # backup the pdb
    echo $kubectl_output > "${STAGING_DIR}/${STAGE}/pdbs.json"

    echo "$kubectl_output" | jq -r '"Name,Namespace,MinAvailable,MaxUnavailable,DisruptionAllowed",
        "----,---------,------------,---------------,-----------------",
        (.items[] | "\(.metadata.name),\(.metadata.namespace),\(.spec.minAvailable // "-"),\(.spec.maxUnavailable // "-"),\(.status.disruptionsAllowed)")' |
        column -t -s','

    # Process each PDB to check if any have 0 disruptions allowed
    readarray -t pdbs < <(echo "$kubectl_output" | jq -c '.items[]')

    for pdb in "${pdbs[@]}"; do
        name=$(echo "$pdb" | jq -r '.metadata.name')
        namespace=$(echo "$pdb" | jq -r '.metadata.namespace')
        disruptionsAllowed=$(echo "$pdb" | jq -r '.status.disruptionsAllowed')

        if [[ "$disruptionsAllowed" == "0" ]]; then
            log_error "PDB ${namespace}/${name} has ${disruptionsAllowed} disruptions allowed"
            failed=1
        fi
    done

    if [[ ${failed} -eq 1 ]]; then
        return 1 # failed
    else
        return 0 # successful
    fi
}