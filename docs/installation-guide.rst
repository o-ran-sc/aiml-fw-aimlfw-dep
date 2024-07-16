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
             cols = [col for col in df.columns if isinstance(df.iloc[0][col], dict) or isinstance(df.iloc[0][col], list)]
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
             df['measTimeStampRf'] = df['measTimeStampRf'].apply(lambda x: str(x))
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

Add feature group from AIMLFW dashboard, example on how to create a feature group is shown in this demo video: `Feature group creation demo <https://wiki.o-ran-sc.org/download/attachments/71762231/feature_group_create_final_lowres.mp4?api=v2>`__

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

From AIMLFW dashboard create feature group (Training Jobs-> Create Feature Group )

NOTE: Below are some example values to be used for the DME based feature group creation for qoe usecase

+--------------------+-------------------------------------------------------------------+
| **Parameter**      | **Value**                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Feature Group Name | featuregroup1                                                     |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Features           | pdcpBytesDl,pdcpBytesUl                                           |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Host               | <IP of VM where DME is installed>                                 |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Port               | 31812                                                             |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Db Org             | est                                                               |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Bucket Name        | pm-logg-bucket                                                    |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| DB Token           | <token obtained using get_access_tokens.sh during DME setup>      |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| _measurement       | test,ManagedElement=nodedntest,GNBDUFunction=1004,NRCellDU=c4_B2  |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| DME flag           | enable it                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Source Name        | <any source name. but same needs to be given when running         |
|                    |  push_qoe_data.sh>                                                |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Measured Obj Class | NRCellDU                                                          |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Dme port           | 31823                                                             |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+


NOTE: Below are some example values to be used for the standalone influx DB creation for qoe usecase

+--------------------+-------------------------------------------------------------------+
| **Parameter**      | **Value**                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Feature Group Name | featuregroup1                                                     |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Features           | pdcpBytesDl,pdcpBytesUl                                           |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Host               | <IP of VM where Influx DB is installed>                           |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Port               | <port of Influx DB>                                               |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Db Org             | primary                                                           |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Bucket Name        | UEData                                                            |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| DB Token           | <token obtained during INflux DB installation>                    |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| _measurement       | liveCell                                                          |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+

Register Model (optional)
-------------------------

Register the model using the below steps if using Model management service for training.

.. code:: bash

        curl --location 'http://<VM IP where AIMLFW is installed>:32006/registerModel' \
              --header 'Content-Type: application/json' \
              --data '{
                 "model-name":"qoe1",
                 "rapp-id": "rapp_1",
                 "meta-info" : 
                 {
                     "accuracy":"90",
                     "model-type":"timeseries",
                     "feature-list":["pdcpBytesDl","pdcpBytesUl"]
                 }
              }'

Training job creation with DME as data source
---------------------------------------------

#. AIMLFW should be installed by following steps in section :ref:`Software Installation and Deployment <reference1>`
#. RANPM setup should be installed and configured as per steps mentioned in section :ref:`Prepare Non-RT RIC DME as data source for AIMLFW <reference3>`
#. To create training job, follow the steps in the demo videos stored here: `Training Job creation <https://wiki.o-ran-sc.org/display/AIMLFEW/Files+for+I+release>`__ 
#. After training job is created and executed successfully, model can be deployed using steps mentioned in section :ref:`Deploy trained qoe prediction model on Kserve <reference4>` or 
   :ref:`Steps to deploy model using Kserve adapter <reference6>`

NOTE: Below are some example values to be used for the QoE usecase training job creation when model management service is not used.
**Note** : The QoE training function does not come pre uploaded, we need to go to training function, create training function and run the qoe-pipeline notebook.

+--------------------+-------------------------------------------------------------------+
| **Parameter**      | **Value**                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Training Job Name  | qoetest                                                           |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Model Management   |  disable                                                          |
| Service            |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Training Function  | qoe_pipeline_h_release                                            |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| FeatureGroup Name  | featuregroup1                                                     |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Datalake Source    | Influx DB                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Feature Filter     |                                                                   |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Hyper Parameters   | epochs:1                                                          |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Description        | test                                                              |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+

NOTE: Below are some example values to be used for the QoE usecase training job creation when model management service is used.

+--------------------+-------------------------------------------------------------------+
| **Parameter**      | **Value**                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Training Job Name  | qoetest                                                           |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Model Management   |  enable                                                           |
| Service            |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Model name         | qoe1                                                              |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| FeatureGroup Name  | featuregroup1                                                     |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Datalake Source    | Influx DB                                                         |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Feature Filter     |                                                                   |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Hyper Parameters   | epochs:1                                                          |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+
| Description        | test                                                              |
|                    |                                                                   |
+--------------------+-------------------------------------------------------------------+


Training job creation with standalone Influx DB as data source
--------------------------------------------------------------

#. AIMLFW should be installed by following steps in section :ref:`Software Installation and Deployment <reference1>`
#. Standalone Influx DB should be setup and configured as mentioned in section :ref:`Install Influx DB as datalake <reference2>`
#. To create training job, follow the steps in the demo videos stored here: `Training Job creation <https://wiki.o-ran-sc.org/display/AIMLFEW/Files+for+I+release>`__ 
#. After training job is created and executed successfully, model can be deployed using steps mentioned in section :ref:`Deploy trained qoe prediction model on Kserve <reference4>` or 
   :ref:`Steps to deploy model using Kserve adapter <reference6>`

NOTE: Below are some example values to be used for the QoE usecase training job creation when model management service is not used

+--------------------+-------------------------+
| **Parameter**      | **Value**               |
|                    |                         |
+--------------------+-------------------------+
| Training Job Name  | qoetest                 |
|                    |                         |
+--------------------+-------------------------+
| Model Management   | disable                 |
| Service            |                         |
+--------------------+-------------------------+
| Training Function  | qoe_pipeline_g_release  |
|                    |                         |
+--------------------+-------------------------+
| FeatureGroup Name  | featuregroup1           |
|                    |                         |
+--------------------+-------------------------+
| Datalake Source    | Influx DB               |
|                    |                         |
+--------------------+-------------------------+
| Feature Filter     |                         |
|                    |                         |
+--------------------+-------------------------+
| Hyper Parameters   | epochs:1                |
|                    |                         |
+--------------------+-------------------------+
| Description        | test                    |
|                    |                         |
+--------------------+-------------------------+

NOTE: Below are some example values to be used for the QoE usecase training job creation when model management service is used

+--------------------+-------------------------+
| **Parameter**      | **Value**               |
|                    |                         |
+--------------------+-------------------------+
| Training Job Name  | qoetest                 |
|                    |                         |
+--------------------+-------------------------+
| Model Management   | enable                  |
| Service            |                         |
+--------------------+-------------------------+
| Model Name         | qoe_pipeline_g_release  |
|                    |                         |
+--------------------+-------------------------+
| Datalake Source    | Influx DB               |
|                    |                         |
+--------------------+-------------------------+
| Feature Filter     |                         |
|                    |                         |
+--------------------+-------------------------+
| Hyper Parameters   | epochs:1                |
|                    |                         |
+--------------------+-------------------------+
| Description        | test                    |
|                    |                         |
+--------------------+-------------------------+

..  _reference5:

Obtain Model URL for deploying trained models
---------------------------------------------

URL for deployment can be obainted from AIMFW dashboard (Training Jobs-> Training Job status -> Select Info for a training job -> Model URL)
In case of using AIMLFW Model management service, URL for downloading and deploying model using Model Management Service will be the following:

.. code:: bash

        http://<VM IP where AIMLFW is deployed>:32006/downloadModel/<model name>/model.zip

Install only Kserve for deploying models
----------------------------------------

To install Kserve run the below commands

.. code:: bash

        ./bin/install_kserve.sh


Uninstall only Kserve
---------------------

To uninstall Kserve run the below commands

.. code:: bash

        ./bin/uninstall_kserve.sh
        


..  _reference4:

Deploy trained qoe prediction model on Kserve
---------------------------------------------

Create namespace using command below

.. code:: bash

        kubectl create namespace kserve-test

Create :file:`qoe.yaml` file with below contents

.. code-block:: yaml

        apiVersion: "serving.kserve.io/v1beta1"
        kind: "InferenceService"
        metadata:
          name: qoe-model
        spec:
          predictor:
            tensorflow:
              storageUri: "<update Model URL here>"
              runtimeVersion: "2.5.1"
              resources:
                requests:
                  cpu: 0.1
                  memory: 0.5Gi
                limits:
                  cpu: 0.1
                  memory: 0.5Gi


To deploy model update the Model URL in the :file:`qoe.yaml` file and execute below command to deploy model
Refer :ref:`Obtain Model URL for deploying trained models <reference5>`

.. code:: bash

        kubectl apply -f qoe.yaml -n kserve-test

Check running state of pod using below command

.. code:: bash

        kubectl get pods -n kserve-test


Test predictions using model deployed on Kserve
-----------------------------------------------

Use below command to obtain Ingress port for Kserve. 

.. code:: bash

        kubectl get svc istio-ingressgateway -n istio-system

Obtain nodeport corresponding to port 80.
In the below example, the port is 31206.

.. code::

        NAME                   TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)                                                                      AGE
        istio-ingressgateway   LoadBalancer   10.105.222.242   <pending>     15021:31423/TCP,80:31206/TCP,443:32145/TCP,31400:32338/TCP,15443:31846/TCP   4h15m


Create predict.sh file with following contents

.. code:: bash

        model_name=qoe-model
        curl -v -H "Host: $model_name.kserve-test.example.com" http://<IP of where Kserve is deployed>:<ingress port for Kserve>/v1/models/$model_name:predict -d @./input_qoe.json

Update the ``IP`` of host where Kserve is deployed and ingress port of Kserve obtained using above method.

Create sample data for predictions in file :file:`input_qoe.json`. Add the following content in :file:`input_qoe.json` file.

.. code:: bash

        {"signature_name": "serving_default", "instances": [[[2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56],
               [2.56, 2.56]]]}


Use command below to trigger predictions

.. code:: bash

        source predict.sh


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

