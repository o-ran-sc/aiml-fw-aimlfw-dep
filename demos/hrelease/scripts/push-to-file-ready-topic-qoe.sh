#!/bin/bash

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


NODE_NAME_BASE=$1
FILENAME=$2
START_EPOCH=$3
END_EPOCH=$4

chmod +x kafka-client-send-file-ready-qoe.sh
kubectl cp kafka-client-send-file-ready-qoe.sh nonrtric/kafka-client:/home/appuser -c kafka-client

kubectl exec kafka-client -c kafka-client -n nonrtric -- bash -c './kafka-client-send-file-ready-qoe.sh '$NODE_NAME_BASE' '$FILENAME' '$START_EPOCH' '$END_EPOCH' '

echo "done"

