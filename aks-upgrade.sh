#!/bin/bash


# check if CLUSTER_NAME and CLUSTER_RESOURCE_GROUP are set, if not, try to get them from the environment variable CLUSTER_RESOURCE_ID
if [ -z "${CLUSTER_NAME}" ] || [ -z "${CLUSTER_RESOURCE_GROUP}" ]; then
    if [ -n "${CLUSTER_RESOURCE_ID}" ]; then
        CLUSTER_NAME=$(echo "${CLUSTER_RESOURCE_ID}" | awk -F'/' '{print $9}')
        CLUSTER_RESOURCE_GROUP=$(echo "${CLUSTER_RESOURCE_ID}" | awk -F'/' '{print $5}')
        CLUSTER_SUBSCRIPTION_ID=$(echo "${CLUSTER_RESOURCE_ID}" | awk -F'/' '{print $3}')
    else
        echo "Error: CLUSTER_NAME and CLUSTER_RESOURCE_GROUP must be set or CLUSTER_RESOURCE_ID must be provided."
        exit 1
    fi
fi

# check if TARGET_VERSION is set, if not, exit with an error message
if [ -z "${TARGET_VERSION}" ] && [ -z "${NODE_OS_UPGRADE}" ]; then
    echo "Error: Either TARGET_VERSION or NODE_OS_UPGRADE must be set."
    exit 1
fi

if [ -n "${TARGET_VERSION}" ]; then
    echo "Upgrading AKS cluster ${CLUSTER_NAME} in resource group ${CLUSTER_RESOURCE_GROUP} to version ${TARGET_VERSION}..."
    az aks upgrade \
    --resource-group "${CLUSTER_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --kubernetes-version "${TARGET_VERSION}" -y
else
    echo "Upgrading AKS cluster ${CLUSTER_NAME} in resource group ${CLUSTER_RESOURCE_GROUP} with node OS upgrade..."
    az aks upgrade \
    --resource-group "${CLUSTER_RESOURCE_GROUP}" \
    --name "${CLUSTER_NAME}" \
    --node-image-only -y
fi
