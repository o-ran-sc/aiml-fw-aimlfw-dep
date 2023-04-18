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

This document describes how to install AIMLFW, it's dependencies and required system resources.


Version history

+--------------------+--------------------+--------------------+--------------------+
| **Date**           | **Ver.**           | **Author**         | **Comment**        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
| 2022-11-30         | 0.1.0              | 		       | First draft        |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
|                    |                    |                    |                    |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+
|                    |                    |                    |                    |
|                    |                    |                    |                    |
|                    |                    |                    |                    |
+--------------------+--------------------+--------------------+--------------------+


Introduction
------------

.. <INTRODUCTION TO THE SCOPE AND INTENTION OF THIS DOCUMENT AS WELL AS TO THE SYSTEM TO BE INSTALLED>


This document describes the supported software and hardware configurations for the reference component as well as providing guidelines on how to install and configure such reference system.

The audience of this document is assumed to have good knowledge in RAN network and Linux system.


Hardware Requirements
---------------------
.. <PROVIDE A LIST OF MINIMUM HARDWARE REQUIREMENTS NEEDED FOR THE INSTALL>

Below are the minimum requirements for installing the AIMLFW

#. OS: Ubuntu 18.04 server
#. 8 cpu cores
#. 16 GB RAM
#. 60 GB harddisk

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

In case Influx DB datalake not available, it can be installed using the steps mentioned in section :ref:`install-influx-db-as-datalake`. Once installed the access details of the datalake can be updated in :file:`RECIPE_EXAMPLE/example_recipe_latest_stable.yaml`. Once updated, follow the below steps for reinstall of some components:

.. code:: bash

        bin/uninstall.sh
        bin/install.sh -f RECIPE_EXAMPLE/example_recipe_latest_stable.yaml

Following are the steps to build sample training pipeline image for QoE prediction example.
This step is required before triggering training for the QoE prediction example.

.. code:: bash

        cd /tmp/
        git clone "https://gerrit.o-ran-sc.org/r/portal/aiml-dashboard"
        docker build -f aiml-dashboard/kf-pipelines/Dockerfile.pipeline -t traininghost/pipelineimage:latest aiml-dashboard/kf-pipelines/.

Software Uninstallation
-----------------------

.. code:: bash

        bin/uninstall_traininghost.sh

.. _install-influx-db-as-datalake:

Install Influx DB as datalake
-----------------------------

.. code:: bash

        helm repo add bitnami https://charts.bitnami.com/bitnami
        helm install my-release bitnami/influxdb
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

        git clone https://gerrit.o-ran-sc.org/r/ric-app/qp
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


Install Kserve for deploying models
-----------------------------------

To install Kserve run the below commands

.. code:: bash

        ./bin/install_kserve.sh


Uninstall Kserve
----------------

To uninstall Kserve run the below commands

.. code:: bash

        ./bin/uninstall_kserve.sh
        

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
