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
bin/uninstall.sh
bin/uninstall_databases.sh
helm repo remove local
sudo helm plugin uninstall servecm


tools/kubeflow/bin/uninstall_kubeflow.sh
tools/leofs/bin/uninstall_leofs.sh
bin/uninstall_rolebindings.sh
kubectl delete namespace traininghost

tools/nfs/delete_nfs_subdir_external_provisioner.sh
tools/kubernetes/uninstall_k8s.sh
