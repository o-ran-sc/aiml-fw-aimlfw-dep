<!--
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
-->
# Dummy-Rapp to test notification_url callback

1. Building Image:
```bash
./rapp-image-build.sh
```

2. Deploy rApp:
```bash
kubectl apply -f krm/.
```

3. Test the pod using curl-pod:
```bash
# Deploy a curl-pod
kubectl run curl-pod --image=curlimages/curl:latest --command sleep 3600
# Query Inference-Service
kubectl exec -it curl-pod -- \
curl \
--location rapp-service.default.svc.cluster.local/callback \
--header "Content-Type: application/json" \
--data '{
        "key1": 3,
        "key2": []
        }'

# Response must be
{"data":{"key1":3,"key2":[]},"message":"Data received"}
```

Note: Use the callback-url/notification_url as `http://rapp-service.default.svc.cluster.local/callback` in order to test notification_rapp.