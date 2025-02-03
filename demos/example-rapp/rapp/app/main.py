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
from flask import Flask, request, jsonify


app = Flask(__name__)

@app.route('/callback', methods=['POST'])
def test_endpoint():
    data = request.json
    print("Recieved Data --> ", data)
    return jsonify({"message": "Data received", "data": data}), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8005)