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
sudo nerdctl --namespace k8s.io rmi tm:latest
sudo nerdctl --namespace k8s.io rmi data-extraction:latest
sudo nerdctl --namespace k8s.io rmi kfadapter:latest
sudo nerdctl --namespace k8s.io rmi aiml-dashboard:latest
sudo nerdctl --namespace k8s.io rmi aiml-notebook:latest
sudo nerdctl --namespace k8s.io rmi kserve-adapter:1.0.1
sudo nerdctl --namespace k8s.io rmi modelmgmtservice:latest 
