.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0

.. Copyright (c) 2024 Samsung Electronics Co., Ltd. All Rights Reserved.


RANPM Installation Guide
=========================

.. contents::
   :depth: 3
   :local:


Introduction
------------

.. <INTRODUCTION TO THE SCOPE AND INTENTION OF THIS DOCUMENT AS WELL AS TO THE SYSTEM TO BE INSTALLED>


This document describes the installation of RANPM, configuration of pm-log jobs and finally pushing PM report using RANPM



Setting Up Kubernetes Environment
------------------------------------
.. <DESCRIBE THE INTIAL KUBERNETES ENVIRONMENT FOR THE INSTALLATION OF RANPM>

1. Deploy kubernetes cluster v1.24

.. code-block:: bash
        
        sudo kind create cluster --config - << EOF
        kind: Cluster
        apiVersion: kind.x-k8s.io/v1alpha4
        nodes:
          - role: control-plane
            extraPortMappings:
              - containerPort: 31784
                hostPort: 31784
                protocol: TCP
              - containerPort: 31823
                hostPort: 31823
                protocol: TCP
              - containerPort: 31767
                hostPort: 31767
                protocol: TCP
            image: kindest/node:v1.24.17@sha256:bad10f9b98d54586cba05a7eaa1b61c6b90bfc4ee174fdc43a7b75ca75c95e51
        EOF

        # Enable k8s cluster to be ascessed by normal user
        sudo cp -r  /root/.kube $HOME/
        sudo chown -R $USER $HOME/.kube

2. Deploy Istio v1.23.2

.. code-block:: bash
        
        curl -L https://istio.io/downloadIstio | ISTIO_VERSION=1.23.2  sh -
        cd istio-1.23.2/
        export PATH=$PWD/bin:$PATH
        istioctl install

3. Build & Load Local Images

.. code-block:: bash

        # Clone RANPM
        git clone "https://gerrit.o-ran-sc.org/r/nonrtric/plt/ranpm"
        cd ranpm/

        # Build & Load 'pm-https-server' Image
        cd https-server/
        ./build.sh no-push
        kind load docker-image pm-https-server:latest

        # Build & Load 'pm-rapp' Image
        cd pm-rapp/
        ./build.sh no-push
        kind load docker-image pm-rapp:latest

Note: For More Build Options, refer to Readme of both components



Deploying RANPM
------------------

.. <DESCRIBE THE DEPLOYMENT OF RANPM>

1. Make sure the following dependencies are installed:

.. code-block:: bash
        
        # Helm, jq, openssl
        curl https://baltocdn.com/helm/signing.asc | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
        sudo apt-get install apt-transport-https --yes
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/helm.gpg] https://baltocdn.com/helm/stable/debian/ all main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
        sudo apt-get update
        sudo apt-get install helm jq openssl 

        # For Keytool (Install java)
        sudo apt install openjdk-21-jre-headless

        # Confirm the installations
        type openssl helm jq envsubst keytool


2. Deploying RANPM

.. code-block:: bash

        cd ./ranpm/install
        nano helm/global-values.yaml # Edit to change any default parameter
        sudo bash ./install-ranpm.sh

3. Verify Deployment

.. code-block:: bash

        ~$ kubectl get pods -n nonrtric
        
        NAME                                        READY   STATUS    RESTARTS      AGE
        bundle-server-7f5c4965c7-bqzt6              1/1     Running   0             18m
        controlpanel-7f94bd9d6-c8qjx                1/1     Running   0             16m
        dfc-0                                       2/2     Running   0             15m
        influxdb2-0                                 1/1     Running   0             18m
        informationservice-68b5f655f-cwjnd          1/1     Running   0             15m
        kafka-1-entity-operator-77c545f9cc-nmwjz    2/2     Running   0             17m
        kafka-1-kafka-0                             1/1     Running   0             17m
        kafka-1-zookeeper-0                         1/1     Running   0             18m
        kafka-client                                1/1     Running   0             20m
        kafka-producer-pm-json2influx-0             1/1     Running   0             15m
        kafka-producer-pm-json2kafka-0              1/1     Running   0             15m
        kafka-producer-pm-xml2json-0                1/1     Running   0             15m
        keycloak-597d95bbc5-6w5kl                   1/1     Running   0             20m
        keycloak-proxy-57f6c97984-kxxwz             1/1     Running   3 (19m ago)   20m
        message-router-7d977b5554-pddtf             1/1     Running   3 (17m ago)   18m
        minio-0                                     1/1     Running   0             18m
        minio-client                                1/1     Running   0             18m
        nonrtricgateway-864bf4bb55-llq77            1/1     Running   0             17m
        opa-ics-54fdf87d89-2lv7c                    1/1     Running   0             15m
        opa-kafka-6665d545c5-68x5p                  1/1     Running   0             18m
        opa-minio-5d6f5d89dc-b9cxn                  1/1     Running   0             18m
        pm-producer-json2kafka-0                    2/2     Running   0             15m
        pm-rapp                                     1/1     Running   0             14m
        pmlog-0                                     2/2     Running   0             10h
        redpanda-console-b85489cc9-rkfj9            1/1     Running   2 (17m ago)   18m
        strimzi-cluster-operator-68c8d8b774-jqnj5   1/1     Running   0             19m
        ves-collector-bd756b64c-pzjfs               1/1     Running   0             18m
        zoo-entrance-85878c564d-7qn2h               1/1     Running   0             18m



        ~$ kubectl get pods -n ran
        
        NAME                READY   STATUS    RESTARTS   AGE
        pm-https-server-0   1/1     Running   0          18m
        pm-https-server-1   1/1     Running   0          18m
        pm-https-server-2   1/1     Running   0          18m
        pm-https-server-3   1/1     Running   0          18m
        pm-https-server-4   1/1     Running   0          18m
        pm-https-server-5   1/1     Running   0          18m
        pm-https-server-6   1/1     Running   0          18m
        pm-https-server-7   1/1     Running   0          18m
        pm-https-server-8   1/1     Running   0          18m
        pm-https-server-9   1/1     Running   0          18m


Troubleshooting RANPM Deployment
---------------------------------
1. Deployment stuck waiting for Kafka-client 

Update 'quorumListenOnAllIPs: true' at Zookeeper config & then Reinstall

.. code-block:: diff

        --- a/install/helm/nrt-base-1/charts/strimzi-kafka/templates/app-kafka.yaml
        +++ b/install/helm/nrt-base-1/charts/strimzi-kafka/templates/app-kafka.yaml
        @@ -63,6 +63,9 @@ spec:
        replicas: 1
        storage:
        type: ephemeral
        +    config:
        +      # new - config
        +      quorumListenOnAllIPs: true
        entityOperator:
        topicOperator: {}
        userOperator: {}



Pushing PM Reports
------------------
.. <DESCRIBE THE SCRIPT TO PUSH PM REPORTS TO RANPM>

1. Create ICS job

.. code-block:: bash

        curl --location --request PUT 'http://<RANPM-Ip>:31823/data-consumer/v1/info-jobs/job1' \
        --header 'Content-Type: application/json' \
        --data '{
                "info_type_id": "PmData",
                "job_owner": "console",
                "job_definition": {
                "filter": {
                        "sourceNames": [],
                        "measObjInstIds": [],
                        "measTypeSpecs": [
                        {
                        "measuredObjClass": "NRCellDU",
                        "measTypes": [
                                "throughput",
                                "x",
                                "y",
                                "availPrbDl",
                                "availPrbUl",
                                "measPeriodPrb",
                                "pdcpBytesUl",
                                "pdcpBytesDl",
                                "measPeriodPdcpBytes"
                                ]
                        }
                        ],
                        "measuredEntityDns": []
                },
                "deliveryInfo": {
                        "topic": "pmreports",
                        "bootStrapServers": "kafka-1-kafka-bootstrap.nonrtric:9097"
                        }
                }
        }'

Confirm ICS Job-creation

.. code-block:: bash

        curl --location 'http://<RANPM-Ip>:31823/data-consumer/v1/info-jobs/job1' | jq .

2. Clone and run script to Push data

.. code-block:: bash

        # Clone the aimlfw-dep
        git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/aimlfw-dep"
        cd aimlfw-dep/demos/hrelease/scripts

Execute below script to push qoe data into ranpm setup

.. code:: bash

        ./push_qoe_data.sh  <source name mentioned when creating feature group> <Number of rows> <Cell Identity>


The Following script downloads `cells.csv <https://raw.githubusercontent.com/o-ran-sc/ric-app-qp/g-release/src/cells.csv>`__ , filters the data based on ``Cell Identity``,
For each PM report, the script convert the PM-report to XML documents, uploads it to one of 'pm-https-server', and sends a File-Ready event on Kafka-topic signifying that the PM report is ready to be processed by RANPM.
Once the file is processed, the PM reports is stored under bucket_name `pm-logg-bucket` and measurement `test,ManagedElement=nodedntest,GNBDUFunction=1004,NRCellDU=<Cell Identity>` which will be reffered while creating featureGroup in further-steps.

Example for executing above script

.. code:: bash
        
        ./push_qoe_data.sh  gnb300505 30 c4/B2



3. Confirm if data is uploaded correctly

.. code:: bash

        kubectl exec -it influxdb2-0 -n nonrtric -- influx query 'from(bucket: "pm-logg-bucket") |> range(start: -1000000000000000000d)' |grep pdcpBytesDl


4. Steps to clear data in InfluxDB

.. code:: bash

        kubectl exec -it influxdb2-0 -n nonrtric -- influx delete --bucket pm-logg-bucket --start 1801-01-27T05:00:22.305309038Z   --stop 2023-11-14T00:00:00Z

5. Delete ICS job

.. code:: bash

        curl --location --request DELETE 'http://<RANPM-Ip>:31823/data-consumer/v1/info-jobs/job1'

Uninstalling RANPM
------------------

.. code-block:: bash

        cd ./ranpm/install
        sudo bash ./uninstall-ranpm.sh

Using Non-RT RIC DME as data source for AIMLFW
----------------------------------------------

1. Deploy AIMLFW
        Please refer `here <https://docs.o-ran-sc.org/projects/o-ran-sc-aiml-fw-aimlfw-dep/en/latest/installation-guide.html#software-installation-and-deployment>`__ for AIMLFW Installation

2. Create FeatureGroup

        i) Get RANPM InfluxDb Token

        .. code-block:: bash

                git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/aimlfw-dep"
                cd aimlfw-dep/demos/hrelease/scripts
                # The following script will give the inflxu-Token for RANPM
                ./get_access_tokens.sh

        ii) Prepare RANPM for AIMLFW ascess

        .. code-block:: bash

                ./prepare_env_aimlfw_access.sh
                # Make influxDb accessible by port-fowarding (Keep it running)
                kubectl port-forward svc/influxdb2 -n nonrtric 8086:8086 --address 0.0.0.0 
        
        iii) Create FeatureGroup at AIMLFW

        .. code-block:: bash

                curl --location '<AIMLFW-Ip>:32002/ai-ml-model-training/v1/featureGroup' \
                --header 'Content-Type: application/json' \
                --data '{
                        "featuregroup_name": "<FEATURE_GROUP_NAME>",
                        "feature_list": "x,y,pdcpBytesDl,pdcpBytesUl",
                        "datalake_source": "InfluxSource",
                        "enable_dme": true,
                        "host": "<RANPM-IP>",
                        "port": "8086",
                        "dme_port": "31823",
                        "bucket": "pm-logg-bucket",
                        "token": "<INFLUX_DB_TOKEN>",
                        "source_name": "",
                        "measured_obj_class": "NRCellDU",
                        "measurement": "test,ManagedElement=nodedntest,GNBDUFunction=1004,NRCellDU=c4_B13",
                        "db_org": "est"
                } '
        
        | Note: 
        | a. AIMLFW-Ip: Refers to the VM-Ip where AIMLFW is installed
        | b. RANPM-ip: Refers to the VM-ip where RANPM is installed 
        | c. port: Refers to influxDB port which we have exposed in Step-2 i.e. 8086
        | d. dme_port: Refers to the Nodeport of InformationService (in RANPM) generally, 31823
        | e. INFLUX_DB_TOKEN: Refers to the token recieved from Step-1


        .. code-block:: bash
                
                # Confirm ICS job creation
                curl --location 'http://<RANPM-Ip>:31823/data-consumer/v1/info-jobs/<FEATURE_GROUP_NAME>' | jq .


3. Simulate RAN-Traffic to RANPM by Pushing PM-reports

        .. code-block:: bash

                cd aimlfw-dep/demos/hrelease/scripts
                ./push_qoe_data.sh  gnb300505 30 c4/B13

        Confirm the data in influxDb

        .. code-block:: bash

                kubectl exec -it influxdb2-0 -n nonrtric -- bash
                influx v1 shell
                use "pm-logg-bucket"
                SELECT * from "test,ManagedElement=nodedntest,GNBDUFunction=1004,NRCellDU=c4_B13"


        The Measurement MUST contain 4 columns as per x,y,pdcpBytesDl,pdcpBytesUl.

4. Create TrainingJob

        Please refer `here <https://docs.o-ran-sc.org/projects/o-ran-sc-aiml-fw-aimlfw-dep/en/latest/installation-guide.html#training-job-creation-with-dme-or-standalone-influxdb-as-data-source>`__ and use the featureGroup created in Step 2. 
 