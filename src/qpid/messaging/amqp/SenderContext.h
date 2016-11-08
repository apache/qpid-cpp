#ifndef QPID_MESSAGING_AMQP_SENDERCONTEXT_H
#define QPID_MESSAGING_AMQP_SENDERCONTEXT_H

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
#include <deque>
#include <string>
#include <vector>
#include <boost/shared_ptr.hpp>
#include "qpid/sys/IntegerTypes.h"
#include "qpid/sys/ExceptionHolder.h"
#include "qpid/sys/Time.h"
#include "qpid/messaging/Address.h"
#include "qpid/messaging/amqp/AddressHelper.h"
#include "qpid/messaging/amqp/EncodedMessage.h"

struct pn_delivery_t;
struct pn_link_t;
struct pn_session_t;
struct pn_terminus_t;

namespace qpid {
namespace messaging {

class Message;
class MessageImpl;

struct MessageReleased : public SendError
{
    MessageReleased(const std::string&);
};

namespace amqp {

class Transaction;

class SenderOptions {
 public:
    bool setToOnSend;
    uint32_t maxDeliveryAttempts;
    bool raiseRejected;
    qpid::sys::Duration redeliveryTimeout;

    SenderOptions(bool setToOnSend, uint32_t maxDeliveryAttempts, bool raiseRejected, const qpid::sys::Duration& redeliveryTimeout=qpid::sys::Duration(0));
};

class SenderContext
{
  public:
    class Delivery
    {
      public:
        Delivery(int32_t id, const uint32_t max_attempts = 0, const qpid::sys::Duration& = qpid::sys::Duration(0));
        void encode(const qpid::messaging::MessageImpl& message, const qpid::messaging::Address&, bool setToField);
        void send(pn_link_t*, bool unreliable, const types::Variant& state=types::Variant());
        bool delivered();
        bool accepted();
        bool rejected();
        bool released();
        bool modified();
        bool delivery_refused();
        bool not_delivered();
        void settle();
        void reset();
        void settleAndReset();
        bool sent() const;
        pn_delivery_t* getToken() const { return token; }
        std::string error();
      private:
        int32_t id;
        pn_delivery_t* token;
        EncodedMessage encoded;
        bool settled;
        uint32_t attempts;
        const uint32_t max_attempts;
        const qpid::sys::AbsTime retry_until;

        std::string getStatus();
};

    typedef boost::shared_ptr<Transaction> CoordinatorPtr;

    SenderContext(pn_session_t* session, const std::string& name,
                  const qpid::messaging::Address& target,
                  const SenderOptions&,
                  const CoordinatorPtr& transaction = CoordinatorPtr());
    virtual ~SenderContext();

    virtual void reset(pn_session_t* session);
    virtual void close();
    virtual void setCapacity(uint32_t);
    virtual uint32_t getCapacity();
    virtual uint32_t getUnsettled();
    virtual const std::string& getName() const;
    virtual const std::string& getTarget() const;
    virtual bool send(const qpid::messaging::Message& message, Delivery**);
    virtual void configure();
    virtual void verify();
    virtual void check();
    virtual bool settled();
    virtual bool closed();
    virtual Address getAddress() const;
    void cleanup();

  protected:
    pn_link_t* sender;

  private:
    friend class ConnectionContext;
    typedef std::deque<Delivery> Deliveries;

    const std::string name;
    qpid::messaging::Address address;
    AddressHelper helper;
    int32_t nextId;
    Deliveries deliveries;
    uint32_t capacity;
    bool unreliable;
    const SenderOptions options;
    boost::shared_ptr<Transaction> transaction;
    sys::ExceptionHolder error;

    uint32_t processUnsettled(bool silent);
    void configure(pn_terminus_t*);
    void resend();
};
}}} // namespace qpid::messaging::amqp

#endif  /*!QPID_MESSAGING_AMQP_SENDERCONTEXT_H*/
