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

helm repo add bitnami https://charts.bitnami.com/bitnami
helm install tm-db bitnami/postgresql --namespace traininghost
while [[ $(kubectl get pods tm-db-postgresql-0 -n traininghost -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for training manager db pod" && sleep 1; done
echo "Installed tm-db"
helm install cassandra --set dbUser.user="cassandra" --namespace="traininghost"  bitnami/cassandra --version 10.0.0
while [[ $(kubectl get pods cassandra-0 -n traininghost -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for cassandra manager db pod" && sleep 1; done
echo "Installed cassandra-db"
