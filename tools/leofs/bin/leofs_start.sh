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

while ! test -d  /proc/1 ; do
        echo "PID 1 not started"
        sleep 1
done

cd ../leofs


if test -f leofs_started; then
  echo "Leofs already installed"
else
    echo "Leofs not started"
    cp ../deb/leofs_1.4.3-1_ubuntu-18.04_amd64.deb .
    dpkg-deb -xv leofs_1.4.3-1_ubuntu-18.04_amd64.deb . 
    sed -i 's/RUNNER_USER=/RUNNER_USER=root/g' ./usr/local/leofs/1.4.3/leo_manager_0/etc/leo_manager.environment
    sed -i 's/RUNNER_USER=/RUNNER_USER=root/g' ./usr/local/leofs/1.4.3/leo_manager_1/etc/leo_manager.environment
    sed -i 's/RUNNER_USER=/RUNNER_USER=root/g' ./usr/local/leofs/1.4.3/leo_storage/etc/leo_storage.environment
    sed -i 's/RUNNER_USER=/RUNNER_USER=root/g' ./usr/local/leofs/1.4.3/leo_gateway/etc/leo_gateway.environment

    touch leofs_started
fi


./usr/local/leofs/1.4.3/leo_manager_0/bin/leo_manager start
echo "leo_manager_0 started"
sleep 20
./usr/local/leofs/1.4.3/leo_manager_1/bin/leo_manager start
echo "leo_manager_1 started"
sleep 20
./usr/local/leofs/1.4.3/leo_storage/bin/leo_storage start
echo "leo_storage started"
sleep 20
./usr/local/leofs/1.4.3/leo_gateway/bin/leo_gateway start
echo "leo_gateway started"
sleep 20
./usr/local/leofs/1.4.3/leofs-adm status
./usr/local/leofs/1.4.3/leofs-adm start
echo "leofs-adm started"
echo $LEOFS_PASSWORD
./usr/local/leofs/1.4.3/leofs-adm import-user leofs leofs $LEOFS_PASSWORD
sleep 20
./usr/local/leofs/1.4.3/leofs-adm add-endpoint leofs.kubeflow
./usr/local/leofs/1.4.3/leofs-adm add-bucket mlpipeline leofs
