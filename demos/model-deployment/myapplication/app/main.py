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
import simplejson as json
import os
import requests
import time

KSERVE_HOST = os.environ['KSERVE_HOST']
MODEL_NAME = os.environ['MODEL_NAME']
PREDICTION_URL = f"{KSERVE_HOST}/v1/models/{MODEL_NAME}:predict"

def predict_single_at_time(model_input : list):
    '''
        model_input must be list
    '''
    headers = {
        "Content-Type": "application/json"
    }
    
    data = {
        "signature_name": "serving_default",
        "instances" : [model_input]
    }
    response = requests.post(PREDICTION_URL, headers=headers, json=data)
    if response.status_code != 200:
        print("Error| Status-code is not 200| ", response.text)
        return -1
    predictions = json.loads(response.text)
    
    # Since we predicting for single dataPoint
    return predictions['predictions'][0]

def make_requests():
    data = [[2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56],
            [2.56, 2.56]]
    print("Input-data : ", data)
    while True:
        try:
            predicted = predict_single_at_time(data)
            print(f"Predicted-Values : {predicted}")
            print("--------------------------------------------------------")
            time.sleep(5)
        except Exception as err:
            print("Recieved Error while make prediction requests | Error : ", err)
            # Keep-trying after 5 seconds
            time.sleep(5)
            
            
if __name__ == '__main__':
    make_requests()
    
    