explain=""

function run_check() {
    if ! shell_output=$(az aks command invoke -n "${CLUSTER_NAME}" -g "${CLUSTER_RESOURCE_GROUP}" --command "kubectl get pdb -A -o json" -o json); then
        explain="Failed to retrieve PodDisruptionBudgets"
        echo 2
    fi

    local backup_file=${STAGING_DIR}/pdb-before.txt
    if [[ "$STAGE" == "postcheck" ]]; then
        backup_file=${STAGING_DIR}/pdb-after.txt
    fi

    # Extract the command output logs (containing the kubectl results)
    KUBECTL_OUTPUT=$(echo "$shell_output" | jq -r .logs)
    
    # Save PDB data to backup file
    echo "$KUBECTL_OUTPUT" > "$backup_file"

    # Check if command was successful
    exit_code=$(echo "$shell_output" | jq -r .exitCode)

    if [ "$exit_code" -eq 0 ]; then
        # Display PDB information in a tabular format
        echo "$KUBECTL_OUTPUT" | jq -r '"Name,Namespace,MinAvailable,MaxUnavailable,DisruptionAllowed", 
            "----,---------,------------,---------------,-----------------",
            (.items[] | "\(.metadata.name),\(.metadata.namespace),\(.spec.minAvailable // "-"),\(.spec.maxUnavailable // "-"),\(.status.disruptionsAllowed)")' | 
            column -t -s',' >&2
        
        # Process each PDB to check if any have 0 disruptions allowed
        readarray -t PDBS < <(echo "$KUBECTL_OUTPUT" | jq -c '.items[]')
        
        for PDB in "${PDBS[@]}"; do
            name=$(echo "$PDB" | jq -r '.metadata.name')
            namespace=$(echo "$PDB" | jq -r '.metadata.namespace')
            disruptionsAllowed=$(echo "$PDB" | jq -r '.status.disruptionsAllowed')
            
            if [[ "$disruptionsAllowed" =~ ^[0-9]+$ && "$disruptionsAllowed" == "0" ]]; then
                explain="PDB ${namespace}/${name} has ${disruptionsAllowed} disruptions allowed"
                echo 1
                break
            fi
        done
        echo 0 # No PDBs with 0 disruptions allowed found, return success
    else
        explain="Error: kubectl command failed with exit code ${exit_code} \nError details: $(echo "$OUTPUT" | jq -r .logs)"
        echo 2 # warning if kubectl command failed
    fi
}
