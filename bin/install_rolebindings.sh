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

# For reading secrets in Kubeflow-Pipeline and SDK

kubectl create clusterrole secret_reader --verb get,list --resource secret
kubectl create  rolebinding secret_pipline_runner_rb -n traininghost --serviceaccount kubeflow:pipeline-runner --clusterrole  secret_reader
kubectl create rolebinding traininghost_default_secret_rb -n kubeflow --serviceaccount traininghost:default --clusterrole secret_reader
