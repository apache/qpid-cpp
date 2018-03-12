#
# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.
#

install (FILES qpidd.1 qmf-gen.1 qpid-printevents.1 qpid-receive.1 qpid-send.1 qpid-tool.1
               qpid-config.1 qpid-ha.1 qpid-queue-stats.1 qpid-route.1 qpid-stat.1
         DESTINATION ${QPID_INSTALL_MANDIR}/man1)
