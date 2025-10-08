# ==================================================================================
#       Copyright (c) 2020 AT&T Intellectual Property.
#       Copyright (c) 2020 HCL Technologies Limited.
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
# ==================================================================================

"""
This module is temporary which aims to populate cell data into influxDB. This will be depreciated once KPIMON push cell info. into influxDB.

Modified version to accept authentication token as a command line argument.

HOW TO RUN:
-----------
python insert_with_token.py <your_influxdb_token>

Example:
--------
python insert_with_token.py "my-secret-influxdb-token-123"

The script will:
1. Read cell data from 'cell.json.gz' file
2. Process and transform the data
3. Connect to InfluxDB using the provided token
4. Write the processed data to the 'UEData' bucket under 'liveCell' measurement

Requirements:
- cell.json.gz file should be present in the same directory
- Valid InfluxDB token with write permissions
- InfluxDB server running on localhost:8086
"""
import pandas as pd
from influxdb_client import InfluxDBClient
from influxdb_client.client.write_api import SYNCHRONOUS
import datetime
import argparse


class INSERTDATA:

     def __init__(self, token):
          self.client = InfluxDBClient(url = "http://localhost:8086", token=token)


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


def populatedb(token):
     url = "https://raw.githubusercontent.com/o-ran-sc/ric-app-qp/refs/heads/f-release/qp/cell.json.gz"
     df = pd.read_json(url,compression='gzip', lines=True)
     df = df[['cellMeasReport']].dropna()
     df = jsonToTable(df)
     df = time(df)
     db = INSERTDATA(token)
     write_api = db.client.write_api(write_options=SYNCHRONOUS)
     write_api.write(bucket="UEData",record=df, data_frame_measurement_name="liveCell",org="primary")


if __name__ == "__main__":
     parser = argparse.ArgumentParser(description='Populate database with cell data using authentication token')
     parser.add_argument('token', type=str, help='Authentication token for InfluxDB')
     args = parser.parse_args()
     populatedb(args.token)