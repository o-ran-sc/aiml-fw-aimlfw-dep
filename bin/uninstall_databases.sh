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

#Uninstall databases

# Function to log messages with different levels: INFO, WARN, ERROR
log_message() {
    local log_level=$1
    local component=$2
    local message=$3
    echo "[$log_level] $component: $message"
}

log_message "INFO" "Helm" "Uninstalling PostgreSQL (tm-db) from 'traininghost' namespace..."
helm delete tm-db -n traininghost
if [ $? -eq 0 ]; then
    log_message "INFO" "Helm" "Successfully uninstalled tm-db"
else
    log_message "ERROR" "Helm" "Failed to uninstall tm-db"
    exit 1
fi
kubectl delete pvc data-tm-db-postgresql-0 -n traininghost
helm delete cassandra -n traininghost
sleep 10
kubectl delete pvc data-cassandra-0 -n traininghost
