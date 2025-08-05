
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

# Kubernetes version upgrade script for AIMLFW
# Reference: O-RAN SC it-dep setup_k8s.sh

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

echo "Step 4: Installing Kubernetes packages (v1.32.3)..."
sudo apt update && sudo apt install -y apt-transport-https ca-certificates curl
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb /' | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null

# installation specific version (1.32.3-1.1)
sudo apt update && sudo apt install -y kubeadm=1.32.3-1.1 kubelet=1.32.3-1.1 kubectl=1.32.3-1.1
sudo apt-mark hold kubelet kubeadm kubectl

echo "Step 5: Initializing Kubernetes..."
sudo kubeadm init --pod-network-cidr=10.244.0.0/16
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

echo "Removing taints from control-plane nodes..."
for node in $(kubectl get nodes --no-headers | awk '{print $1}')
do
  echo "Removing taint from $node..."
  kubectl taint nodes $node node-role.kubernetes.io/control-plane- --ignore-not-found=true
done

echo "Downloading and applying Calico..."
curl -fsSL https://raw.githubusercontent.com/projectcalico/calico/v3.30.1/manifests/calico.yaml -o calico.yaml

# Calico v3.30.1
echo "Applying Calico configuration..."
kubectl apply -f calico.yaml

echo "Installation completed for kubernetes!"

# nerdctl installation (AIMLFW requirements)
echo "Installing nerdctl..."
NERDCTL_VERSION=1.7.6

archType="amd64"
if test "$(uname -m)" = "aarch64"
then
    archType="arm64"
fi

wget -q "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${archType}.tar.gz" -O /tmp/nerdctl.tar.gz
sudo tar Cxzvvf /usr/bin /tmp/nerdctl.tar.gz

echo "Installation completed for nerdctl!"

# buildkit installation (AIMLFW requirements)
echo "Installing buildkit..."
BUILDKIT_VERSION=0.13.2

archType="amd64"
if test "$(uname -m)" = "aarch64"
then
    archType="arm64"
fi

wget -q "https://github.com/moby/buildkit/releases/download/v${BUILDKIT_VERSION}/buildkit-v${BUILDKIT_VERSION}.linux-${archType}.tar.gz" -O /tmp/buildkit.tar.gz
tar Cxzvvf /tmp /tmp/buildkit.tar.gz
sudo mv /tmp/bin/buildctl /usr/bin/

# buildkitd instance start
sudo nerdctl run -d --name buildkitd --privileged moby/buildkit:latest

# kustomize installation (AIMLFW requirements)
echo "Installing kustomize..."
KUSTOMIZE_VERSION=5.4.2
curl -LO "https://github.com/kubernetes-sigs/kustomize/releases/download/kustomize%2Fv${KUSTOMIZE_VERSION}/kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" 
tar -xvzf "kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz" 
sudo mv kustomize /usr/local/bin/ 
rm "kustomize_v${KUSTOMIZE_VERSION}_linux_amd64.tar.gz"
echo "Kustomize installed successfully."

echo "All installations completed successfully!"
