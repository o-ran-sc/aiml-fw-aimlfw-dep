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

# Function to dynamically generate log messages
log_message() {
    local log_level=$1
    local component=$2
    local message=$3
    echo "[$log_level] $component: $message"
}

# Add the Bitnami Helm repository
log_message "INFO" "Helm" "Adding Bitnami Helm repository..."
helm repo add bitnami https://charts.bitnami.com/bitnami

# Install PostgreSQL for Training Manager
log_message "INFO" "Helm" "Installing PostgreSQL (tm-db) in 'traininghost' namespace..."
helm install tm-db bitnami/postgresql --namespace traininghost

# Wait for tm-db to be ready
log_message "INFO" "Kubernetes" "Waiting for tm-db-postgresql pod to be ready..."
while [[ $(kubectl get pods tm-db-postgresql-0 -n traininghost -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do 
    log_message "INFO" "Kubernetes" "Waiting for training manager db pod..."
    sleep 1
done
log_message "INFO" "Kubernetes" "tm-db (PostgreSQL) pod is ready."

# Install Cassandra for Training Manager
log_message "INFO" "Helm" "Installing Cassandra in 'traininghost' namespace..."
helm install cassandra --set dbUser.user="cassandra" --namespace="traininghost" bitnami/cassandra --version 10.0.0

# Wait for Cassandra to be ready
log_message "INFO" "Kubernetes" "Waiting for cassandra-0 pod to be ready..."
while [[ $(kubectl get pods cassandra-0 -n traininghost -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do 
    log_message "INFO" "Kubernetes" "Waiting for Cassandra manager db pod..."
    sleep 1
done
log_message "INFO" "Kubernetes" "Cassandra pod is ready."

# Final status
log_message "INFO" "Kubernetes" "PostgreSQL (tm-db) and Cassandra successfully installed."
