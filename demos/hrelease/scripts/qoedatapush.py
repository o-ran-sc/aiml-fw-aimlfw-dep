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



from xml.dom import minidom, Node
import pandas as pd
import os  
import datetime
import subprocess
import gzip
import sys

#Function to create pm file based on qoe data file
def create_xml_document(measurement_list, row, dir_name, sourcename,index):

    time = row['measTimeStampRf']
    du = str(row['du-id'])
    cell = row['nrCellIdentity'].replace('/','_')
    print(time,du,cell)
    doc = minidom.Document()

    measCollecFile = doc.createElement('measCollecFile')
    measCollecFile.setAttribute("xmlns","http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec")
    measCollecFile.setAttribute("xmlns:xsi","http://www.w3.org/2001/XMLSchema-instance")
    measCollecFile.setAttribute("xsi:schemaLocation","http://www.3gpp.org/ftp/specs/archive/32_series/32.435#measCollec")
    doc.appendChild(measCollecFile)

    pi = doc.createProcessingInstruction('xml-stylesheet',
                                         'type="text/xsl" href="MeasDataCollection.xsl"')
    root = doc.firstChild
    doc.insertBefore(pi, root)

    fileHeader = doc.createElement('fileHeader')
    fileHeader.setAttribute('fileFormatVersion',"32.435 V10.0")
    fileHeader.setAttribute('vendorName',"vendor A")
    fileHeader.setAttribute('dnPrefix',"SubNetwork=XX")
    measCollecFile.appendChild(fileHeader)


    fileSender = doc.createElement('fileSender')
    fileSender.setAttribute('localDn',"test")
    fileSender.setAttribute('elementType',"RadioNode")
    fileHeader.appendChild(fileSender)

    measCollec = doc.createElement('measCollec')
    measCollec.setAttribute('beginTime',time)
    fileHeader.appendChild(measCollec)

    measData = doc.createElement('measData')
    measCollecFile.appendChild(measData)


    managedElement = doc.createElement('managedElement')
    managedElement.setAttribute('localDn',"test")
    managedElement.setAttribute('swVersion',"testversion")
    measData.appendChild(managedElement)


    measInfo = doc.createElement('measInfo')
    measInfo.setAttribute('measInfoId',"PM=1,PmGroup=NRCellDU_GNBDU")
    measData.appendChild(measInfo)


    job = doc.createElement('job')
    job.setAttribute('jobId',"nr_all")
    measInfo.appendChild(job)

    granPeriod = doc.createElement('granPeriod')
    granPeriod.setAttribute('duration',"PT900S")
    granPeriod.setAttribute('endTime',time)
    measInfo.appendChild(granPeriod)

    repPeriod = doc.createElement('repPeriod')
    repPeriod.setAttribute('duration',"PT900S")
    measInfo.appendChild(repPeriod)

    measurement_index = 1
    for column in row.index:
        if column in measurement_list:
            measType = doc.createElement('measType')
            measType.setAttribute('p',str(measurement_index))
            measTypeValue = doc.createTextNode(column)
            measType.appendChild(measTypeValue)
            measInfo.appendChild(measType)

            measurement_index = measurement_index + 1

    measValue = doc.createElement('measValue')
    measValue.setAttribute('measObjLdn',"ManagedElement=nodedntest,GNBDUFunction="+ du +",NRCellDU="+ cell)
    measInfo.appendChild(measValue)

    measurement_index = 1
    for column in row.index:
        if column in measurement_list:
            r = doc.createElement('r')
            r.setAttribute('p',str(measurement_index))
            measTypeValue = doc.createTextNode(str(row[column]))
            r.appendChild(measTypeValue)
            measValue.appendChild(r)

            measurement_index = measurement_index + 1
    
    xmlstr = doc.toprettyxml(encoding="utf-8")
    
    format_string = "%Y-%m-%dT%H:%M:%S.%f"
    date_string = time
    datetimestart = datetime.datetime.strptime(date_string, format_string)
    datetimeend = datetimestart + datetime.timedelta(milliseconds=10)
    

    datetime_start_formatted = datetimestart.strftime("%Y%m%d.%H%M")
    datetime_end_formatted = datetimeend.strftime("%H%M")
    secondsfiltered = datetimestart.strftime("%S%f")[:-3]

    filename = dir_name + "/" "A" + datetime_start_formatted + "+0200"+ "-" + datetime_end_formatted + "+0200"+ "_"+ sourcename + "_" + du +"_"+ cell+"_"+ secondsfiltered +".xml"

    with open(filename, "wb") as f:
        f.write(xmlstr)

    #Fix to increment timestamp in seconds
    datetimestart_in_epoch = int(datetimestart.timestamp()*1000 * 1000) + (index *1000 * 1000)
    datetimeend_in_epoch = int(datetimeend.timestamp()*1000 * 1000) + (index *1000 * 1000)
    
    print(datetimeend_in_epoch)
    filename_gz = filename + '.gz'
    f_in = open(filename, 'rb')
    f_out = gzip.open(filename_gz, 'wb')
    f_out.writelines(f_in)
    f_out.close()
    f_in.close()
    return datetimestart_in_epoch,datetimeend_in_epoch,filename_gz

#Function to copy generated files to http_server    
def copy_files_http_server(filename_gz):
    copy_command = ["kubectl", "cp", filename_gz ,"ran/pm-https-server-0:/files", "-c", "pm-https-server"]
    print(subprocess.run(copy_command, capture_output=True))

#Function to push file ready event for each row
def push_file_ready_event(sourcename, filename_gz, datetimestart_in_epoch, datetimeend_in_epoch):
    push_file_ready_event_command = ["./push-to-file-ready-topic-qoe.sh",sourcename,filename_gz,str(datetimestart_in_epoch),str(datetimeend_in_epoch)]
    print(subprocess.run(push_file_ready_event_command, capture_output=True))

#Read input data csv file
if (len(sys.argv) < 4):
    sys.exit('Give all input parameters, e.g. python3 qoedatapush.py <source name> <max number of rows to take from csv> <cell Identity to be filtered>')
dir_name='files'
sourcename = sys.argv[1]
max_rows= int(sys.argv[2])
print('max_rows: ',max_rows)
filtered_cell = sys.argv[3]
print('filtered_cell:',filtered_cell)
if not os.path.exists(dir_name):
    os.makedirs(dir_name)

measurement_list = ['throughput','x','y','availPrbDl','availPrbUl','measPeriodPrb','pdcpBytesUl','pdcpBytesDl','measPeriodPdcpBytes']
df = pd.read_csv('qoedata.csv')
df_selected = df
df_selected = df_selected[df_selected['nrCellIdentity'] == filtered_cell]
df_selected = df_selected.head(max_rows)
print(df_selected.size)
for index,row in df_selected.iterrows():
    datetimestart_in_epoch,datetimeend_in_epoch,filename_gz = create_xml_document(measurement_list, row, dir_name, sourcename, index)
    filename_wo_dir_gz = filename_gz.replace(dir_name+'/','')
    copy_files_http_server(filename_gz)
    push_file_ready_event(sourcename, filename_wo_dir_gz, datetimestart_in_epoch, datetimeend_in_epoch)
