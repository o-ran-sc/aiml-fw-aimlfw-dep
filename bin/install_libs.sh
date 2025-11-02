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

# === STEP 1: Copy libraries ===
echo "Installing libraries to $TARGET_DIR ..."
sudo mkdir -p "$TARGET_DIR"
sudo cp -r tools/$LIBS_NAME/* "$TARGET_DIR/"
sudo chmod -R 755 "$TARGET_DIR"
echo "Libraries copied successfully."

# === STEP 2: Add environment variable and sourcing to bashrc ===
if ! grep -q "$ENV_VAR_NAME" "$BASHRC_FILE"; then
  echo "Adding environment variable to $BASHRC_FILE ..."
  cat <<EOF >> "$BASHRC_FILE"

export $ENV_VAR_NAME="$TARGET_DIR"

EOF
  echo "Environment variable added to bashrc."
else
  echo "Environment variable already exists in bashrc."
fi

echo ""
# It is observed, when you run "./bin/install_libs.sh" instead of "source ./bin/install_libs.sh", 
# Bash runs it as a child process i.e. any changes/creation done to enivornment-variables will not be propagated to main bash process.
# Therefore, it is required the user to do the following in order to apply changes 
echo "Please run 'source ~/.bashrc' or restart your terminal to apply changes."