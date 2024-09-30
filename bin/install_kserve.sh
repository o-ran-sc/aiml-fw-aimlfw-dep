#==================================================================================
#  Copyright (c) 2023 Samsung Electronics Co., Ltd. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#==================================================================================

#!/bin/bash

set -eu

# Function to dynamically generate log messages
# This function allows logging with a consistent format, supporting different levels like INFO, ERROR, and WARN
log_message() {
    local log_level=$1
    local component=$2
    local message=$3
    echo "[$log_level] $component: $message"
}


DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$DIR" || exit

# Import KServe configs
log_message "INFO" "KServe" "Importing configurations"
source ${DIR}/../tools/kserve/config.sh

# Function to wait for Kubernetes deployments
wait_for_deployment() {
    log_message "INFO" "Kubernetes" "Waiting for all pods under deployment $1 in namespace $2"
    STILL_WAITING=true
    while $STILL_WAITING; do
        STILL_WAITING=false
        PODS=$(kubectl get pods -n $2 -l app=$1 2>/dev/null | grep $1 | awk '{print $1}')
        for POD in ${PODS}; do
            READY=$(kubectl get pod ${POD} -n $2 2>/dev/null | grep $1 | awk '{print $2}')
            DESIRED_STATE=$(echo ${READY} | cut -d/ -f 1)
            CURRENT_STATE=$(echo ${READY} | cut -d/ -f 2)
            if [ $DESIRED_STATE -ne $CURRENT_STATE ]; then
                STILL_WAITING=true
                sleep 1
                log_message "INFO" "Kubernetes" "Pod $POD is not ready. Retrying..."
            fi
        done
    done
    log_message "INFO" "Kubernetes" "All pods for deployment $1 are now running"
}

# Function to wait for Kubernetes StatefulSets
wait_for_statefulset() {
    log_message "INFO" "Kubernetes" "Waiting for statefulset $1 in namespace $2"
    STILL_WAITING=true
    while $STILL_WAITING; do
        STILL_WAITING=false
        READYS=$(kubectl get statefulset -n $2 2>/dev/null | grep $1 | awk '{print $2}')
        for READY in ${READYS}; do
            DESIRED_STATE=$(echo ${READY} | cut -d/ -f 1)
            CURRENT_STATE=$(echo ${READY} | cut -d/ -f 2)
            if [ $DESIRED_STATE -ne $CURRENT_STATE ]; then
                STILL_WAITING=true
                sleep 1
                log_message "INFO" "Kubernetes" "Statefulset $1 not fully ready. Retrying..."
            fi
        done
    done
    log_message "INFO" "Kubernetes" "Statefulset $1 is now running"
}

########## Install Cert Manager ##########
log_message "INFO" "Cert-Manager" "Checking Cert Manager installation..."
IS_CERT_INSTALLED=$(kubectl get crd certificaterequests.cert-manager.io 2>&1 | grep "Error from server (NotFound)" | wc -l)
if [ "$IS_CERT_INSTALLED" -eq 1 ]; then
    log_message "INFO" "Cert-Manager" "Installing Cert Manager"
    kubectl apply -f https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml
    CERT_MANAGER_DEPLOYMENTS="cert-manager-cainjector cert-manager-webhook cert-manager"
    for CERT_MANAGER_DEPLOYMENT in $CERT_MANAGER_DEPLOYMENTS; do
        wait_for_deployment $CERT_MANAGER_DEPLOYMENT "cert-manager"
    done
    log_message "INFO" "Cert-Manager" "Cert Manager installation completed"
else
    log_message "INFO" "Cert-Manager" "Cert Manager already installed, skipping installation"
fi

# temp dir
WORK_DIR=$(mktemp -d -p "${DIR}")
if [[ ! "$WORK_DIR" || ! -d "$WORK_DIR" ]]; then
    echo "Could not create temp dir"
    exit 1
fi
cd "${WORK_DIR}"

# deletes the temp directory
function cleanup() {
    rm -rf "$WORK_DIR"
    echo "Deleted temp working directory $WORK_DIR"
}

# register the cleanup function to be called on the EXIT signal
trap cleanup EXIT

########## Install Istio ##########
ISTIO_OPTIONS="ISTIO_VERSION TARGET_ARCH"
for ISTIO_OPTION in $ISTIO_OPTIONS; do
    if [ -z "${!ISTIO_OPTION}" ]; then
        echo "$ISTIO_OPTION is empty"
        exit 1
    fi
done

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=$TARGET_ARCH sh -

pushd "./istio-${ISTIO_VERSION}/bin"
PRECHECK_RESULT=$(./istioctl x precheck | grep "Install Pre-Check passed!" | wc -l)
if [ "$PRECHECK_RESULT" -ne 1 ]; then
    echo "istio x precheck failed"
    FAIL_REASON=$(./istioctl x precheck | grep "already installed in namespace" | wc -l)
    if [ "$FAIL_REASON" -ne 1 ]; then
        read -p "Force install istio? (Y/N): " confirm
        if [[ $confirm == [yY] || $confirm == [yY][eE][sS] ]]; then
            echo "install istio forcingly"
            ./istioctl install --force -y -f "${DIR}/../tools/kserve/istio-minimal-operator.yaml"
        else
            echo "do not install istio forcingly, bye bye~"
            exit 1
        fi
    else
        echo "unhandled precheck fail"
        exit 1
    fi
else
    ./istioctl install -y -f "${DIR}/../tools/kserve/istio-minimal-operator.yaml"
fi
popd

ISTIO_DEPLOYMENTS="istiod cluster-local-gateway istio-ingressgateway"
for ISTIO_DEPLOYMENTS in $ISTIO_DEPLOYMENTS; do
    wait_for_deployment $ISTIO_DEPLOYMENTS "istio-system"
done

########## Install Knative ##########
kubectl apply -f https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving-crds.yaml
kubectl apply -f https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving-core.yaml
KNATIVE_CORE_DEPLOYMENTS="activator autoscaler controller webhook"
for KNATIVE_DEPLOYMENT in $KNATIVE_CORE_DEPLOYMENTS; do
    wait_for_deployment $KNATIVE_DEPLOYMENT "knative-serving"
done

kubectl apply -f https://github.com/knative/net-istio/releases/download/${KNATIVE_VERSION}/release.yaml

KNATIVE_REL_DEPLOYMENTS="networking-istio istio-webhook"
for KNATIVE_DEPLOYMENT in $KNATIVE_REL_DEPLOYMENTS; do
    wait_for_deployment $KNATIVE_DEPLOYMENT "knative-serving"
done

function rpt() {
    set +e
    CMD="kubectl apply -f ${DIR}/../tools/kserve/cert-manager-test.yaml"
    echo "Start cert-manager testing, ignore error statements a seconds"
    until $CMD; do
        sleep 1
    done
    set -e
}
rpt
kubectl delete -f "${DIR}/../tools/kserve/cert-manager-test.yaml"

########## Install Kserve & Kserve Runtimes ##########
IS_KSERVE_INSTALLED=$(kubectl get crd inferenceservices.serving.kserve.io --ignore-not-found)
if [ -z "$IS_KSERVE_INSTALLED" ]; then
    kubectl apply -f https://raw.githubusercontent.com/kserve/kserve/master/install/${KSERVE_VERSION}/kserve.yaml
    KSERVE_DEPLOYMENTS="kserve-controller-manager"
    for KSERVE_DEPLOYMENT in $KSERVE_DEPLOYMENTS; do
        wait_for_deployment $KSERVE_DEPLOYMENT "kserve"
    done

    # Wait for KServe Webhook to be ready by checking kserve-controller-manager logs
    echo "Waiting for KServe Webhook to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/kserve-controller-manager -n kserve
else
    echo "KServe already exist, skipping installation"
fi

RUNTIMES_INSTALLED=$(kubectl get clusterservingruntimes.serving.kserve.io --ignore-not-found)
if [ -z "$RUNTIMES_INSTALLED" ]; then
    echo "Installing KServe runtimes"
    kubectl apply -f https://raw.githubusercontent.com/kserve/kserve/master/install/${KSERVE_VERSION}/kserve-runtimes.yaml
else
    echo "KServe runtimes already exist, skipping installation"
fi