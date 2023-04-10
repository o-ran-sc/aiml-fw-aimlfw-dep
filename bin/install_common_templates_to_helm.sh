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

#!/bin/bash
#set -e

if [ -z $(helm plugin list | grep servecm | awk '{print $1}') ];
then
        echo "Installing servecm (Chart Manager) and common templates to helm3"

        helm plugin install https://github.com/jdolitsky/helm-servecm
else
        echo "Found servecm in the helm plugin list. Skip servecm installation."
fi

#The hardcoded location does not work anymore, Reference: change similar to RIC-966 updating chartmuseum and docker refs
curl -LO https://get.helm.sh/chartmuseum-v0.15.0-linux-386.tar.gz
tar xzvf chartmuseum-v0.15.0-linux-386.tar.gz
chmod +x ./linux-386/chartmuseum
sudo cp ./linux-386/chartmuseum /usr/local/bin

eval $(helm env | grep HELM_REPOSITORY_CACHE)
echo ${HELM_REPOSITORY_CACHE}
helm servecm --port=8879 --context-path=/charts --storage local --storage-local-rootdir $HELM_REPOSITORY_CACHE/local/ <<EOF &
yes
EOF

CURL_CMD="curl --silent --output /dev/null  http://127.0.0.1:8879/charts"
`${CURL_CMD}`
READY=$?
while [ ${READY} != 0 ]; do
        echo "servecm not yet running. sleeping for 2 seconds"
        sleep 2
        `${CURL_CMD}`
        READY=$?
done
echo "servcm up and running"

eval $(helm env |grep HELM_REPOSITORY_CACHE)
echo ${HELM_REPOSITORY_CACHE}
mkdir -p "${HELM_REPOSITORY_CACHE}/local/"

export COMMON_CHART_VERSION=$(cat aimlfw-common/Common-Template/helm/aimlfw-common/Chart.yaml | grep version | awk '{print $2}')
helm package -d /tmp aimlfw-common/Common-Template/helm/aimlfw-common
cp /tmp/aimlfw-common-${COMMON_CHART_VERSION}.tgz "${HELM_REPOSITORY_CACHE}/local/"
helm repo remove local
helm repo add local http://127.0.0.1:8879/charts

echo "checking that aimlfw-common templates were added"
helm search repo local/aimlfw-common
