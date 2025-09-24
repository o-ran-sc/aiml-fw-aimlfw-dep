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

if [ -z "$1" ]; then
  echo "Error: RECIPE file path not provided."
  exit 1
fi

RECIPE_FILE=$1

if [ ! -f "$RECIPE_FILE" ]; then
  echo "Error: RECIPE file not found at $RECIPE_FILE"
  exit 1
fi

kubectl create namespace kubeflow
sleep 10
head /dev/urandom | tr -dc A-Za-z0-9 | head -c 8 | kubectl create secret generic leofs-secret -n kubeflow --from-file=password=/dev/stdin

sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile.leofs \
    --local dockerfile=tools/leofs \
    --local context=. \
    --output type=oci,name=leofs | sudo nerdctl load --namespace k8s.io
    
helm dep up helm/leofs
helm install leofs helm/leofs -f $RECIPE_FILE
sleep 10
NAMESPACE=kubeflow
COMPONENT=leofs
POD_NAME=$(kubectl get pod -l app.kubernetes.io/name=$COMPONENT -n $NAMESPACE -o jsonpath="{.items[0].metadata.name}")
while [[ $(kubectl get pods $POD_NAME -n kubeflow -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for leofs pod" && sleep 1; done
