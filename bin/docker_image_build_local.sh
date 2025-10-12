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
git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/awmf/modelmgmtservice"

sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile \
    --local dockerfile=tm \
    --local context=tm \
    --output type=oci,name=tm:latest | sudo nerdctl load --namespace k8s.io

sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile \
    --local dockerfile=data-extraction \
    --local context=data-extraction \
    --output type=oci,name=data-extraction:latest | sudo nerdctl load --namespace k8s.io


sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile \
    --local dockerfile=kubeflow-adapter \
    --local context=kubeflow-adapter \
    --output type=oci,name=kfadapter:latest | sudo nerdctl load --namespace k8s.io

sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile \
    --local dockerfile=aiml-dashboard \
    --local context=aiml-dashboard \
    --output type=oci,name=aiml-dashboard:latest | sudo nerdctl load --namespace k8s.io

sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile \
    --local dockerfile=aiml-dashboard/kf-pipelines \
    --local context=aiml-dashboard/kf-pipelines \
    --output type=oci,name=aiml-notebook:latest | sudo nerdctl load --namespace k8s.io

sudo buildctl --addr=nerdctl-container://buildkitd build \
    --frontend dockerfile.v0 \
    --opt filename=Dockerfile \
    --local dockerfile=modelmgmtservice \
    --local context=modelmgmtservice \
    --output type=oci,name=modelmgmtservice:latest | sudo nerdctl load --namespace k8s.io

cd -
rm -Rf /tmp/gerrit_code
