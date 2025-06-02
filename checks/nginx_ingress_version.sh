# This script checks the compatibility of Ingress-NGINX versions with a specified Kubernetes version.
# In its current form, it prints the Ingress-NGINX versions and their corresponding Helm chart 
# versions that are compatible with the provided Kubernetes version.
# 
# Users are expected to manually verify the compatibility of their Ingress-NGINX setup with the
# Kubernetes version.


IFS=$'\n\t'

# Embedded version mapping: Ingress-NGINX Version | K8s Versions | Helm Chart Version
# Source: https://github.com/kubernetes/ingress-nginx/blob/main/README.md#supported-versions-table
read -r -d '' INGRESS_DATA <<'EOF'
v1.12.2|1.32,1.31,1.30,1.29,1.28|4.12.2
v1.12.1|1.32,1.31,1.30,1.29,1.28|4.12.1
v1.12.0|1.32,1.31,1.30,1.29,1.28|4.12.0
v1.12.0-beta.0|1.32,1.31,1.30,1.29,1.28|4.12.0-beta.0
v1.11.6|1.30,1.29,1.28,1.27,1.26|4.11.6
v1.11.5|1.30,1.29,1.28,1.27,1.26|4.11.5
v1.11.4|1.30,1.29,1.28,1.27,1.26|4.11.4
v1.11.3|1.30,1.29,1.28,1.27,1.26|4.11.3
v1.11.2|1.30,1.29,1.28,1.27,1.26|4.11.2
v1.11.1|1.30,1.29,1.28,1.27,1.26|4.11.1
v1.11.0|1.30,1.29,1.28,1.27,1.26|4.11.0
v1.10.6|1.30,1.29,1.28,1.27,1.26|4.10.6
v1.10.5|1.30,1.29,1.28,1.27,1.26|4.10.5
v1.10.4|1.30,1.29,1.28,1.27,1.26|4.10.4
v1.10.3|1.30,1.29,1.28,1.27,1.26|4.10.3
v1.10.2|1.30,1.29,1.28,1.27,1.26|4.10.2
v1.10.1|1.30,1.29,1.28,1.27,1.26|4.10.1
v1.10.0|1.29,1.28,1.27,1.26|4.10.0
v1.9.6|1.29,1.28,1.27,1.26,1.25|4.9.1
v1.9.5|1.28,1.27,1.26,1.25|4.9.0
v1.9.4|1.28,1.27,1.26,1.25|4.8.3
v1.9.3|1.28,1.27,1.26,1.25|4.8.*
v1.9.1|1.28,1.27,1.26,1.25|4.8.*
v1.9.0|1.28,1.27,1.26,1.25|4.8.*
v1.8.4|1.27,1.26,1.25,1.24|4.7.*
v1.7.1|1.27,1.26,1.25,1.24|4.6.*
v1.6.4|1.26,1.25,1.24,1.23|4.5.*
v1.5.1|1.25,1.24,1.23|4.4.*
v1.4.0|1.25,1.24,1.23,1.22|4.3.0
v1.3.1|1.24,1.23,1.22,1.21,1.20|4.2.5
EOF


function list_ingress_and_helm_versions() {
    local k8s_version=$1

    if [[ -z "$k8s_version" ]]; then
        log_error "Error: Kubernetes version is required as argument.\n" >&2
        return 1
    fi

    # remove patch version if present
    k8s_version=${k8s_version%%.*}.$(echo "$k8s_version" | cut -d'.' -f2)

    if ! [[ "$k8s_version" =~ ^1\.[0-9]{1,2}$ ]]; then
        log_error "Error: Invalid Kubernetes version format. Expected format: 1.xx (e.g., 1.28)\n" >&2
        return 1
    fi

    local match_found=0
    local line ingress_version versions helm_version

    log_info "Ingress-NGINX versions compatible with Kubernetes version: $k8s_version"
    log_info "Ingress-NGINX Version     Helm Chart Version"
    log_info "---------------------     -----------------------"
    while IFS= read -r line; do
        ingress_version=${line%%|*}
        versions=${line#*|}
        helm_version=${versions##*|}
        versions=${versions%|*}

        if grep -q "\b${k8s_version}\b" <<< "${versions//,/ }"; then
            log_info $(printf "   %-18s       %s\n" "$ingress_version" "$helm_version")
            match_found=1
        fi
    done <<< "$INGRESS_DATA"

    if [[ $match_found -eq 0 ]]; then
        log_error "No matching Ingress-NGINX versions found for Kubernetes version: %s\n" "$k8s_version" >&2
        return 1
    fi
}


function run_check() {
    local k8s_version=$TARGET_VERSION

    if [[ -z "$k8s_version" ]]; then
        log_error "Error: Kubernetes version is required as argument.\n" >&2
        return 2
    fi

    log_info "Checking Ingress-NGINX versions compatible with Kubernetes version: $k8s_version"
    list_ingress_and_helm_versions "$k8s_version"
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to list Ingress-NGINX versions."
        return 2
    fi

    return 2 # Indicating a warning, as this is not a failure but an informational check.
}