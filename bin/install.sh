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

IS_HELM3=$(helm version --short|grep -e "^v3")

while [ -n "$1" ]; do # while loop starts

    case "$1" in

    -f) OVERRIDEYAML=$2
        shift
        ;;
    -c) LIST_OF_COMPONENTS=$2
        shift
        ;;
    -o) KERNEL_OPTIMIZATION=true
        ;;
    *) echo "Option $1 not recognized" ;; # In case you typed a different option other than a,b,c

    esac

    shift

done

if [ -z "$OVERRIDEYAML" ];then
    echo "****************************************************************************************************************"
    echo "                                                     ERROR                                                      "
    echo "****************************************************************************************************************"
    echo "AIMLFW deployment without deployment recipe is currently disabled. Please specify an recipe with the -f option."
    echo "****************************************************************************************************************"
    exit 1
fi

if [ -z $IS_HELM3 ]
then
    echo "****************************************************************************************************************"
    echo "                                                     ERROR                                                      "
    echo "****************************************************************************************************************"
    echo "AIMLFW deployment expects helm 3 installed"
    echo "****************************************************************************************************************"
    exit 1
else
    HAS_COMMON_PACKAGE=$(helm search repo local/aimlfw-common | grep aimlfw-common)
fi


if [ -z "$HAS_COMMON_PACKAGE" ];then
    echo "****************************************************************************************************************"
    echo "                                                     ERROR                                                      "
    echo "****************************************************************************************************************"
    echo "Can't locate the aimlfw-common helm package in the local repo. Please make sure that it is properly installed."
    echo "****************************************************************************************************************"
    exit 1
fi

COMPONENTS="tm data-extraction kfadapter aiml-dashboard aiml-notebook modelmgmtservice"

for component in $COMPONENTS; do
    helm dep up helm/$component
    echo "Installing $component"
    helm install $component helm/$component -f $OVERRIDEYAML
done
