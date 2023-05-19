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

NODE_NAME_BASE=$1
FILENAME=$2
START_EPOCH=$3
END_EPOCH=$4
SRV_ID=0
SRV="pm-https-server-$SRV_ID.pm-https-server.ran"
HTTPS_PORT=443
URL="https://$SRV:$HTTPS_PORT/files/$FILENAME"

EVT='{"event":{"commonEventHeader":{"sequence":0,"eventName":"FileReady","sourceName":"'$NODE_NAME_BASE'","lastEpochMicrosec":'$END_EPOCH',"startEpochMicrosec":'$START_EPOCH',"timeZoneOffset":"UTC+05:00","changeIdentifier":"PM_MEAS_FILES"},"notificationFields":{"notificationFieldsVersion":"notificationFieldsVersion","changeType":"FileReady","changeIdentifier":"PM_MEAS_FILES","arrayOfNamedHashMap":[{"name":"'$FILENAME'","hashMap":{"fileFormatType":"org.3GPP.32.435#measCollec","location":"'$URL'","fileFormatVersion":"V10","compression":"gzip"}}]}}}'
echo $EVT
echo $EVT >> .out.json
cat .out.json | kafka-console-producer --topic file-ready --broker-list kafka-1-kafka-bootstrap.nonrtric:9092
echo "done"
