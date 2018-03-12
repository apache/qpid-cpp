.\"
.\" Licensed to the Apache Software Foundation (ASF) under one
.\" or more contributor license agreements.  See the NOTICE file
.\" distributed with this work for additional information
.\" regarding copyright ownership.  The ASF licenses this file
.\" to you under the Apache License, Version 2.0 (the
.\" "License"); you may not use this file except in compliance
.\" with the License.  You may obtain a copy of the License at
.\"
.\"   http://www.apache.org/licenses/LICENSE-2.0
.\"
.\" Unless required by applicable law or agreed to in writing,
.\" software distributed under the License is distributed on an
.\" "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
.\" KIND, either express or implied.  See the License for the
.\" specific language governing permissions and limitations
.\" under the License.
.\"

[NAME]

qpid-stat \- Show QPID Broker Stats

[SYNOPSIS]

qpid-stat <commands> [OPTIONS]

[=DESCRIPTION]

Shows general broker stats, connections, exchanges, queues, 
subsriptions, access control list stats and broker memory stats. 

Usage: qpid-stat -g [options]
       qpid-stat -c [options]
       qpid-stat -e [options]
       qpid-stat -q [options] [queue-name]
       qpid-stat -u [options]
       qpid-stat -m [options]
       qpid-stat --acl [options]

[AUTHOR]

The Apache Qpid Project, dev@qpid.apache.org

[REPORTING BUGS]

Please report bugs to users@qpid.apache.org
