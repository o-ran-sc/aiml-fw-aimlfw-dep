#==================================================================================
#  Copyright (c) 2025 Samsung Electronics Co., Ltd. All Rights Reserved.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#  See the License for the specific language governing permissions and
#  limitations under the License.
#==================================================================================
#!/bin/bash

LIBS_NAME="libs"                         # name of your libs folder
TARGET_DIR="/usr/local/lib/aimlfw/$LIBS_NAME"     # where to install
ENV_VAR_NAME="AIMLFW_LIBS_HOME"                # environment variable name
BASHRC_FILE="$HOME/.bashrc"                # file to append env setup

# === STEP 1: Delete libraries ===
sudo rm -rf $TARGET_DIR

if grep -q "export $ENV_VAR_NAME=" "$BASHRC_FILE"; then
  echo "Removing environment variable from $BASHRC_FILE ..."
  sed -i "/export $ENV_VAR_NAME=\".*\"/d" "$BASHRC_FILE"
  echo "Environment variable removed."
else
  echo "No environment variable entry found in bashrc"
fi

echo "Uninstall completed"