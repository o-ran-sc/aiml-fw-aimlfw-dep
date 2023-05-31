# ==================================================================================
#
#       Copyright (c) 2023 Samsung Electronics Co., Ltd. All Rights Reserved.
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

#!/bin/bash

if [ $# -lt 3 ]; then
    echo "Give all input parameters, e.g ./push_qoe_data.sh <source name> <max number of rows to take from csv> <cell Identity to be filtered>"
    exit 1
fi

kubectl patch StatefulSet pm-https-server -n ran -p '{"spec":{"template":{"spec":{"containers":[{"name":"pm-https-server", "env":[{"name":"ALWAYS_RETURN", "value":""}]}]}}}}'
kubectl rollout status statefulset/pm-https-server -n ran
kubectl exec -it pm-https-server-0 -n ran -c pm-https-server -- mkdir -p /files
sudo apt install -y python3-pip
pip3 install pandas
wget https://raw.githubusercontent.com/o-ran-sc/ric-app-qp/g-release/src/cells.csv -O qoedata.csv
python3 qoedatapush.py $1 $2 $3
