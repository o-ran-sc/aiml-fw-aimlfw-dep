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

import kfp
import kfp.dsl as dsl
from kfp.dsl import InputPath, OutputPath
from kfp.dsl import component as component
from kfp import kubernetes

BASE_IMAGE = "traininghost/pipelineimage:latest"

@component(base_image=BASE_IMAGE,packages_to_install=['requests'])
def train_export_model(featurepath: str, epochs: str, modelname: str, modelversion:str):
    
    import re
    import tensorflow as tf
    from numpy import array
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import Dense
    from tensorflow.keras.layers import Flatten, Dropout, Activation
    from tensorflow.keras.layers import LSTM
    import numpy as np
    import requests
    import zipfile
    print("numpy version")
    print(np.__version__)
    import pandas as pd
    import os
    from featurestoresdk.feature_store_sdk import FeatureStoreSdk
    from modelmetricsdk.model_metrics_sdk import ModelMetricsSdk
    
    fs_sdk = FeatureStoreSdk()
    mm_sdk = ModelMetricsSdk()
    print("featurepath is: ", featurepath)
    features = fs_sdk.get_features(featurepath, ['pdcpBytesDl','pdcpBytesUl'])
    print("Dataframe:")
    print(features)

    features_cellc2b2 = features
    print(features_cellc2b2)
    print('Previous Data Types are --> ', features_cellc2b2.dtypes)
    features_cellc2b2["pdcpBytesDl"] = pd.to_numeric(features_cellc2b2["pdcpBytesDl"], downcast="float")
    features_cellc2b2["pdcpBytesUl"] = pd.to_numeric(features_cellc2b2["pdcpBytesUl"], downcast="float")
    print('New Data Types are --> ', features_cellc2b2.dtypes)
    
    features_cellc2b2 = features_cellc2b2[['pdcpBytesDl', 'pdcpBytesUl']]
    
    def split_series(series, n_past, n_future):
        X, y = list(), list()
        for window_start in range(len(series)):
            past_end = window_start + n_past
            future_end = past_end + n_future
            if future_end > len(series):
                break
            # slicing the past and future parts of the window
            past, future = series[window_start:past_end, :], series[past_end:future_end, :]
            X.append(past)
            y.append(future)
        return np.array(X), np.array(y)
    X, y = split_series(features_cellc2b2.values,10, 1)
    X = X.reshape((X.shape[0], X.shape[1],X.shape[2]))
    y = y.reshape((y.shape[0], y.shape[2]))
    print(X.shape)
    print(y.shape)
 
    print("Loading the saved model")
    print(os.listdir(os.getcwd()))
    

    url = f"http://modelmgmtservice.traininghost:8082/ai-ml-model-discovery/v1/models/?model-name={modelname}&model-version={modelversion}"
    modelinfo =  requests.get(url).json()[0]
    artifactversion = modelinfo["modelId"]["artifactVersion"]
    model_url = ""
    if modelinfo["modelLocation"] != "":
        model_url= modelinfo["modelLocation"]
    else :
        model_url = f"http://tm.traininghost:32002/model/{modelname}/{modelversion}/{artifactversion}/Model.zip"
    # Download the model zip file

    print(f"Downloading model from :{model_url}")
    response = requests.get(model_url)

    print("Response generated: " + str(response))

    # Check if the request was successful
    if response.status_code == 200:
        local_file_path = 'Model.zip'
        with open(local_file_path, 'wb') as file:
            file.write(response.content)
        print(f'Downloaded file saved to {local_file_path}')
    else:
        print('Failed to download the file')

    print(os.listdir(os.getcwd()))

    # Extract the zip file
    zip_file_path = "./Model.zip"
    extract_to_dir = "./Model"

    if not os.path.exists(extract_to_dir):
        os.makedirs(extract_to_dir)

    with zipfile.ZipFile(zip_file_path, 'r') as zip_ref:
        zip_ref.extractall(extract_to_dir)

    # Delete the zip file after extraction
    if os.path.exists(zip_file_path):
        os.remove(zip_file_path)
        print(f'Deleted zip file: {zip_file_path}')
    else:
        print(f'Zip file not found: {zip_file_path}')

    # Path to the directory containing the saved model
    model_path = f"./Model/{modelversion}"

    # Load the model in SavedModel format     
    model = tf.keras.models.load_model(model_path)
    
    model.compile(loss='mse', optimizer='adam', metrics=['mse'])
    model.summary()

    # Define a directory to save checkpoints
    checkpoint_dir = "./checkpoints"
    if not os.path.exists(checkpoint_dir):
        os.makedirs(checkpoint_dir)

    # Define a ModelCheckpoint callback
    checkpoint_path = os.path.join(checkpoint_dir, "model_epoch_{epoch:02d}_val_loss_{val_loss:.2f}.h5")
    checkpoint_callback = tf.keras.callbacks.ModelCheckpoint(
        filepath=checkpoint_path,   # Save checkpoint file path, this file is not saved finaly
        monitor='val_loss',         # Monitor validation loss, can be train loss also 
        save_best_only=True,        # Save only the best model based on validation loss
        save_weights_only=False,    # Save the entire model, not just weights
        mode='min',                 # Minimizing the validation loss
        verbose=0                   # set to 1 if want to print info when a new checkpoint is saved
    )

    # Train the model with checkpointing
    print("Retraining the model with checkpoints...")
    history = model.fit(
        X, 
        y, 
        batch_size=10, 
        epochs=int(epochs), 
        validation_split=0.2, 
        callbacks=[checkpoint_callback]  # Add the callback here
    )
    
    yhat = model.predict(X, verbose = 0)
    xx = y
    yy = yhat
    
    retrained_model_path = "./retrain"
    if not os.path.exists(retrained_model_path):
        os.makedirs(retrained_model_path)

    # Save the retrained model
    model.save(retrained_model_path)
    print(f"Retrained model saved at {retrained_model_path}")

    import json
    data = {}
    data['metrics'] = []
    data['metrics'].append({'Accuracy': str(np.mean(np.absolute(np.asarray(xx)-np.asarray(yy))<5))})

# update artifact version
    new_artifactversion =""
    if modelinfo["modelLocation"] != "":
        new_artifactversion = "1.1.0"
    else:
        major, minor , patch= map(int, artifactversion.split('.'))
        minor+=1
        new_artifactversion = f"{major}.{minor}.{patch}"
    
    # update the new artifact version in mme
    url = f"http://modelmgmtservice.traininghost:8082/ai-ml-model-registration/v1/model-registrations/updateArtifact/{modelname}/{modelversion}/{new_artifactversion}"
    updated_model_info= requests.post(url).json()
    print(updated_model_info)
    
    mm_sdk.upload_metrics(data, modelname, modelversion,new_artifactversion)
    mm_sdk.upload_model("./retrain/", modelname, modelversion, new_artifactversion)

@dsl.pipeline(
    name="qoe Pipeline",
    description="qoe",
)
def super_model_pipeline( 
    featurepath: str, epochs: str, modelname: str, modelversion:str):
    
    trainop=train_export_model(featurepath=featurepath, epochs=epochs, modelname=modelname, modelversion=modelversion)
    trainop.set_caching_options(False)
    kubernetes.set_image_pull_policy(trainop, "IfNotPresent")

pipeline_func = super_model_pipeline
file_name = "qoe_model_pipeline_retrain"

kfp.compiler.Compiler().compile(pipeline_func,  
  '{}.yaml'.format(file_name))

import requests
pipeline_name="qoe_Pipeline_retrain"
pipeline_file = file_name+'.yaml'
requests.post("http://tm.traininghost:32002/pipelines/{}/upload".format(pipeline_name), files={'file':open(pipeline_file,'rb')})