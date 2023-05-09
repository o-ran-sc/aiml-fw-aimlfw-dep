# ==================================================================================
#
#       Copyright (c) 2023 Samsung Electronics Co., Ltd. All Rights Reserved.
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

#!/usr/bin/env python
# coding: utf-8

# In[1]:


import kfp
import kfp.components as components
import kfp.dsl as dsl
from kfp.components import InputPath, OutputPath


# In[2]:


def train_export_model(trainingjobName: str, epochs: str, version: str):
    
    import tensorflow as tf
    from numpy import array
    from tensorflow.keras.models import Sequential
    from tensorflow.keras.layers import Dense
    from tensorflow.keras.layers import Flatten, Dropout, Activation
    from tensorflow.keras.layers import LSTM
    import numpy as np
    print("numpy version")
    print(np.__version__)
    import pandas as pd
    import os
    from featurestoresdk.feature_store_sdk import FeatureStoreSdk
    from modelmetricsdk.model_metrics_sdk import ModelMetricsSdk
    
    fs_sdk = FeatureStoreSdk()
    mm_sdk = ModelMetricsSdk()
    
    features = fs_sdk.get_features(trainingjobName, ['measTimeStampRf', 'nrCellIdentity', 'pdcpBytesDl','pdcpBytesUl'])
    print("Dataframe:")
    print(features)

    features_cellc2b2 = features[features['nrCellIdentity'] == "c2/B2"]
    print("Dataframe for cell : c2/B2")
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
    
    mm_sdk.upload_metrics(data, trainingjobName, version)
    mm_sdk.upload_model("./", trainingjobName, version)


# In[3]:


BASE_IMAGE = "traininghost/pipelineimage:latest"


# In[4]:


def train_and_export(trainingjobName: str, epochs: str, version: str):
    trainOp = components.func_to_container_op(train_export_model, base_image=BASE_IMAGE)(trainingjobName, epochs,version)
    # Below line to disable caching of pipeline step
    trainOp.execution_options.caching_strategy.max_cache_staleness = "P0D"
    trainOp.container.set_image_pull_policy("IfNotPresent")


# In[5]:


@dsl.pipeline(
    name="qoe Pipeline",
    description="qoe",
)
def super_model_pipeline( 
    trainingjob_name: str, epochs: str, version: str):
    
    train_and_export(trainingjob_name, epochs, version)


# In[6]:

# In[7]:


#import requests
#pipeline_name="qoe Pipeline"
#pipeline_file = file_name+'.zip'
#requests.post("http://tm.traininghost:32002/pipelines/{}/upload".format(pipeline_name), files={'file':open(pipeline_file,'rb')})


if __name__ == '__main__':
    # Compiling the pipeline
	pipeline_func = super_model_pipeline
	file_name = "qoe_model_pipeline"
	kfp.compiler.Compiler().compile(pipeline_func, file_name + '.yaml')

# In[ ]:





# In[ ]:




