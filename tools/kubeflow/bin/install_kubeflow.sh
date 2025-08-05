# ==================================================================================
#
#       Copyright (c) 2022 Samsung Electronics Co., Ltd. All Rights Reserved.
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

kubectl create namespace kubeflow
sleep 10
kubeflow_dir=tools/kubeflow
previous_dir=$PWD
source $previous_dir/$kubeflow_dir/leofs_env.sh

# Updated KFP version for better Kubernetes v1.32.3 compatibility
KFP_VERSION="2.3.0"  # Updated from 2.2.0 to 2.3.0 for better compatibility
REPO_URL="https://github.com/kubeflow/pipelines/archive/refs/tags/$KFP_VERSION.tar.gz"
WORK_DIR="/tmp/kubeflow_pipelines"
CUSTOM_ENV_DIR="$previous_dir/$kubeflow_dir/aimlfw-kustomize"

# Create a working directory in /tmp
mkdir -p $WORK_DIR
cd $WORK_DIR

# Download the specific version of Kubeflow Pipelines
curl -L $REPO_URL -o kubeflow_pipelines.tar.gz

# Extract the downloaded tarball
tar -xvzf kubeflow_pipelines.tar.gz

# Navigate to the extracted directory
cd pipelines-$KFP_VERSION

# Copy the custom kustomize overlay to the appropriate location
cp -r $CUSTOM_ENV_DIR manifests/kustomize/env/

# Replace placeholders in the specific kustomize file using environment variables
KUSTOMIZE_FILE="manifests/kustomize/env/$(basename $CUSTOM_ENV_DIR)/minio-artifact-secret-patch.env"

# Replace values in the kustomize file
sed -i "s/PLACEHOLDER_LEOFS_KEY/$LEOFS_KEY/g" $KUSTOMIZE_FILE

cd manifests/kustomize/env/$(basename $CUSTOM_ENV_DIR)

# Deploy all the artifacts
kustomize build ../../cluster-scoped-resources | kubectl apply -f -
kubectl wait crd/applications.app.k8s.io --for condition=established --timeout=60s
kustomize build ./ | kubectl apply -f -
kubectl wait applications/pipeline -n kubeflow --for condition=Ready --timeout=1800s

cd $previous_dir
