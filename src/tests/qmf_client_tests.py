#!/usr/bin/env python
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

# Runs QMF tests using the qmf.client API.


import unittest, os, socket, time
from qmf.client import SyncRequestResponse, BrokerAgent, ReconnectDelays
from proton.handlers import MessagingHandler
from proton.reactor import Container
from proton.utils import BlockingConnection, ConnectionException
from proton import Message, Event
from threading import Thread
from Queue import Queue, Empty, Full

class TestPort(object):
    """Get an unused port using bind(0) and SO_REUSEADDR and hold it till close()
    Can be used as `with TestPort() as tp:` Provides tp.host, tp.port and tp.addr
    (a "host:port" string)
    """
    def __init__(self):
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.sock.bind(('127.0.0.1', 0)) # Testing exampless is local only
        self.host, self.port = socket.getnameinfo(self.sock.getsockname(), 0)
        self.addr = "%s:%s" % (self.host, self.port)

    def __enter__(self):
        return self

    def __exit__(self, *args):
        self.close()

    def close(self):
        self.sock.close()


class QmfClientTest(unittest.TestCase):
    """
    Test QMFv2 support using the qmf.console library.
    """

    def configure(self, config):
        """Called by the qpid-python-test framework with broker config"""
        self.broker = config.broker

    def setUp(self):
        self.agent = BrokerAgent.connect(self.broker)

    def test_broker(self):
        self.assertEqual(self.agent.getBroker().name, "amqp-broker")

    def test_connections(self):
        connections = self.agent.getAllConnections()
        self.assertTrue(len(connections) > 0)

    def test_queues(self):
        connections = self.agent.getAllConnections()
        qnames = [ "qq%s"%i for i in xrange(10)]
        for q in qnames:
            self.agent.addQueue(q)
            self.assertEqual(q, self.agent.getQueue(q).name)
        queues = self.agent.getAllQueues()
        self.assertLess(set(qnames), set([q.name for q in queues]))
        self.agent.delQueue("qq0")
        self.assertIs(None, self.agent.getQueue("qq0"))
        try:
            self.agent.delQueue("nosuch")
        except:
            pass

    def test_exchanges(self):
        connections = self.agent.getAllConnections()
        enames = [ "ee%s"%i for i in xrange(10)]
        for e in enames:
            self.agent.addExchange('fanout', e)
            self.assertEqual(e, self.agent.getExchange(e).name)
        exchanges = self.agent.getAllExchanges()
        self.assertLess(set(enames), set([e.name for e in exchanges]))
        self.agent.delExchange("ee0")
        self.assertIs(None, self.agent.getExchange("ee0"))
        try:
            self.agent.delExchange("nosuch")
        except:
            pass

    def test_bind(self):
        self.agent.addQueue('qq')
        self.agent.addExchange('direct', 'ex')
        self.agent.bind('ex', 'qq', 'kk')
        self.assertTrue([b for b in self.agent.getAllBindings() if b.bindingKey == 'kk'])
        self.agent.unbind('ex', 'qq', 'kk')
        self.assertFalse([b for b in self.agent.getAllBindings() if b.bindingKey == 'kk'])

    def test_fork(self):
        """Ensure that the client is fork-safe."""
        self.agent.addQueue('parent')
        pid = os.fork()
        if pid:                 # parent
            self.assertEqual((pid,0), os.waitpid(pid, 0))
            self.assertIs(None, self.agent.addQueue('parent'))
            self.assertEqual('child', self.agent.getQueue('child').name)
        else:                   # child
            # Can't use the parent's connection.
            agent = BrokerAgent.connect(self.broker)
            agent.delQueue('parent')
            agent.addQueue('child')
            os._exit(0)        # Force exit, test framework will catch SystemExit


class DisconnectServer(MessagingHandler, Thread):
    """
    Server that disconnects its clients to test automatic re-connect
    """
    def __init__(self, addr):
        Thread.__init__(self)
        MessagingHandler.__init__(self)

        self.addr = addr
        self.response = None       # Response message
        self.senders = {}
        self.listening = False

        self.disconnect = Queue(0) # Disconnect requests
        self.disconnected = Queue(0) # Disconnects executed

        # Start listener and server thread
        self.container = Container(self)
        self.container.start()
        while not self.listening and self.container.process():
            pass
        self.start()

    def run(self):
        while self.container.process():
            pass
        self.container.stop()
        self.container.process()

    def stop(self):
        self.container.stop()
        self.join()

    def on_start(self, event):
        self.acceptor = event.container.listen(self.addr)
        self.listening = True

    def on_connection_bound(self, event):
        # Turn off security
        event.transport.require_auth(False);
        event.transport.sasl().allowed_mechs("ANONYMOUS");
        self.transport = event.transport

    def check_disconnect(self, event):
        try:
            self.disconnect.get_nowait()
            event.transport.close_head()
            event.transport.close_tail()
            self.disconnected.put(event.type)
            return True
        except Empty:
            return False

    def on_link_opening(self, event):
        if event.link.is_sender:
            if event.link.remote_source == "STOP":
                self.reactor.stop()
            if event.link.remote_source and event.link.remote_source.dynamic:
                event.link.source.address = str(id(event.link))
                self.senders[event.link.source.address] = event.link
            else:
                event.link.source.address = event.link.remote_source.address
        else:
            event.link.target.address = event.link.remote_target.address
            event.link.flow(1)
        self.check_disconnect(event)

    def on_message(self, event):
        if self.check_disconnect(event):
            return
        em = event.message
        m = self.response or em
        m.address = em.reply_to
        m.correlation_id = em.correlation_id
        self.senders[m.address].send(m)
        event.link.flow(1)


class ReconnectTests(unittest.TestCase):

    def setUp(self):
        with TestPort() as tp:
            self.server = DisconnectServer(tp.addr)

    def tearDown(self):
        self.server.stop()

    def test_reconnect_delays(self):
        self.assertEquals([0, 1, 2, 4, 7, 7, 7, 7], list(ReconnectDelays(1, 7, 3)))
        self.assertEquals([0, .2, .4, .8, 1.0], list(ReconnectDelays(.2, 1, 0)))
        self.assertRaises(ValueError, ReconnectDelays, 0, 1)
        self.assertRaises(ValueError, ReconnectDelays, 1, -1)
        d = iter(ReconnectDelays(5, 5)) # 5's forever
        self.assertEquals(0, d.next())
        for x in xrange(100):
            self.assertEquals(5, d.next())

    query_response = Message(body=[],
                            properties={"method":"response", "qmf.agent":"broker",
                                        "qmf.content":"_data", "qmf.opcode":"_query_response"})

    method_response = Message(body={"_arguments":[]},
                            properties={"method":"response", "qmf.agent":"broker",
                                        "qmf.content":"_data", "qmf.opcode":"_method_response"})

    def test_reconnect_agent(self):
        # Dummy response message
        self.server.response = self.query_response

        # Failure during initial connection should raise an exception, no reconnect
        self.server.disconnect.put(True)
        self.assertRaises(ConnectionException, BrokerAgent.connect, self.server.addr, reconnect_delays=[0, 0, 0])
        self.assertEquals(Event.LINK_REMOTE_OPEN, self.server.disconnected.get())

        agent = BrokerAgent.connect(self.server.addr, reconnect_delays=[0, 0, 0])
        agent.getBroker()                # Should work OK

        self.server.disconnect.put(True) # Disconnect on message delivery
        self.server.disconnect.put(True) # Disconnect first reconnect on link open
        self.server.disconnect.put(True) # Disconnect second reconnect on link open
        agent.getBroker()
        self.assertEquals(Event.DELIVERY, self.server.disconnected.get())
        self.assertEquals(Event.LINK_REMOTE_OPEN, self.server.disconnected.get())
        self.assertEquals(Event.LINK_REMOTE_OPEN, self.server.disconnected.get())

        # Try a healthy get
        agent.getBroker()

        self.server.disconnect.put(True)
        agent.list("foo")
        self.assertEquals(Event.DELIVERY, self.server.disconnected.get())

        self.server.disconnect.put(True)
        agent.getConnection("foo")
        self.assertEquals(Event.DELIVERY, self.server.disconnected.get())

        # Try a method call
        self.server.response = self.method_response
        self.server.disconnect.put(True)
        agent.echo()
        self.assertEquals(Event.DELIVERY, self.server.disconnected.get())

        # We should give up after 4 disconnects
        self.server.disconnect.put(True)
        self.server.disconnect.put(True)
        self.server.disconnect.put(True)
        self.server.disconnect.put(True)
        self.assertRaises(ConnectionException, agent.echo)

    def test_reconnect_agent_delay(self):
        self.server.response = self.query_response
        agent = BrokerAgent.connect(self.server.addr, reconnect_delays=[0.1, 0.2])
        def elapsed(f, *args, **kwargs):
            t = time.time()
            f(*args, **kwargs)
            return time.time() - t
        self.server.disconnect.put(True)
        self.assertLess(0.1, elapsed(agent.getBroker))
        self.server.disconnect.put(True)
        self.server.disconnect.put(True)
        self.assertLess(0.3, elapsed(agent.getBroker))

if __name__ == "__main__":
    shutil.rmtree("brokertest.tmp", True)
    os.execvp("qpid-python-test", ["qpid-python-test", "-m", "qmf_client_tests"])
