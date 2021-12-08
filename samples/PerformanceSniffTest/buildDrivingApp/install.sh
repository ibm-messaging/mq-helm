#! /bin/bash
# © Copyright IBM Corporation 2021
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

mkdir buildcontainer
cd buildcontainer
git clone https://github.com/ibm-messaging/cphtestp.git
cd cphtestp
cd ssl
cp ../../../../../genericresources/createcerts/server.kdb key.kdb
cp ../../../../../genericresources/createcerts/server.rdb key.rdb
cp ../../../../../genericresources/createcerts/server.sth key.sth
cd ..
wget https://public.dhe.ibm.com/ibmdl/export/pub/software/websphere/messaging/mqadv/mqadv_dev923_ubuntu_x86-64.tar.gz
tar -zxf mqadv_dev923_ubuntu_x86-64.tar.gz
rm mqadv_dev923_ubuntu_x86-64.tar.gz
cp -R MQServer/lap .
cp MQServer/mqlicense.sh .
cp MQServer/ibmmq-client_9.*_amd64.deb .
cp MQServer/ibmmq-gskit_9.*_amd64.deb .
cp MQServer/ibmmq-runtime_9.*_amd64.deb .
rm -rf MQServer
docker build --tag cphtestp .
