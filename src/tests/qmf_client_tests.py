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

import unittest, qmf.client, os

class QmfClientTest(unittest.TestCase):
    """
    Test QMFv2 support using the qmf.console library.
    """

    def configure(self, config):
        """Called by the qpid-python-test framework with broker config"""
        self.broker = config.broker

    def setUp(self):
        self.agent = qmf.client.BrokerAgent.connect(self.broker)

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
            agent = qmf.client.BrokerAgent.connect(self.broker)
            agent.delQueue('parent')
            agent.addQueue('child')
            os._exit(0)        # Force exit, test framework will catch SystemExit

if __name__ == "__main__":
    shutil.rmtree("brokertest.tmp", True)
    os.execvp("qpid-python-test", ["qpid-python-test", "-m", "qmf_client_tests"])
