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

set -u

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null && pwd)"
cd "$DIR" || exit

# import configs
source ${DIR}/../tools/kserve/config.sh

function wait_for_pods_terminate() {
    echo -n "waiting for $1 pods to terminates"

    STILL_WAITING=true
    while $STILL_WAITING; do
        PODS=$(kubectl get pods -n $2 2>/dev/null | grep $1 | awk '{print $1}')
        if [ -z "$PODS" ]; then
            STILL_WAITING=false
        else
            echo -n "."
            sleep 1
        fi
    done

    echo
}

########## Uninstall Kserve & Kserve Runtimes ##########
kubectl delete --timeout=10s -f https://raw.githubusercontent.com/kserve/kserve/master/install/${KSERVE_VERSION}/kserve-runtimes.yaml
kubectl delete --timeout=10s -f https://raw.githubusercontent.com/kserve/kserve/master/install/${KSERVE_VERSION}/kserve.yaml
KSERVE_DEPLOYMENTS="kserve-controller-manager"
for KSERVE_DEPLOYMENT in $KSERVE_DEPLOYMENTS; do
    wait_for_pods_terminate $KSERVE_DEPLOYMENT "kserve"
done

########## Uninstall Cert Manager ##########
kubectl delete --timeout=10s -f https://github.com/jetstack/cert-manager/releases/download/${CERT_MANAGER_VERSION}/cert-manager.yaml
CERT_MANAGER_DEPLOYMENTS="cert-manager cert-manager-cainjector cert-manager-webhook"
for CERT_MANAGER_DEPLOYMENT in $CERT_MANAGER_DEPLOYMENTS; do
    wait_for_pods_terminate $CERT_MANAGER_DEPLOYMENT "cert-manager"
done

########## Uninstall Knative ##########
kubectl delete -f https://github.com/knative/net-istio/releases/download/${KNATIVE_VERSION}/release.yaml
KNATIVE_DEPLOYMENTS="networking-istio istio-webhook"
for KNATIVE_DEPLOYMENT in $KNATIVE_DEPLOYMENTS; do
    wait_for_pods_terminate $KNATIVE_DEPLOYMENT "knative-serving"
done

set +e
# TODO: Review and resolve errors from deleting overlapping resources in serving-crds.yaml and serving-core.yaml
# These errors occur due to overlapping resource definitions but are not expected to affect the installation or functionality
kubectl delete -f https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving-core.yaml       
kubectl delete -f https://github.com/knative/serving/releases/download/${KNATIVE_VERSION}/serving-crds.yaml       
set -e
KNATIVE_DEPLOYMENTS="autoscaler controller webhook activator"
for KNATIVE_DEPLOYMENT in $KNATIVE_DEPLOYMENTS; do
    wait_for_pods_terminate $KNATIVE_DEPLOYMENT "knative-serving"
done

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

########## Uninstall Istio ##########
ISTIO_OPTIONS="ISTIO_VERSION TARGET_ARCH"
for ISTIO_OPTION in $ISTIO_OPTIONS; do
    if [ -z "${!ISTIO_OPTION}" ]; then
        echo "$ISTIO_OPTION is empty"
        exit 1
    fi
done

curl -L https://istio.io/downloadIstio | ISTIO_VERSION=$ISTIO_VERSION TARGET_ARCH=$TARGET_ARCH sh -

pushd "./istio-${ISTIO_VERSION}/bin"
./istioctl verify-install
./istioctl x uninstall --purge -y
popd

ISTIO_DEPLOYMENTS="istiod cluster-local-gateway istio-ingressgateway"
for ISTIO_DEPLOYMENTS in $ISTIO_DEPLOYMENTS; do
    wait_for_pods_terminate $ISTIO_DEPLOYMENTS "istio-system"
done
kubectl delete namespace istio-system

