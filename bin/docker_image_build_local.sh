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

mkdir -p /tmp/gerrit_code
cd /tmp/gerrit_code
git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/awmf/tm"
git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/athp/data-extraction"
git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/athp/tps/kubeflow-adapter"
git clone "https://gerrit.o-ran-sc.org/r/portal/aiml-dashboard"
git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/aihp/ips/kserve-adapter"

docker build -f tm/Dockerfile -t tm tm/.
docker build -f data-extraction/Dockerfile -t data-extraction data-extraction/.
docker build -f kubeflow-adapter/Dockerfile -t kfadapter kubeflow-adapter/.
docker build -f aiml-dashboard/Dockerfile -t aiml-dashboard aiml-dashboard/.
docker build -f aiml-dashboard/kf-pipelines/Dockerfile -t aiml-notebook aiml-dashboard/kf-pipelines/.
docker build -f kserve-adapter/Dockerfile -t kserve-adapter:1.0.0 kserve-adapter/.

cd -
rm -Rf /tmp/gerrit_code
