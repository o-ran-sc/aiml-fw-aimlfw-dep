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
is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null || [ -n "$WSL_DISTRO_NAME" ] || [ -n "$WSL_INTEROP" ]
}

K8S_VERSION=1.32
K8S_MINOR_VERSION=8
KUSTOMIZE_VERSION=5.5.0
CALICO_VERSION=3.30.1
NERDCTL_VERSION=1.7.6 # see https://github.com/containerd/nerdctl/releases for the latest release
BUILDKIT_VERSION=0.13.2 # see https://github.com/moby/buildkit/releases for the latest release

if [ -z "$AIMLFW_LIBS_HOME" ]; then
  echo "Please set AIMLFW_LIBS_HOME by running install_libs.sh first."
  exit 1
fi

source "$AIMLFW_LIBS_HOME/loglib.sh"

log_section_break
echo -e "\n${BOLD}${CYAN}: Starting Kubernetes Installation...${NC}\n"
START_TIME=$(date +%s)

log_step "Step 0: Checking if running on WSL..."
if is_wsl; then
  log_info "Running on WSL"
else
  log_info "Not WSL"
fi

echo "Step 1: Disabling swap memory..."
sudo swapoff -a
sudo sed -i '/swap/s/^/#/' /etc/fstab

echo "Step 2: Enabling IPv4 packet forwarding and loading kernel modules..."
echo -e "overlay\nbr_netfilter" | sudo tee /etc/modules-load.d/k8s.conf > /dev/null
sudo modprobe overlay
sudo modprobe br_netfilter

cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf > /dev/null
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sudo sysctl --system

echo "Step 3: Installing Containerd..."
sudo apt update
sudo apt install -y containerd
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
sudo systemctl restart containerd

echo "Step 4: Installing Kubernetes packages..."
sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v$K8S_VERSION/deb /" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt update && sudo apt install -y kubeadm=$K8S_VERSION.$K8S_MINOR_VERSION-1.1 kubelet=$K8S_VERSION.$K8S_MINOR_VERSION-1.1 kubectl=$K8S_VERSION.$K8S_MINOR_VERSION-1.1
sudo apt-mark hold kubelet kubeadm kubectl

echo "Step 5: Initializing Kubernetes..."
if is_wsl; then
  sudo kubeadm init --pod-network-cidr=10.244.0.0/16
else
  sudo kubeadm init
fi
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Removing taints from control-plane nodes..."
for node in $(kubectl get nodes --no-headers | awk '{print $1}')
do
  echo "Removing taint from $node..."
  kubectl taint nodes $node node-role.kubernetes.io/control-plane-
done

echo "Step 6: Applying CNI plugin..."
if is_wsl; then
  echo "WSL environment — Flannel CNI"
  curl -fSL "https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml" -o kube-flannel.yml
  kubectl apply -f kube-flannel.yml
else
  echo "Non-WSL environment — Calico CNI"
  kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v$CALICO_VERSION/manifests/calico.yaml
fi
echo "Installation completed for kubernetes!"

# install nerdctl
archType="amd64"
if test "$(uname -m)" = "aarch64"
then
            archType="arm64"
fi

wget -q "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${archType}.tar.gz" -O /tmp/nerdctl.tar.gz
sudo tar Cxzvvf /usr/bin /tmp/nerdctl.tar.gz

echo "Installation completed for nerdctl!"

# install buildkit
archType="amd64"
if test "$(uname -m)" = "aarch64"
then
            archType="arm64"
fi
echo "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${archType}.tar.gz"
wget -q "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${archType}.tar.gz" -O /tmp/buildkit.tar.gz
tar Cxzvvf /tmp /tmp/buildkit.tar.gz
sudo mv /tmp/bin/buildctl /usr/bin/

# run buildkit instance
if is_wsl; then
  sudo nerdctl run -d --name buildkitd --privileged --network host moby/buildkit:latest
else
  sudo nerdctl run -d --name buildkitd --privileged moby/buildkit:latest
fi
# install kustomize
curl -LO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" 
tar -xvzf "kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" 
sudo mv kustomize /usr/local/bin/ 
rm "kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
echo "Kustomize installed successfully." 