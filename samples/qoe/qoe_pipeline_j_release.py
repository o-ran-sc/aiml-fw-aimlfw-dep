import kfp
import kfp.dsl as dsl
from kfp.dsl import InputPath, OutputPath
from kfp.dsl import component as component
from kfp import kubernetes


@component(base_image="traininghost/pipelineimage:latest")
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
    print("job name is: ", trainingjobName)
    features = fs_sdk.get_features(trainingjobName, ['pdcpBytesDl','pdcpBytesUl'])
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
    
    mm_sdk.upload_metrics(data, trainingjobName, version)
    mm_sdk.upload_model("./", trainingjobName, version)


@dsl.pipeline(
    name="qoe Pipeline",
    description="qoe",
)
def super_model_pipeline( 
    trainingjob_name: str, epochs: str, version: str):
    
    trainop=train_export_model(trainingjobName=trainingjob_name, epochs=epochs, version=version)
    trainop.set_caching_options(False)
    kubernetes.set_image_pull_policy(trainop, "IfNotPresent")


if __name__ == '__main__':
    # Compiling the pipeline
	pipeline_func = super_model_pipeline
	file_name = "qoe_model_pipeline"
	kfp.compiler.Compiler().compile(pipeline_func, file_name + '.yaml')

