# SME Registration of AIMLF Using Preloading SME of NonRT RIC

This document outlines the steps required to register an API invoker with AIMLF, preloading SME of NonRT RIC, and managing API interactions.

---

## Step 1: Preloading the Service Manager with SME Data

Use the following command to preload the service manager with SME data for NonRT RIC.

### Command:
```bash
$ ./servicemanager-preload.sh config-nonrtric-2.yaml
```

Output: the API registration information will be printed in the console log
Service Manager preload completed for config-nonrtric-2.yaml



## Step 2: Registering an invoker:

Can create invoker via postman or alternatively use curl command

### Command:
```bash
$ curl --location 'http://172.18.0.2:31575/api-invoker-management/v1/onboardedInvokers' \
--header 'Content-Type: application/json' \
--data '{
    "apiInvokerInformation": "rAppKong as invoker 3",
	 "apiList": [
        {
            "aefProfiles": [
                {
                    "aefId": "AEF_id_rAppKong_as_AEF",
                    "domainName": "kong",
                    "interfaceDescriptions": [
                        {
                            "ipv4Addr": "10.101.1.101",
                            "port": 32080
                        }
                    ],
                    "protocol": "HTTP_1_1",
                    "versions": [
                        {
                            "apiVersion": "",
                            "resources": [
                                {
                                    "commType": "REQUEST_RESPONSE",
                                    "operations": [
                                        "GET"
                                    ],
                                    "resourceName": "helloworld",
                                    "uri": "/helloworld"
                                },
                                {
                                    "commType": "REQUEST_RESPONSE",
                                    "operations": [
                                        "GET"
                                    ],
                                    "resourceName": "helloworld_sme",
                                    "uri": "/helloworld/sme"
                                }
                            ]
                        }
                    ]
                }
            ],
            "apiId": "api_id_helloworld",
            "apiName": "helloworld",
            "description": "Description,namespace,repoName,chartName,releaseName"
        }
	],
    "NotificationDestination": "http://invoker-app-kong:8086/callback",
    "onboardingInformation": {
		"apiInvokerPublicKey": "{PUBLIC_KEY_INVOKER_KONG_2}",
		"apiInvokerCertificate": "apiInvokerCertificate"
  },
  "requestTestNotification": true
}'
```

Output: 
```bash
{
    "apiInvokerId": "api_invoker_id_rAppKong_as_invoker_3",
    "apiInvokerInformation": "rAppKong as invoker 3",
    "notificationDestination": "http://invoker-app-kong:8086/callback",
    "onboardingInformation": {
        "apiInvokerCertificate": "apiInvokerCertificate",
        "apiInvokerPublicKey": "{PUBLIC_KEY_INVOKER_KONG_2}"
    },
    "requestTestNotification": true
}
```

Acessing the hashed uri of the published services using the invoker

```bash
command: $   curl -X GET \
 -H "Accept: application/json,application/problem+json" \
 "http://172.18.0.2:31575/service-apis/v1/allServiceAPIs?api-invoker-id=api_invoker_id_rAppKong_as_invoker_3&aef-id=AEF_id_AIMLTrainingservice_as_AEF" | jq .
 
 
 Output: 
    {
      "aefProfiles": [
        {
          "aefId": "AEF_id_AIMLTrainingservice_as_AEF",
          "domainName": "kong",
          "interfaceDescriptions": [
            {
              "ipv4Addr": "oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local",
              "port": 80
            }
          ],
          "protocol": "HTTP_1_1",
          "versions": [
            {
              "apiVersion": "",
              "resources": [
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "GET"
                  ],
                  "resourceName": "getPipeline",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/pipelines"
                },
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "POST"
                  ],
                  "resourceName": "CreateFeatureGroup",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/featureGroup"
                },
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "POST"
                  ],
                  "resourceName": "CreateTrainingJob",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/{training_job_id}"
                },
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "POST"
                  ],
                  "resourceName": "StartTraining",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/{training_job_id}/training"
                },
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "GET"
                  ],
                  "resourceName": "GetTrainingJob",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/{training_job_id}/{version}"
                },
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "DELETE"
                  ],
                  "resourceName": "DeleteTrainingJob",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs"
                },
                {
                  "commType": "REQUEST_RESPONSE",
                  "operations": [
                    "GET"
                  ],
                  "resourceName": "RetrainingJob",
                  "uri": "/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/retraining"
                }
              ]
            }
          ]
        }
      ],
      "apiId": "api_id_AIMLT-http7",
      "apiName": "AIMLT-http7",
      "description": "Description,namespace,repoName,chartName,releaseName"
    }
```
## Step 3: Use the hasshed URIs to acces the API functions  

Function 1:Post request to create a featuregroup 
 
 to run the curl command inside the pod: kubectl run mycurlpod --image=curlimages/curl --rm -i --tty -- sh
 
Command: curl --location 'http://oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local:80/AIMLT-http2/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/featureGroup' \

--header 'Content-Type: application/json' \

--data '{"featureGroupName":"testing_influxdb_4","feature_list":"pdcpBytesDl,pdcpBytesUl","datalake_source":"InfluxSource","enable_Dme":false,"Host":"my-release-influxdb.default","Port":"8086","dmePort":"","bucket":"pm-bucket","token":"asjkahsjdhaksdhaksdha","source_name":"","measured_obj_class":"","_measurement":"liveCell","dbOrg":"primary"}'

Output: {"result": "Feature Group Created"}


Function 2: Post request to create trainingJob   
(feature group same as above)

curl -X POST --location 'http://oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local:80/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/testing_influxdb_103' \

--header 'Content-Type: application/json' \

--data '{"trainingjob_name":"testing_influxdb_103","is_mme":false,"model_name":"","pipeline_name":"pipeline_kfp2.2.0_6","experiment_name":"Default","featureGroup_name":"testing_influxdb","query_filter":"","arguments":{"epochs":"1","trainingjob_name":"testing_influxdb_103"},"enable_versioning":false,"description":"testing","pipeline_version":"pipeline_kfp2.2.0_6","datalake_source":"InfluxSource"}'


Output: 
{"result": "Information stored in database."}

Function 3: Post request to start training


curl --location 'http://oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local:80/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/testing_influxdb_103/training"' \

--header 'Content-Type: application/json' \

--data '{"trainingjobs":"testing_influxdb_103"}'

Output:
{"trainingjob_name": "testing_influxdb_103", "result": "/task-status/testing_influxdb_103"}


Function 4: Get Training Job Name 

curl -X GET --location 'http://oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local:80/AIMLT-http9/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/testing_influxdb_103/1'

Output: 
{"trainingjob": {"trainingjob_name": "testing_influxdb_103", "description": "testing", "feature_list": "testing_influxdb", "pipeline_name": "pipeline_kfp2.2.0_6", "experiment_name": "Default", "arguments": {"epochs": "1", "trainingjob_name": "testing_influxdb_103"}, "query_filter": "", "creation_time": "2024-09-17 09:35:48.827106", "run_id": "e444f1fa-46d6-44ae-adaa-0668a03c6df6", "steps_state": {"DATA_EXTRACTION": "FINISHED", "DATA_EXTRACTION_AND_TRAINING": "FINISHED", "TRAINING": "FINISHED", "TRAINING_AND_TRAINED_MODEL": "FINISHED", "TRAINED_MODEL": "FINISHED"}, "updation_time": "2024-09-17 09:40:33.105334", "version": 1, "enable_versioning": false, "pipeline_version": "pipeline_kfp2.2.0_6", "datalake_source": "InfluxSource", "model_url": "http://10.0.0.10:32002/model/testing_influxdb_103/1/Model.zip", "notification_url": "", "is_mme": false, "model_name": false, "model_info": "", "accuracy": "{\"metrics\": [{\"Accuracy\": \"0.0012591038143439082\"}]}"}}


Function 5: RetrainingJob

curl --location 'http://oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local:80/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs/retraining' \

--header 'Content-Type: application/json' \

--data '{"trainingjobs_list":[{"trainingjob_name":"testing_influxdb_103"}]}'

Output:
{"success count": 1, "failure count": 0}


Function 6: Delete Job 
curl --location --request DELETE 'http://oran-nonrtric-kong-proxy.nonrtric.svc.cluster.local:80/AIMLT-http7/port-32002-hash-be75777a-c18e-5db1-a3ac-38148631d1fa/trainingjobs' \

--header 'Content-Type: application/json' \

--data '{"list":[{"trainingjob_name":"testing_influxdb_102","version":1}]}'

Output:

{"success count": 1, "failure count": 0}

