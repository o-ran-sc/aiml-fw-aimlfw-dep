# ==================================================================================
#
#       Copyright (c) 2023 Samsung Electronics Co., Ltd. All Rights Reserved.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#          http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.
#
# ==================================================================================
#!/bin/bash

# Function to dynamically generate log messages
log_message() {
    local log_level=$1
    local component=$2
    local message=$3
    echo "[$log_level] $component: $message"
}

IS_HELM3=$(helm version --short|grep -e "^v3")

while [ -n "$1" ]; do # while loop starts

    case "$1" in

        -f) OVERRIDEYAML=$2
            log_message "INFO" "Argument Parsing" "Using override YAML file: $OVERRIDEYAML"
            shift
            ;;
        -c) LIST_OF_COMPONENTS=$2
            log_message "INFO" "Argument Parsing" "List of components specified: $LIST_OF_COMPONENTS"
            shift
            ;;
        -o) KERNEL_OPTIMIZATION=true
            log_message "INFO" "Argument Parsing" "Kernel optimization enabled"
            ;;
        *) log_message "ERROR" "Argument Parsing" "Unrecognized option: $1"; exit 1 ;;


    esac

    shift

done

if [ -z "$OVERRIDEYAML" ];then
    log_message "ERROR" "Validation" "Kserve deployment requires a deployment recipe. Please specify a recipe with the -f option."
    exit 1
fi

if [ -z $IS_HELM3 ]
then
    log_message "ERROR" "Validation" "Helm 3 is required for Kserve deployment. Please install Helm 3."
    exit 1
else
    HAS_COMMON_PACKAGE=$(helm search repo local/aimlfw-common | grep aimlfw-common)
fi

if [ -z "$HAS_COMMON_PACKAGE" ]; then
    log_message "INFO" "Helm" "Installing common Helm templates..."
    bin/install_common_templates_to_helm.sh
    if [ -z $(helm search repo local/aimlfw-common | grep aimlfw-common) ]; then
        log_message "ERROR" "Helm" "Could not locate the aimlfw-common Helm package in the local repo. Please ensure it is installed."
        exit 1
    else
        log_message "INFO" "Helm" "Successfully installed the aimlfw-common Helm package."
    fi
else
    log_message "INFO" "Helm" "aimlfw-common Helm package found."
fi

# Create the necessary namespace
log_message "INFO" "Kubernetes" "Creating namespace 'ricips'..."
kubectl create namespace ricips

# Install Kserve
log_message "INFO" "Kserve Installation" "Installing Kserve..."
bin/install_kserve.sh

# Update and install the Kserve adapter
log_message "INFO" "Kserve Adapter" "Updating dependencies for kserve-adapter..."
helm dep up helm/kserve-adapter
log_message "INFO" "Kserve Adapter" "Installing kserve-adapter..."
helm install kserve-adapter helm/kserve-adapter -f $OVERRIDEYAML
log_message "INFO" "Kserve Adapter" "Kserve-adapter installed successfully."

