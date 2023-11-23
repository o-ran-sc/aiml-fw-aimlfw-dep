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

# Checking whether the user is added in the docker group or not.
if [[ $(groups | grep docker) ]]; then
    echo "You are already added to the docker group!"
else
    sudo groupadd docker
    sudo usermod -aG docker $USER
    echo "Adding you to the docker group re-login is required."
    echo "Exiting now try to login again."
    exit
fi

tools/kubernetes/install_k8s.sh
tools/nfs/configure_nfs_server.sh localhost
tools/helm/install_helm.sh
tools/nfs/install_nfs_subdir_external_provisioner.sh localhost

bin/install_common_templates_to_helm.sh
bin/build_default_pipeline_image.sh
tools/leofs/bin/install_leofs.sh
tools/kubeflow/bin/install_kubeflow.sh
kubectl create namespace traininghost
kubectl create namespace ricips

bin/install_rolebindings.sh
bin/install_databases.sh
bin/install.sh -f RECIPE_EXAMPLE/example_recipe_latest_stable.yaml
