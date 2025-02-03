# ==================================================================================
#
#       Copyright (c) 2025 Samsung Electronics Co., Ltd. All Rights Reserved.
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
FROM python:3.10-slim
# Set environment variables to avoid user prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive
# Install necessary packages and clean up
RUN apt-get update && apt-get install -y bash vim && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN touch ~/.vimrc

RUN apt update && apt install -y curl

COPY app app
# Location in the container
WORKDIR /app
RUN pip3 install  -r requirements.txt

EXPOSE 8005
# CMD ["tail", "-f", "/dev/null"]