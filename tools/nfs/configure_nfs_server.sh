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

sudo apt update
sudo apt install -y nfs-kernel-server
sudo mkdir /srv/nfs/kubedata -p
sudo chown nobody: /srv/nfs/kubedata/
sudo sed "/kubedata/d" /etc/exports > /tmp/exports_tmp ; sudo mv /tmp/exports_tmp /etc/exports
echo "/srv/nfs/kubedata $1(rw,sync,no_subtree_check,no_root_squash,no_all_squash,insecure)" >> /etc/exports
sudo exportfs -a
sudo systemctl restart nfs-kernel-server
echo "Configuring NFS server complete"
