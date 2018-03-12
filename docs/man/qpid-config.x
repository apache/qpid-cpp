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

qpid-config \-  QPID Broker Configuration Tool

[SYNOPSIS]

qpid-config [OPTIONS] commands

[=DESCRIPTION]

Usage:  qpid-config [OPTIONS]
        qpid-config [OPTIONS] exchanges [filter-string]
        qpid-config [OPTIONS] queues    [filter-string]
        qpid-config [OPTIONS] add exchange <type> <name> [AddExchangeOptions]
        qpid-config [OPTIONS] del exchange <name>
        qpid-config [OPTIONS] add queue <name> [AddQueueOptions]
        qpid-config [OPTIONS] del queue <name> [DelQueueOptions]
        qpid-config [OPTIONS] bind   <exchange-name> <queue-name> [binding-key]
                  <for type xml>     [-f -|filename]
                  <for type header>  [all|any] k1=v1 [, k2=v2...]
        qpid-config [OPTIONS] unbind <exchange-name> <queue-name> [binding-key]
        qpid-config [OPTIONS] reload-acl
        qpid-config [OPTIONS] add <type> <name> [--argument <property-name>=<property-value>]
        qpid-config [OPTIONS] del <type> <name>
        qpid-config [OPTIONS] list <type> [--show-property <property-name>]
        qpid-config [OPTIONS] log [<logstring>]
        qpid-config [OPTIONS] shutdown"""

[=EXAMPLES]

$ qpid-config add queue q

$ qpid-config add exchange direct d -a localhost:5672

$ qpid-config exchanges -b 10.1.1.7:10000

$ qpid-config queues -b guest/guest@broker-host:10000

Add Exchange <type> values:

    direct     Direct exchange for point-to-point communication
    fanout     Fanout exchange for broadcast communication
    topic      Topic exchange that routes messages using binding keys with wildcards
    headers    Headers exchange that matches header fields against the binding keys
    xml        XML Exchange - allows content filtering using an XQuery


Queue Limit Actions:

    none (default) - Use broker's default policy
    reject         - Reject enqueued messages
    ring           - Replace oldest unacquired message with new

Replication levels:

    none           - no replication
    configuration  - replicate queue and exchange existence and bindings, but not messages.
    all            - replicate configuration and messages

Log <logstring> value:

    Comma separated <module>:<level> pairs, e.g. 'info+,debug+:Broker,trace+:Queue'

[AUTHOR]

The Apache Qpid Project, dev@qpid.apache.org

[REPORTING BUGS]

Please report bugs to users@qpid.apache.org
