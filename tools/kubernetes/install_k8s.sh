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

# Install containerd
sudo tee /etc/modules-load.d/containerd.conf <<EOF
overlay
br_netfilter
EOF

sudo modprobe overlay
sudo modprobe br_netfilter

sudo tee /etc/sysctl.d/kubernetes.conf<<EOF
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
net.ipv4.ip_forward = 1
EOF

sudo sysctl --system

sudo mkdir -m 0755 -p /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

sudo echo \
"deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
$(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

sudo apt-get update
sudo apt-get update && sudo apt-get install -y containerd.io

sudo mkdir -p /etc/containerd

sudo containerd config default | sudo tee /etc/containerd/config.toml
sudo sed -e 's/SystemdCgroup = false/SystemdCgroup = true/g' -i /etc/containerd/config.toml

sudo systemctl daemon-reload
sleep 5
sudo systemctl restart containerd
sudo systemctl enable containerd 
sleep 5
sudo systemctl status containerd

# install kubernetes
sudo apt-get update && sudo apt-get install -y apt-transport-https ca-certificates curl

curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | sudo tee /etc/apt/sources.list.d/kubernetes.list

sudo apt-get update && sudo apt-get install -y kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl

sudo systemctl enable kubelet
sudo kubeadm init
sleep 10

# setup the environment
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config

# setup calico
curl https://raw.githubusercontent.com/projectcalico/calico/v3.28.0/manifests/calico.yaml -O
kubectl apply -f calico.yaml
sleep 5
kubectl taint nodes --all node-role.kubernetes.io/master-
 kubectl taint nodes aimlfw node-role.kubernetes.io/control-plane-


# install nerdctl
NERDCTL_VERSION=1.7.6 # see https://github.com/containerd/nerdctl/releases for the latest release

archType="amd64"
if test "$(uname -m)" = "aarch64"
then
            archType="arm64"
fi

wget -q "https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-${archType}.tar.gz" -O /tmp/nerdctl.tar.gz
sudo tar Cxzvvf /usr/bin /tmp/nerdctl.tar.gz

# install buildkit
BUILDKIT_VERSION=0.13.2 # see https://github.com/moby/buildkit/releases for the latest release

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
sudo nerdctl run -d --name buildkitd --privileged moby/buildkit:latest

