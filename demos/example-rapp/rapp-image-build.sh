# ==================================================================================
#
#       Copyright (c) 2025 Samsung Electronics Co., Ltd. All Rights Reserved.
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

# sudo nerdctl --namespace k8s.io rmi -f rapp:dev
echo "Building New Image & Loading"
sudo buildctl --addr=nerdctl-container://buildkitd build \
	--frontend dockerfile.v0 \
	--opt filename=Dockerfile \
	--local dockerfile=rapp \
	--local context=rapp \
	--output type=oci,name=rapp:dev | sudo nerdctl load --namespace k8s.io