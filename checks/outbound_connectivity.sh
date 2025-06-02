

function check_https_dest() {
    dest=$1
    log_info "   Checking outbound connectivity to ${dest} ... "
    shell_output=`az aks command invoke -n ${CLUSTER_NAME} -g ${CLUSTER_RESOURCE_GROUP} --command "curl https://${dest}" -o json`

    if [ $(echo $shell_output | jq -r .exitCode) == 0 ] ; then 
        log_info "Outbound connectivity to https://${dest} is OK ✅"
        return 0
    else
        log_error "Outbound connectivity to https://${dest} is NOT OK ❌"
        echo "$shell_output" | jq -r .logs
        return 1
    fi
}

function validate_connectivity_tcp_inputs() {
    remote_ip="$1"
    remote_port="$2"
    if [[ -z "$remote_ip" || -z "$remote_port" ]]; then
        printf "Error: remote_ip and remote_port must be set.\n" >&2
        return 1
    fi

    if ! [[ "$remote_ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$|^(([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,})$ ]]; then
        printf "Error: Invalid IP or hostname format: %s\n" "$remote_ip" >&2
        return 1
    fi

    if ! [[ "$remote_port" =~ ^[0-9]+$ ]] || (( remote_port < 1 || remote_port > 65535 )); then
        printf "Error: Invalid port number: %s\n" "$remote_port" >&2
        return 1
    fi
}

function check_tcp_dest() {
    remote_ip="$1"
    remote_port="$2"
    log_info "Checking outbound TCP connectivity to ${remote_ip}:${remote_port} ... "
    shell_output=`az aks command invoke -n ${CLUSTER_NAME} -g ${CLUSTER_RESOURCE_GROUP} --command "curl -s --connect-timeout 5  https://${remote_ip}:${remote_port}" -o json`

    if curl -s --connect-timeout 5 "$remote_ip:$remote_port" >/dev/null; then
        log_info "Outbound connectivity to ${remote_ip}:${remote_port} is OK ✅"
        return 0
    fi

    log_error "Outbound connectivity to ${remote_ip}:${remote_port} is NOT OK ❌"
    return 1
}

function run_check() {
    local failed_count=0
    # check_https_dest "www.google.com"
    # failed_count=$((failed_count+$?))
    check_https_dest "packages.microsoft.com"
    failed_count=$((failed_count+$?))
    check_https_dest "www.faileddomain.com"
    failed_count=$((failed_count+$?))

    if [ -n "${ADD_CONNECTIVITY_CHECKS:-}" ]; then
        IFS=',' read -ra ADDR <<< "${ADD_CONNECTIVITY_CHECKS}"
        for i in "${ADDR[@]}"; do
        
            # if i begins with http:// or https://, remove the protocol prefix
            if [[ "$i" == http://* ]]; then
                i="${i#http://}"
            elif [[ "$i" == https://* ]]; then
                i="${i#https://}"
            fi

            # if i has a colon, assume it's an IP:port format and split it and call check_tcp_dest
            if [[ "$i" == *:* ]]; then
                remote_ip="${i%:*}"
                remote_port="${i#*:}"
                validate_connectivity_tcp_inputs "$remote_ip" "$remote_port"
                if [ $? -ne 0 ]; then
                    log_error "Invalid TCP destination format: $i"
                    continue
                fi
                check_tcp_dest "$remote_ip" "$remote_port"
                failed_count=$((failed_count+$?))
                continue
            else
                # otherwise assume it's a hostname for HTTPS check
                log_info "Adding additional connectivity check for destination: $i"
                check_https_dest "$i"
                failed_count=$((failed_count+$?))
            fi
        done
    fi
    if [ $failed_count -gt 0 ]; then
        log_error "Outbound connectivity check failed for ${failed_count} destinations."
        return 1 # error status
    else
        log_info "Outbound connectivity check passed for all destinations."
        return 0 # OK status
    fi
}