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

tools/kubernetes/install_k8s.sh
kubectl taint nodes --all node-role.kubernetes.io/control-plane-
tools/nfs/configure_nfs_server.sh localhost
tools/helm/install_helm.sh
tools/nfs/install_nfs_subdir_external_provisioner.sh localhost

bin/install_common_templates_to_helm.sh
bin/build_default_pipeline_image.sh
tools/leofs/bin/install_leofs.sh
tools/kubeflow/bin/install_kubeflow.sh
kubectl create namespace traininghost
#copy of secrets to traininghost namespace to enable modelmanagement service to access leofs
kubectl get secret leofs-secret --namespace=kubeflow -o yaml | sed -e 's/kubeflow/traininghost/g' | kubectl apply -f -

bin/install_rolebindings.sh
bin/install_databases.sh
bin/install.sh -f RECIPE_EXAMPLE/example_recipe_latest_stable.yaml
