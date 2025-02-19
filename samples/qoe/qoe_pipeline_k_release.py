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

@component(base_image=BASE_IMAGE)
def train_export_model(featurepath: str, epochs: str, modelname: str, modelversion:str):
    
    import tensorflow as tf
    from numpy import array
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import Dense
    from tensorflow.keras.layers import Flatten, Dropout, Activation
    from tensorflow.keras.layers import LSTM
    import numpy as np
    import requests
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
    
    model = Sequential()
    model.add(LSTM(units = 150, activation="tanh" ,return_sequences = True, input_shape = (X.shape[1], X.shape[2])))

    model.add(LSTM(units = 150, return_sequences = True,activation="tanh"))

    model.add(LSTM(units = 150,return_sequences = False,activation="tanh" ))

    model.add((Dense(units = X.shape[2])))
    
    model.compile(loss='mse', optimizer='adam',metrics=['mse'])
    model.summary()
    
    model.fit(X, y, batch_size=10,epochs=int(epochs), validation_split=0.2)
    yhat = model.predict(X, verbose = 0)

    
    xx = y
    yy = yhat
    model.save("./")
    import json
    data = {}
    data['metrics'] = []
    data['metrics'].append({'Accuracy': str(np.mean(np.absolute(np.asarray(xx)-np.asarray(yy))<5))})
    
#     as new artifact after training will always be 1.0.0
    artifactversion="1.0.0"
    url = f"http://modelmgmtservice.traininghost:8082/ai-ml-model-registration/v1/model-registrations/updateArtifact/{modelname}/{modelversion}/{artifactversion}"
    updated_model_info= requests.post(url).json()
    print(updated_model_info)
    
    mm_sdk.upload_metrics(data, modelname, modelversion,artifactversion)
    mm_sdk.upload_model("./", modelname, modelversion, artifactversion)

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
file_name = "qoe_model_pipeline"

kfp.compiler.Compiler().compile(pipeline_func,  
  '{}.yaml'.format(file_name))

import requests
pipeline_name="qoe_Pipeline"
pipeline_file = file_name+'.yaml'
requests.post("http://tm.traininghost:32002/pipelines/{}/upload".format(pipeline_name), files={'file':open(pipeline_file,'rb')})