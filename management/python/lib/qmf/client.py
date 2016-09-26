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
# under the License
#

"""
AMQP 1.0 QMF client for the Qpid C++ broker.

This client is based on the Qpid-Proton library which only supports AMQP 1.0, it
is intended for forward-looking projects that want to move to the newer client
libraries. One important feature is that it does not start background threads,
which makes it more suitable for environments that may fork.
"""

from proton import Message
from proton.utils import BlockingConnection, IncomingMessageHandler
import threading, struct

class SyncRequestResponse(IncomingMessageHandler):
    """
    Implementation of the synchronous request-responce (aka RPC) pattern.
    @ivar address: Address for all requests, may be None.
    @ivar connection: Connection for requests and responses.
    """

    def __init__(self, connection, address=None):
        """
        Send requests and receive responses. A single instance can send many requests
        to the same or different addresses.

        @param connection: A L{BlockingConnection}
        @param address: Address for all requests.
            If not specified, each request must have the address property set.
            Sucessive messages may have different addresses.
        """
        super(SyncRequestResponse, self).__init__()
        self.connection = connection
        self.address = address
        self.sender = self.connection.create_sender(self.address)
        # dynamic=true generates a unique address dynamically for this receiver.
        # credit=1 because we want to receive 1 response message initially.
        self.receiver = self.connection.create_receiver(None, dynamic=True, credit=1, handler=self)
        self.response = None
        self._cid = 0
        self.lock = threading.Lock()

    def _next(self):
        """Get the next correlation ID"""
        self.lock.acquire()
        try:
            self._cid += 1;
            return struct.pack("L", self._cid)
        finally:
            self.lock.release()

    def call(self, request):
        """
        Send a request message, wait for and return the response message.

        @param request: A L{proton.Message}. If L{self.address} is not set the 
            L{self.address} must be set and will be used.
        """
        return self.wait(self.send(request))

    def send(self, request):
        """
        Send a request and return the correlation_id immediately. Use wait() to get the response.
        @param request: A L{proton.Message}. If L{self.address} is not set the 
            L{self.address} must be set and will be used.
        """
        if not self.address and not request.address:
            raise ValueError("Request message has no address: %s" % request)
        request.reply_to = self.reply_to
        request.correlation_id = self._next()
        self.sender.send(request)
        return request.correlation_id

    def wait(self, correlation_id):
        """Wait for and return a single response to a request previously sent with send()"""
        def wakeup():
            return self.response and (self.response.correlation_id == correlation_id)
        self.connection.wait(wakeup, msg="Waiting for response")
        response = self.response
        self.response = None    # Ready for next response.
        self.receiver.flow(1)   # Set up credit for the next response.
        return response

    @property
    def reply_to(self):
        """Return the dynamic address of our receiver."""
        return self.receiver.remote_source.address

    def on_message(self, event):
        """Called when we receive a message for our receiver."""
        self.response = event.message
        self.connection.container.yield_() # Wake up the wait() loop to handle the message.

class BrokerAgent(object):
    """Proxy for a manageable Qpid broker"""

    @staticmethod
    def connection(url=None, timeout=10, ssl_domain=None, sasl=None):
        """Return a BlockingConnection suitable for use with a BrokerAgent."""
        return BlockingConnection(url,
                                  timeout=timeout,
                                  ssl_domain=ssl_domain,
                                  allowed_mechs=str(sasl.mechs) if sasl else None,
                                  user=str(sasl.user) if sasl else None,
                                  password=str(sasl.password) if sasl else None)

    @staticmethod
    def connect(url=None, timeout=10, ssl_domain=None, sasl=None):
        """Return a BrokerAgent connected with the given parameters"""
        return BrokerAgent(BrokerAgent.connection(url, timeout, ssl_domain, sasl))

    def __init__(self, connection):
        """
        Create a management node proxy using the given connection.
        @param locales: Default list of locales for management operations.
        @param connection: a L{BlockingConnection} to the management agent.
        """
        path = connection.url.path or "qmf.default.direct"
        self._client = SyncRequestResponse(connection, path)

    def close(self):
        """Shut down the node"""
        if self._client:
            self._client.connection.close()
            self._client = None

    def __repr__(self):
        return "%s(%s)"%(self.__class__.__name__, self._client.connection.url)

    def _request(self, opcode, content):
        props = {'method'             : 'request',
                 'qmf.opcode'         : opcode,
                 'x-amqp-0-10.app-id' : 'qmf2'}
        return self._client.call(Message(body=content, properties=props, subject="broker"))

    def _method(self, method, arguments=None, addr="org.apache.qpid.broker:broker:amqp-broker"):
        """
        Make a L{proton.Message} containining a QMF method request.
        """
        content = {'_object_id'   : {'_object_name' : addr},
                   '_method_name' : method,
                   '_arguments'   : arguments or {}}
        response = self._request('_method_request', content)
        if response.properties['qmf.opcode'] == '_exception':
            raise Exception("management error: %r" % response.body['_values'])
        if response.properties['qmf.opcode'] != '_method_response':
            raise Exception("bad response: %r" % response.properties)
        return response.body['_arguments']

    def _gather(self, response):
        items = response.body
        while 'partial' in response.properties:
            response = self._client.wait()
            items += self._client.wait(response.correlation_id).body
        return items

    def _classQuery(self, class_name):
        query = {'_what' : 'OBJECT', '_schema_id' : {'_class_name' : class_name}}
        response = self._request('_query_request', query)
        if response.properties['qmf.opcode'] != '_query_response':
            raise Exception("bad response")
        return self._gather(response)

    def _nameQuery(self, object_id):
        query = {'_what'      : 'OBJECT', '_object_id' : {'_object_name' : object_id}}
        response = self._request('_query_request', query)
        if response.properties['qmf.opcode'] != '_query_response':
            raise Exception("bad response")
        items = self._gather(response)
        if len(items) == 1:
            return items[0]
        return None

    def _getAll(self, cls):
        return [cls(self, x) for x in self._classQuery(cls.__name__.lower())]

    def _getSingle(self, cls):
        l = self._getAll(cls)
        return l and l[0]

    def _get(self, cls, oid):
        x = self._nameQuery(oid)
        return x and cls(self, x)

    def getBroker(self): return self._getSingle(Broker)
    def getCluster(self): return self._getSingle(Cluster)
    def getHaBroker(self): return self._getSingle(HaBroker)
    def getAllConnections(self): return self._getAll(Connection)
    def getConnection(self, oid): return self._get(Connection, "org.apache.qpid.broker:connection:%s" % oid)
    def getAllSessions(self): return self._getAll(Session)
    def getSession(self, oid): return self._get(Session, "org.apache.qpid.broker:session:%s" % oid)
    def getAllSubscriptions(self): return self._getAll(Subscription)
    def getSubscription(self, oid): return self._get(Subscription, "org.apache.qpid.broker:subscription:%s" % oid)
    def getAllExchanges(self): return self._getAll(Exchange)
    def getExchange(self, name): return self._get(Exchange, "org.apache.qpid.broker:exchange:%s" % name)
    def getAllQueues(self): return self._getAll(Queue)
    def getQueue(self, name): return self._get(Queue, "org.apache.qpid.broker:queue:%s" % name)
    def getAllBindings(self): return self._getAll(Binding)
    def getAllLinks(self): return self._getAll(Link)
    def getAcl(self): return self._getSingle(Acl)
    def getMemory(self): return self._getSingle(Memory)

    def echo(self, sequence = 1, body = "Body"):
      """Request a response to test the path to the management broker"""
      return self._method('echo', {'sequence' : sequence, 'body' : body})

    def queueMoveMessages(self, srcQueue, destQueue, qty):
        """Move messages from one queue to another"""
        self._method("queueMoveMessages", {'srcQueue':srcQueue,'destQueue':destQueue,'qty':qty})

    def queueRedirect(self, sourceQueue, targetQueue):
        """Enable/disable delivery redirect for indicated queues"""
        self._method("queueRedirect", {'sourceQueue':sourceQueue,'targetQueue':targetQueue})

    def setLogLevel(self, level):
        """Set the log level"""
        self._method("setLogLevel", {'level':level})

    def getLogLevel(self):
        """Get the log level"""
        return self._method('getLogLevel')

    def setTimestampConfig(self, receive):
        """Set the message timestamping configuration"""
        self._method("setTimestampConfig", {'receive':receive})

    def getTimestampConfig(self):
        """Get the message timestamping configuration"""
        return self._method('getTimestampConfig')

    def setLogHiresTimestamp(self, logHires):
        """Set the high resolution timestamp in logs"""
        self._method("setLogHiresTimestamp", {'logHires':logHires})

    def getLogHiresTimestamp(self):
        """Get the high resolution timestamp in logs"""
        return self._method('getLogHiresTimestamp')

    def addExchange(self, exchange_type, name, options={}, **kwargs):
        properties = {}
        properties['exchange-type'] = exchange_type
        for k,v in options.items():
            properties[k] = v
        for k,v in kwargs.items():
            properties[k] = v
        args = {'type':       'exchange',
                'name':        name,
                'properties':  properties,
                'strict':      True}
        self._method('create', args)

    def delExchange(self, name):
        args = {'type': 'exchange', 'name': name}
        self._method('delete', args)

    def addQueue(self, name, options={}, **kwargs):
        properties = options
        for k,v in kwargs.items():
            properties[k] = v
        args = {'type':       'queue',
                'name':        name,
                'properties':  properties,
                'strict':      True}
        self._method('create', args)

    def delQueue(self, name, if_empty=True, if_unused=True):
        options = {'if_empty':  if_empty,
                   'if_unused': if_unused}
        args = {'type':        'queue', 
                'name':         name,
                'options':      options}
        self._method('delete', args)

    def bind(self, exchange, queue, key="", options={}, **kwargs):
        properties = options
        for k,v in kwargs.items():
            properties[k] = v
        args = {'type':       'binding',
                'name':       "%s/%s/%s" % (exchange, queue, key),
                'properties':  properties,
                'strict':      True}
        self._method('create', args)

    def unbind(self, exchange, queue, key, **kwargs):
        args = {'type':       'binding',
                'name':       "%s/%s/%s" % (exchange, queue, key),
                'strict':      True}
        self._method('delete', args)

    def reloadAclFile(self):
        self._method('reloadACLFile', {}, "org.apache.qpid.acl:acl:org.apache.qpid.broker:broker:amqp-broker")

    def acl_lookup(self, userName, action, aclObj, aclObjName, propMap):
        args = {'userId':      userName,
                'action':      action,
                'object':      aclObj,
                'objectName':  aclObjName,
                'propertyMap': propMap}
        return self._method('Lookup', args, "org.apache.qpid.acl:acl:org.apache.qpid.broker:broker:amqp-broker")

    def acl_lookupPublish(self, userName, exchange, key):
        args = {'userId':       userName,
                'exchangeName': exchange,
                'routingKey':   key}
        return self._method('LookupPublish', args, "org.apache.qpid.acl:acl:org.apache.qpid.broker:broker:amqp-broker")

    def Redirect(self, sourceQueue, targetQueue):
        args = {'sourceQueue': sourceQueue,
                'targetQueue': targetQueue}
        return self._method('queueRedirect', args, "org.apache.qpid.broker:broker:amqp-broker")

    def create(self, _type, name, properties={}, strict=False):
        """Create an object of the specified type"""
        args = {'type': _type,
                'name': name,
                'properties': properties,
                'strict': strict}
        return self._method('create', args)

    def delete(self, _type, name, options):
        """Delete an object of the specified type"""
        args = {'type': _type,
                'name': name,
                'options': options}
        return self._method('delete', args)

    def list(self, _type):
        """List objects of the specified type"""
        return [i["_values"] for i in self._doClassQuery(_type.lower())]

    def query(self, _type, oid):
        """Query the current state of an object"""
        return self._get(self, _type, oid)


class BrokerObject(object):
    def __init__(self, broker, content):
        self.broker = broker
        self.content = content

    @property
    def values(self):
        return self.content['_values']

    def __getattr__(self, key):
        return self.values.get(key)

    def getObjectId(self):
        return self.content['_object_id']['_object_name']

    def getAttributes(self):
        return self.values

    def getCreateTime(self):
        return self.content['_create_ts']

    def getDeleteTime(self):
        return self.content['_delete_ts']

    def getUpdateTime(self):
        return self.content['_update_ts']

    def update(self):
        """
        Reload the property values from the agent.
        """
        refreshed = self.broker._get(self.__class__, self.getObjectId())
        if refreshed:
            self.content = refreshed.content
            self.values = self.content['_values']
        else:
            raise Exception("No longer exists on the broker")

    def __repr__(self):
        return "%s(%s)"%(self.__class__.__name__, self.content)

    def __str__(self):
        return self.getObjectId()


class Broker(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Cluster(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class HaBroker(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Memory(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Connection(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

    def close(self):
        self.broker._method("close", {}, "org.apache.qpid.broker:connection:%s" % self.address)

class Session(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Subscription(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Exchange(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Binding(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Queue(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

    def purge(self, request):
        """Discard all or some messages on a queue"""
        self.broker._method("purge", {'request':request}, "org.apache.qpid.broker:queue:%s" % self.name)

    def reroute(self, request, useAltExchange, exchange, filter={}):
        """Remove all or some messages on this queue and route them to an exchange"""
        self.broker._method("reroute", {'request':request,'useAltExchange':useAltExchange,'exchange':exchange,'filter':filter},
                          "org.apache.qpid.broker:queue:%s" % self.name)

class Link(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

class Acl(BrokerObject):
    def __init__(self, broker, values):
        BrokerObject.__init__(self, broker, values)

