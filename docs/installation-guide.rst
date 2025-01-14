.. This work is licensed under a Creative Commons Attribution 4.0 International License.
.. http://creativecommons.org/licenses/by/4.0

.. Copyright (c) 2022 Samsung Electronics Co., Ltd. All Rights Reserved.


Installation Guide
==================

.. contents::
   :depth: 3
   :local:

Abstract
--------

This document describes how to install AIMLFW, demo scenarios, it's dependencies and required system resources.


Version history

+--------------------+--------------------+--------------------+-----------------------+
| **Date**           | **Ver.**           | **Author**         | **Comment**           |
|                    |                    |                    |                       |
+--------------------+--------------------+--------------------+-----------------------+
| 2022-11-30         | 0.1.0              | 		       | First draft           |
|                    |                    |                    |                       |
+--------------------+--------------------+--------------------+-----------------------+
| 2023-06-06         | 1.0.0              | Joseph Thaliath    | H Release             |
|                    |                    |                    |                       |
+--------------------+--------------------+--------------------+-----------------------+
| 2023-08-10         | 1.0.1              | Joseph Thaliath    | H Maintenance release |
|                    |                    |                    |                       |
+--------------------+--------------------+--------------------+-----------------------+
| 2023-12-14         | 1.1.0              | Joseph Thaliath    | I release             |
|                    |                    |                    |                       |
+--------------------+--------------------+--------------------+-----------------------+
| 2023-12-14         | 2.0.0              | Rajdeep Singh      | K release             |
|                    |                    |                    |                       |
+--------------------+--------------------+--------------------+-----------------------+


Introduction
------------

.. <INTRODUCTION TO THE SCOPE AND INTENTION OF THIS DOCUMENT AS WELL AS TO THE SYSTEM TO BE INSTALLED>


This document describes the supported software and hardware configurations for the reference component as well as providing guidelines on how to install and configure such reference system.

The audience of this document is assumed to have good knowledge in AI/ML tools, Kubernetes and Linux system.


Hardware Requirements
---------------------
.. <PROVIDE A LIST OF MINIMUM HARDWARE REQUIREMENTS NEEDED FOR THE INSTALL>

Below are the minimum requirements for installing the AIMLFW

#. OS: Ubuntu 22.04 server
#. 16 cpu cores
#. 32 GB RAM
#. 60 GB harddisk

..  _reference1:

Software Installation and Deployment
------------------------------------
.. <DESCRIBE THE FULL PROCEDURES FOR THE INSTALLATION OF THE O-RAN COMPONENT INSTALLATION AND DEPLOYMENT>

.. code:: bash

        git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/aimlfw-dep"
        cd aimlfw-dep

Update recipe file :file:`RECIPE_EXAMPLE/example_recipe_latest_stable.yaml` which includes update of VM IP and datalake details.

**Note**: In case the Influx DB datalake is not available, this can be skipped at this stage and can be updated after installing datalake.

.. code:: bash

        bin/install_traininghost.sh



Check running state of all pods and services using below command

.. code:: bash

        kubectl get pods --all-namespaces
        kubectl get svc --all-namespaces


Check the AIMLFW dashboard by using the following url

.. code:: bash

        http://localhost:32005/

In case of any change required in the RECIPE_EXAMPLE/example_recipe_latest_stable.yaml file after installation, 
the following steps can be followed to reinstall with new changes.

.. code:: bash

        bin/uninstall.sh
        bin/install.sh -f RECIPE_EXAMPLE/example_recipe_latest_stable.yaml


Software Uninstallation
-----------------------

.. code:: bash

        bin/uninstall_traininghost.sh

.. _install-influx-db-as-datalake:

..  _reference2:


Install Influx DB as datalake (Optional)
----------------------------------------

Standalone Influx DB installation can be used if DME is not used as a data source.

.. code:: bash

        helm repo add bitnami https://charts.bitnami.com/bitnami
        helm install my-release bitnami/influxdb --version 5.13.5
        kubectl exec -it <pod name> bash

From below command  we can get username, org name, org id and access token

.. code:: bash

        cat bitnami/influxdb/influxd.bolt | tr -cd "[:print:]"

eg:   {"id":"0a576f4ba82db000","token":"xJVlOom1GRUxDNkldo1v","status":"active","description":"admin's Token","orgID":"783d5882c44b34f0","userID":"0a576f4b91edb000","permissions" ...

Use the tokens further in the below configurations and in the recipe file.

Following are the steps to add qoe data to Influx DB.


Execute below from inside Influx DB container to create a bucket:

.. code:: bash

        influx bucket create -n UEData -o primary -t <token>


Install the following dependencies

.. code:: bash

        sudo pip3 install pandas
        sudo pip3 install influxdb_client


Use the :file:`insert.py` in ``ric-app/qp repository`` to upload the qoe data in Influx DB


.. code:: bash

        git clone -b f-release https://gerrit.o-ran-sc.org/r/ric-app/qp
        cd qp/qp

Update :file:`insert.py` file with the following content:

.. code-block:: python

        import pandas as pd
        from influxdb_client import InfluxDBClient
        from influxdb_client.client.write_api import SYNCHRONOUS
        import datetime


        class INSERTDATA:

           def __init__(self):
                self.client = InfluxDBClient(url = "http://localhost:8086", token="<token>")


        def explode(df):
             for col in df.columns:
                     if isinstance(df.iloc[0][col], list):
                             df = df.explode(col)
                     d = df[col].apply(pd.Series)
                     df[d.columns] = d
                     df = df.drop(col, axis=1)
             return df
        

        def jsonToTable(df):
             df.index = range(len(df))
             cols = [col for col in df.columns if isinstance(df.iloc[0][col], (dict, list))]
             if len(cols) == 0:
                     return df
             for col in cols:
                     d = explode(pd.DataFrame(df[col], columns=[col]))
                     d = d.dropna(axis=1, how='all')
                     df = pd.concat([df, d], axis=1)
                     df = df.drop(col, axis=1).dropna()
             return jsonToTable(df)


        def time(df):
             df.index = pd.date_range(start=datetime.datetime.now(), freq='10ms', periods=len(df))
             df['measTimeStampRf'] = df['measTimeStampRf'].astype(str)
             return df


        def populatedb():
             df = pd.read_json('cell.json.gz', lines=True)
             df = df[['cellMeasReport']].dropna()
             df = jsonToTable(df)
             df = time(df)
             db = INSERTDATA()
             write_api = db.client.write_api(write_options=SYNCHRONOUS)
             write_api.write(bucket="UEData",record=df, data_frame_measurement_name="liveCell",org="primary")

        populatedb()


Update ``<token>`` in :file:`insert.py` file

Follow below command to port forward to access Influx DB

.. code:: bash

        kubectl port-forward svc/my-release-influxdb 8086:8086

To insert data:

.. code:: bash

        python3 insert.py

To check inserted data in Influx DB , execute below command inside the Influx DB container:

.. code:: bash

        influx query  'from(bucket: "UEData") |> range(start: -1000d)' -o primary -t <token>



..  _reference3:

Prepare Non-RT RIC DME as data source for AIMLFW (optional)
-----------------------------------------------------------

Bring up the RANPM setup by following the steps mentioned in the file install/README.md present in the repository `RANPM repository <https://gerrit.o-ran-sc.org/r/admin/repos/nonrtric/plt/ranpm>`__

Once all the pods are in running state, follow the below steps to prepare ranpm setup for AIMLFW qoe usecase data access

The scripts files are present in the folder demos/hrelease/scripts of repository `AIMLFW repository <https://gerrit.o-ran-sc.org/r/admin/repos/aiml-fw/aimlfw-dep>`__

Note: The following steps need to be performed in the VM where the ranpm setup is installed.

.. code:: bash

        git clone "https://gerrit.o-ran-sc.org/r/aiml-fw/aimlfw-dep"
        cd aimlfw-dep/demos/hrelease/scripts
        ./get_access_tokens.sh

Output of ./get_access_tokens.sh can be used during feature group creation step.


Execute the below script

.. code:: bash

        ./prepare_env_aimlfw_access.sh

Add feature group from AIMLFW dashboard, example on how to create a feature group is shown in this demo video: `Feature group creation demo <https://lf-o-ran-sc.atlassian.net/wiki/download/attachments/13697168/feature_group_create_final_lowres.mp4?api=v2>`__

Execute below script to push qoe data into ranpm setup

.. code:: bash

        ./push_qoe_data.sh  <source name mentioned when creating feature group> <Number of rows> <Cell Identity>

Example for executing above script

.. code:: bash
        
        ./push_qoe_data.sh  gnb300505 30 c4/B2

Steps to check if data is upload correctly


.. code:: bash

        kubectl exec -it influxdb2-0 -n nonrtric -- bash
        influx query 'from(bucket: "pm-logg-bucket") |> range(start: -1000000000000000000d)' |grep pdcpBytesDl

Steps to clear the data in InfluxDB

.. code:: bash

        kubectl exec -it influxdb2-0 -n nonrtric -- bash
        influx delete --bucket pm-logg-bucket --start 1801-01-27T05:00:22.305309038Z   --stop 2023-11-14T00:00:00Z

        
Feature group creation
----------------------

From AIMLFW dashboard create feature group (Training Jobs-> Create Feature Group ) Or curl 

NOTE: Here is a curl request to create feature group using curl

.. code:: bash

        curl --location 'http://<VM IP where AIMLFW is installed>:32002/ai-ml-model-training/v1/featureGroup' \
              --header 'Content-Type: application/json' \
              --data '{
                        "featuregroup_name": "<Name of the feature group>",
                        "feature_list": "<Features in a comma separated format>",
                        "datalake_source": "InfluxSource",
                        "enable_dme": <True for DME use, False for Standalone Influx DB>,
                        "host": "<IP of VM where Influx DB is installed>",
                        "port": "<Port of Influx DB>",",
                        "dme_port": "",
                        "bucket": "<Bucket Name>",
                        "token": "<INFLUX_DB_TOKEN>",
                        "source_name": "<any source name. but same needs to be given when running push_qoe_data.sh>",
                        "measured_obj_class": "",
                        "measurement": "<Measurement of the db>",
                        "db_org": "<Org of the db>"
                    }'

NOTE: Below are some example values to be used for the DME based feature group creation for qoe usecase

.. code:: bash

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

NOTE: Below are some example values to be used for the standalone influx DB creation for qoe usecase. Dme is not used in this example. 

.. code:: bash

        curl --location 'http://<VM IP where AIMLFW is installed>:32002/ai-ml-model-training/v1/featureGroup' \
              --header 'Content-Type: application/json' \
              --data '{
                        "featuregroup_name": "<Feature Group name>",
                        "feature_list": "pdcpBytesDl,pdcpBytesUl",
                        "datalake_source": "InfluxSource",
                        "enable_dme": false,
                        "host": "my-release-influxdb.default",
                        "port": "8086",
                        "dme_port": "",
                        "bucket": "UEData",
                        "token": "<INFLUX_DB_TOKEN>",
                        "source_name": "",
                        "measured_obj_class": "",
                        "measurement": "liveCell",
                        "db_org": "primary"
                    }'

Register Model (compulsory)
---------------------------

Register the model using the below steps if using Model management service for training.

.. code:: bash

        curl --location 'http://<VM IP where AIMLFW is installed>:32006/ai-ml-model-registration/v1/registerModel' \
              --header 'Content-Type: application/json' \
              --data '{
                    "modelId": {
                        "modelName": "modeltest1",
                        "modelVersion": "1"
                    },
                    "description": "This is a test model.",
                    "modelInformation": {
                        "metadata": {
                            "author": "John Doe"
                        },
                        "inputDataType": "pdcpBytesDl,pdcpBytesUl",
                        "outputDataType": "pdcpBytesDl,pdcpBytesUl"
                    }
                }'

Model Discovery
---------------

Model discovery can be done using the following API endpoint:


To fetch all registered models, use the following API endpoint:

.. code:: bash

    curl --location 'http://<VM IP where AIMLFW is installed>:32006/ai-ml-model-discovery/v1/models'

To fetch models with model name , use the following API endpoint:

.. code:: bash

    curl --location 'http://<VM IP where AIMLFW is installed>:32006/ai-ml-model-discovery/v1/models?model-name=<model_name>'

To fetch specific model, use the following API endpoint:

.. code:: bash

    curl --location 'http://<VM IP where AIMLFW is installed>:32006/ai-ml-model-discovery/v1/models?model-name=<model_name>&&model-version=<model_version>'


Training job creation with DME or Standalone InfluxDB as data source
--------------------------------------------------------------------

#. AIMLFW should be installed by following steps in section :ref:`Software Installation and Deployment <reference1>`
#. RANPM setup should be installed and configured as per steps mentioned in section :ref:`Prepare Non-RT RIC DME as data source for AIMLFW <reference3>`
#. After training job is created and executed successfully, model can be deployed using steps mentioned in section :ref:`Deploy trained qoe prediction model on Kserve <reference4>` or 
   :ref:`Steps to deploy model using Kserve adapter <reference6>`

NOTE: The QoE training function does not come pre uploaded, we need to go to training function, create training function and run the qoe-pipeline notebook.

.. code:: bash

        curl --location 'http://<VM IP where AIMLFW is installed>:32002/ai-ml-model-training/v1/training-jobs' \
              --header 'Content-Type: application/json' \
              --data '{
                        "modelId":{
                            "modelname": "modeltest15",
                            "modelversion": "1"
                        },
                        "model_location": "",
                        "training_config": {
                            "description": "trainingjob for testing",
                            "dataPipeline": {
                                "feature_group_name": "testing_influxdb_01",
                                "query_filter": "",
                                "arguments": "{'epochs': 1}"
                            },
                            "trainingPipeline": {
                                    "training_pipeline_name": "qoe_Pipeline_testing_1", 
                                    "training_pipeline_version": "qoe_Pipeline_testing_1", 
                                    "retraining_pipeline_name":"qoe_Pipeline_retrain",
                                    "retraining_pipeline_version":"2"
                            }
                        },
                        "training_dataset": "",
                        "validation_dataset": "",
                        "notification_url": "",
                        "consumer_rapp_id": "",
                        "producer_rapp_id": ""
                    }'

..  _reference7:

Obtain the Status of Training Job
---------------------------------

The Status of Trainingjob can be featched using the following API endpoint. Replace <TrainingjobId> with the ID of the training job.

.. code:: bash

    curl --location http://<AIMLFW-Ip>:32002/ai-ml-model-training/v1/training-jobs/<TrainingjobId>/status


..  _reference5:

Obtain Model URL for deploying trained models
---------------------------------------------

You can curl the following API endpoint to obtain Trainingjob Info and fetch model_url for deployment after training is complete. Replace <TrainingjobId> with the ID of the training job.

.. code:: bash

    curl --location 'http://<AIMLFW-Ip>:32002/ai-ml-model-training/v1/training-jobs/<TrainingjobId>'

OR you can download the model using Model_name, Model_version, Model_artifact_version as follows:

.. code:: bash

    wget http://<AIMLFW-Ip>:32002/model/<MODEL_NAME>/<MODEL_VERSION>/<MODEL_ARTIFACT_VERSION>/Model.zip


Model-Retraining
----------------------------------------
A previously trained model can be retrained with different configurations/data as follows:

.. code:: bash

        curl --location 'localhost:32002/ai-ml-model-training/v1/training-jobs' \
        --header 'Content-Type: application/json' \
        --data '{
                "modelId": {
                "modelname":"<MODEL_TO_RETRAIN>",
                "modelversion":"<MODEL_VERSION_TO_RETRAIN>"
        },
        "training_config": {
                "description": "Retraining-Example",
                "dataPipeline": {
                "feature_group_name": "<FEATUREGROUP_NAME>",
                "query_filter": "",
                "arguments": {"epochs": 20}
                },
                "trainingPipeline": {
                        "training_pipeline_name": "qoe_Pipeline",
                        "training_pipeline_version": "qoe_Pipeline",
                        "retraining_pipeline_name": "qoe_Pipeline_retrain",
                        "retraining_pipeline_version": "qoe_Pipeline_retrain"
                }
        },
        "model_location": ""
        }'

| The user can specify different configurations as well as retraining-pipeline by modifying the training-config.
| The default `qoe_Pipeline_retrain` pipeline fetches and loads the existing model, retrains it with new arguments or data, and updates the artifact version from 1.0.0 to 1.1.0.

Verify Updated Artifact-Version after retraining from MME

.. code:: bash

        curl --location 'localhost:32006/ai-ml-model-discovery/v1/models/?model-name=<MODEL_NAME>&model-version=<MODEL_VERSION>'


| Note: 
| a. The QoE retraining function does not come pre uploaded, we need to go to training function, create training function and run the `qoe-pipeline-retrain-2` notebook.
| b. Subsequent retrainings will update the artifact version as follows: 
|               From 1.x.0 to 1.(x + 1).0


..  _reference4:

Model-Deployment
----------------------------------------

1. Installing Kserve

.. code:: bash

        ./bin/install_kserve.sh

2. Verify Installation

.. code:: bash

        ~$ kubectl get pods -n kserve
        
        NAME                                        READY   STATUS    RESTARTS   AGE
        kserve-controller-manager-5d995bd58-9pf6x   2/2     Running   0          6d18h

3. Deploy trained qoe prediction model on Kserve

.. code:: bash

        # Create namespace
        kubectl create namespace kserve-test


Create :file:`qoe.yaml` file with below contents

.. code-block:: yaml

        apiVersion: "serving.kserve.io/v1beta1"
        kind: "InferenceService"
        metadata:
          name: "qoe-model"
          namespace: kserve-test
        spec:
          predictor:
            model:
              modelFormat:
                name: tensorflow
              storageUri: "<MODEL URL>"


To deploy model update the Model URL in the :file:`qoe.yaml` file and execute below command to deploy model
Refer :ref:`Obtain Model URL for deploying trained models <reference5>`

.. code:: bash

        kubectl apply -f qoe.yaml

        
Verify Model-Deployment


.. code:: bash

        ~$ kubectl get InferenceService -n kserve-test

        NAME        URL                                              READY   PREV   LATEST   PREVROLLEDOUTREVISION   LATESTREADYREVISION         AGE
        qoe-model   http://qoe-model.kserve-test.svc.cluster.local   True           100                              qoe-model-predictor-00001   42s


        ~$ kubectl get pods -n kserve-test

        NAME                                                   READY   STATUS    RESTARTS   AGE
        qoe-model-predictor-00001-deployment-86d9db6cb-5r8st   2/2     Running   0          93s         


4. Test predictions using model deployed on Kserve

In order to test our deployed-model, we will query the InferenceService from a curl-pod.

.. code:: bash

        # Deploy a curl-pod
        kubectl run curl-pod --image=curlimages/curl:latest --command sleep 3600
        # Query Inference-Service
        kubectl exec -it curl-pod -- \
                curl   \
                --location http://qoe-model.kserve-test.svc.cluster.local/v1/models/qoe-model:predict \
                --header "Content-Type: application/json" \
                --data '{
                        "signature_name": "serving_default",
                        "instances": [[
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56],
                                [2.56, 2.56]]
                                ]
                        }'

| Note: We can change which deployed-model to query by changing the location as:
| location = <KSERVE_HOST>/v1/models/<MODEL_NAME>:predict, where
| a. MODEL_NAME: Refers to the Name of Inference-Service
| b. KSERVE_HOST: Refers to the URL of Inference-Service



5. Uninstall Kserve

.. code:: bash

        ./bin/uninstall_kserve.sh 


For Advanced usecases, Please refer to official kserve-documentation `here <https://kserve.github.io/website/0.8/get_started/first_isvc/#1-create-a-namespace>`__ 


Install both Kserve and Kserve adapter for deploying models
-----------------------------------------------------------

To install Kserve run the below commands
Please note to update the DMS IP in example_recipe_latest_stable.yaml before installation 

.. code:: bash

        ./bin/install_kserve_inference.sh


Uninstall both Kserve and Kserve adapter for deploying models
-------------------------------------------------------------

To uninstall Kserve run the below commands

.. code:: bash

        ./bin/uninstall_kserve_inference.sh



..  _reference6:

Steps to deploy model using Kserve adapter
------------------------------------------

Prerequisites

#. Install chart museum
#. Build ricdms binary


#. Run ric dms

   .. code:: bash

        export RIC_DMS_CONFIG_FILE=$(pwd)/config/config-test.yaml
        ./ricdms


#. Create sample_config.json

   Create sample_config.json file with the following contents

   .. code:: bash

        {
          "xapp_name": "sample-xapp",
          "xapp_type": "inferenceservice",
          "version": "2.2.0",
          "sa_name": "default",
          "inferenceservice": {
              "engine": "tensorflow",
              "storage_uri": "<Model URL>",
              "runtime_version": "2.5.1",
              "api_version": "serving.kubeflow.org/v1beta1",
              "min_replicas": 1,
              "max_replicas": 1
          }
        }

       Refer :ref:`Obtain Model URL for deploying trained models <reference5>`

#. Copy sample_config.json
  
   Update the below command with kserve adapter pod name 

   .. code:: bash

      kubectl cp sample_config.json ricips/<kserve adapter pod name>:pkg/helm/data/sample_config.json

#. Generating and upload helm package

   .. code:: bash

        curl --request POST --url 'http://127.0.0.1:31000/v1/ips/preparation?configfile=pkg/helm/data/sample_config.json&schemafile=pkg/helm/data/sample_schema.json'

#. Check uploaded charts

   .. code:: bash

        curl http://127.0.0.1:8080/api/charts

#. Deploying the model

   .. code:: bash

        curl --request POST --url 'http://127.0.0.1:31000/v1/ips?name=inference-service&version=1.0.0'

#. Check deployed Inference service

   .. code:: bash

        kubectl get InferenceService -n ricips

