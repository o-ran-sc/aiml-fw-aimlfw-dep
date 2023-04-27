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

previous_dir=$PWD
kubeflow_dir=tools/kubeflow
cd /tmp
wget https://github.com/kubeflow/pipelines/archive/refs/tags/1.4.0.tar.gz
tar -xvzf 1.4.0.tar.gz
cd pipelines-1.4.0
cp $previous_dir/$kubeflow_dir/kustomization.yaml manifests/kustomize/env/platform-agnostic/kustomization.yaml
cp $previous_dir/$kubeflow_dir/workflow-controller-configmap.yaml manifests/kustomize/base/argo/workflow-controller-configmap.yaml
sed -e 's/mlpipeline-.*$/mlpipeline-leofs-artifact/g' manifests/kustomize/base/pipeline/ml-pipeline-ui-deployment.yaml > /tmp/ml-pipeline-ui-deployment_tmp.yaml
cp /tmp/ml-pipeline-ui-deployment_tmp.yaml manifests/kustomize/base/pipeline/ml-pipeline-ui-deployment.yaml
cp $previous_dir/$kubeflow_dir/ml-pipeline-apiserver-deployment.yaml manifests/kustomize/base/pipeline/ml-pipeline-apiserver-deployment.yaml
cp $previous_dir/$kubeflow_dir/config.json backend/src/apiserver/config/config.json
cp -r $previous_dir/samples/* samples/
cp $previous_dir/$kubeflow_dir/sample_config.json backend/src/apiserver/config/sample_config.json
tmpfile=$(mktemp)
address='backend/src/apiserver/config/config.json'
leofs_password=$(kubectl get secret leofs-secret -n kubeflow -o jsonpath='{.data.password}' | base64 -d)
sed -e "s/\"SecretAccessKey.*$/\"SecretAccessKey\" : \"$leofs_password\",/g" $address >"$tmpfile" &&
  mv -- "$tmpfile" $address

#Fix for Kubeflow pipeline backend apiserver Dockerfile because stretch version is moved to archive
sed -i '4i RUN sed -i s/deb.debian.org/archive.debian.org/g /etc/apt/sources.list' backend/Dockerfile
sed -i '5i RUN sed -i s/security.debian.org/archive.debian.org/g /etc/apt/sources.list' backend/Dockerfile
sed -i '6i RUN sed  -i '/stretch-updates/d' /etc/apt/sources.list' backend/Dockerfile
sed -i '61i RUN sed -i s/deb.debian.org/archive.debian.org/g /etc/apt/sources.list' backend/Dockerfile
sed -i '62i RUN sed -i s/security.debian.org/archive.debian.org/g /etc/apt/sources.list' backend/Dockerfile
sed -i '63i RUN sed  -i '/stretch-updates/d' /etc/apt/sources.list' backend/Dockerfile

#build backend apiserver with new config.json
docker build -f backend/Dockerfile . --tag api_server_local
kubectl apply -k manifests/kustomize/cluster-scoped-resources/
source $previous_dir/$kubeflow_dir/leofs_env.sh
envsubst < $previous_dir/$kubeflow_dir/mlpipeline-leofs-artifact-secret.yaml | kubectl apply -n kubeflow -f -
kubectl apply -k  manifests/kustomize/env/platform-agnostic-pns/
sleep 60
kubectl set image deployment/ml-pipeline -n kubeflow ml-pipeline-api-server=api_server_local:latest
cd $previous_dir
