/*
 *
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 * 
 *   http://www.apache.org/licenses/LICENSE-2.0
 * 
 * Unless required by applicable law or agreed to in writing,
 * software distributed under the License is distributed on an
 * "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
 * KIND, either express or implied.  See the License for the
 * specific language governing permissions and limitations
 * under the License.
 *
 */
#include "SenderImpl.h"
#include "MessageSink.h"
#include "SessionImpl.h"
#include "AddressResolution.h"

namespace qpid {
namespace client {
namespace amqp0_10 {

SenderImpl::SenderImpl(SessionImpl& _parent, const std::string& _name, 
                       const qpid::messaging::Address& _address, 
                       const qpid::messaging::Variant::Map& _options) : 
    parent(_parent), name(_name), address(_address), options(_options), state(UNRESOLVED) {}

void SenderImpl::send(qpid::messaging::Message& m) 
{
    execute1<Send>(&m);
}

void SenderImpl::cancel()
{
    execute<Cancel>();
}

void SenderImpl::init(qpid::client::AsyncSession s, AddressResolution& resolver)
{
    session = s;
    if (state == UNRESOLVED) {
        sink = resolver.resolveSink(session, address, options);
        state = ACTIVE;
    }
    if (state == CANCELLED) {
        sink->cancel(session, name);
        parent.senderCancelled(name);
    } else {
        sink->declare(session, name);
        //TODO: replay
    }
}

void SenderImpl::sendImpl(qpid::messaging::Message& m) 
{
    //TODO: record for replay if appropriate
    sink->send(session, name, m);
}

void SenderImpl::cancelImpl()
{
    state = CANCELLED;
    sink->cancel(session, name);
    parent.senderCancelled(name);
}

}}} // namespace qpid::client::amqp0_10
