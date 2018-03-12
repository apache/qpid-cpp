#!/bin/sh
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
#
# Assumes all tools are installed
#
ver="($(qpidd --version | cut -d"(" -f2)"
#
help2man --no-info --include=qpidd.x --output=qpidd.1 --version-option="--version" qpidd
#
man_pages="qpid-tool qmf-gen qpid-config qpid-ha qpid-printevents qpid-queue-stats qpid-route qpid-stat"
for page in ${man_pages} 
do
  help2man --no-info --include=${page}.x --output=${page}.1 --version-string=" $ver" $page
done
#
man_pages="qpid-receive qpid-send"
for page in ${man_pages} 
do
  help2man --no-info --include=${page}.x --output=${page}.1 --version-string=" $ver" --no-discard-stderr $page
done

exit

