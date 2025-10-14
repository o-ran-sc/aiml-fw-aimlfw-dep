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
# --- Verify current working directory ---
if [ ! -f "tools/logging/log.sh" ]; then
    echo -e "Please run this script from the aimlfw-dep directory."
    echo -e "For example:"
    echo -e "cd aimlfw-dep"
    echo -e "./tools/kubernetes/uninstall_k8s.sh"
    exit 1
fi

source tools/logging/log.sh
log_divider
echo -e "\n${BOLD}${CYAN}: Starting Kubernetes Uninstallation...${NC}\n"
START_TIME=$(date +%s)

sudo kubeadm reset
sudo apt-get -y purge kubeadm kubectl kubelet kubernetes-cni kube*
sudo apt-get -y autoremove
sudo rm -rf ~/.kube

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))
echo -e "\n${BOLD}${GREEN} Kubernetes Uninstallation Completed Successfully!${NC}"
echo -e "${YELLOW}Total Time: ${DURATION}s${NC}\n"
log_divider