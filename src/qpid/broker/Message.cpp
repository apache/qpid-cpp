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

#include "Message.h"
#include "ExchangeRegistry.h"
#include "qpid/StringUtils.h"
#include "qpid/framing/frame_functors.h"
#include "qpid/framing/FieldTable.h"
#include "qpid/framing/MessageTransferBody.h"
#include "qpid/framing/SendContent.h"
#include "qpid/framing/SequenceNumber.h"
#include "qpid/framing/TypeFilter.h"
#include "qpid/log/Statement.h"

using boost::intrusive_ptr;
using namespace qpid::broker;
using namespace qpid::framing;
using std::string;

TransferAdapter Message::TRANSFER;

Message::Message(const SequenceNumber& id) : frames(id), persistenceId(0), redelivered(false), loaded(false),
staged(false), forcePersistentPolicy(false), publisher(0), adapter(0) {}

Message::~Message()
{
}

void Message::forcePersistent()
{
    forcePersistentPolicy = true;
}

std::string Message::getRoutingKey() const
{
    return getAdapter().getRoutingKey(frames);
}

std::string Message::getExchangeName() const 
{
    return getAdapter().getExchange(frames);
}

const boost::shared_ptr<Exchange> Message::getExchange(ExchangeRegistry& registry) const
{
    if (!exchange) {
        exchange = registry.get(getExchangeName());
    } 
    return exchange;
}

bool Message::isImmediate() const
{
    return getAdapter().isImmediate(frames);
}

const FieldTable* Message::getApplicationHeaders() const
{
    return getAdapter().getApplicationHeaders(frames);
}

bool Message::isPersistent()
{
    return (getAdapter().isPersistent(frames) || forcePersistentPolicy);
}

bool Message::requiresAccept()
{
    return getAdapter().requiresAccept(frames);
}

uint32_t Message::getRequiredCredit() const
{
    //add up payload for all header and content frames in the frameset
    SumBodySize sum;
    frames.map_if(sum, TypeFilter2<HEADER_BODY, CONTENT_BODY>());
    return sum.getSize();
}

void Message::encode(framing::Buffer& buffer) const
{
    //encode method and header frames
    EncodeFrame f1(buffer);
    frames.map_if(f1, TypeFilter2<METHOD_BODY, HEADER_BODY>());

    //then encode the payload of each content frame
    EncodeBody f2(buffer);
    frames.map_if(f2, TypeFilter<CONTENT_BODY>());
}

void Message::encodeContent(framing::Buffer& buffer) const
{
    //encode the payload of each content frame
    EncodeBody f2(buffer);
    frames.map_if(f2, TypeFilter<CONTENT_BODY>());
}

uint32_t Message::encodedSize() const
{
    return encodedHeaderSize() + encodedContentSize();
}

uint32_t Message::encodedContentSize() const
{
    return  frames.getContentSize();
}

uint32_t Message::encodedHeaderSize() const
{
    //add up the size for all method and header frames in the frameset
    SumFrameSize sum;
    frames.map_if(sum, TypeFilter2<METHOD_BODY, HEADER_BODY>());
    return sum.getSize();
}

void Message::decodeHeader(framing::Buffer& buffer)
{
    AMQFrame method;
    method.decode(buffer);
    frames.append(method);

    AMQFrame header;
    header.decode(buffer);
    frames.append(header);
}

void Message::decodeContent(framing::Buffer& buffer)
{
    if (buffer.available()) {
        //get the data as a string and set that as the content
        //body on a frame then add that frame to the frameset
        AMQFrame frame;
        frame.setBody(AMQContentBody());
        frame.castBody<AMQContentBody>()->decode(buffer, buffer.available());
        frames.append(frame);
    } else {
        //adjust header flags
        MarkLastSegment f;
        frames.map_if(f, TypeFilter<HEADER_BODY>());    
    }
    //mark content loaded
    loaded = true;
}

void Message::releaseContent(MessageStore* _store)
{
    if (!store) {
        store = _store;
    }
    if (store) {
        if (!getPersistenceId()) {
            intrusive_ptr<PersistableMessage> pmsg(this);
            store->stage(pmsg);
            staged = true;
        }
        //remove any content frames from the frameset
        frames.remove(TypeFilter<CONTENT_BODY>());
        setContentReleased();
    }
}

void Message::destroy()
{
    if (staged) {
        if (store) {
            store->destroy(*this);
        } else {
            QPID_LOG(error, "Message content was staged but no store is set so it can't be destroyed");
        }
    }
}

void Message::sendContent(Queue& queue, framing::FrameHandler& out, uint16_t maxFrameSize) const
{
    if (isContentReleased()) {
        //load content from store in chunks of maxContentSize
        uint16_t maxContentSize = maxFrameSize - AMQFrame::frameOverhead();
        intrusive_ptr<const PersistableMessage> pmsg(this);
        
        bool done = false;
        for (uint64_t offset = 0; !done; offset += maxContentSize)
        {            
            AMQFrame frame(in_place<AMQContentBody>());
            string& data = frame.castBody<AMQContentBody>()->getData();

            store->loadContent(queue, pmsg, data, offset, maxContentSize);
            done = data.size() < maxContentSize;
            frame.setBof(false);
            frame.setEof(true);
            if (offset > 0) {
                frame.setBos(false);
            }
            if (!done) {
                frame.setEos(false);
            }
            QPID_LOG(debug, "loaded frame for delivery: " << frame);
            out.handle(frame);
        }
    } else {
        Count c;
        frames.map_if(c, TypeFilter<CONTENT_BODY>());

        SendContent f(out, maxFrameSize, c.getCount());
        frames.map_if(f, TypeFilter<CONTENT_BODY>());
    }
}

void Message::sendHeader(framing::FrameHandler& out, uint16_t /*maxFrameSize*/) const
{
    sys::Mutex::ScopedLock l(lock);
    Relay f(out);
    frames.map_if(f, TypeFilter<HEADER_BODY>());    
}

// TODO aconway 2007-11-09: Obsolete, remove. Was used to cover over
// 0-8/0-9 message differences.
MessageAdapter& Message::getAdapter() const
{
    if (!adapter) {
        if(frames.isA<MessageTransferBody>()) {
            adapter = &TRANSFER;
        } else {
            const AMQMethodBody* method = frames.getMethod();
            if (!method) throw Exception("Can't adapt message with no method");
            else throw Exception(QPID_MSG("Can't adapt message based on " << *method));
        }
    }
    return *adapter;
}

uint64_t Message::contentSize() const
{
    return frames.getContentSize();
}

bool Message::isContentLoaded() const
{
    return loaded;
}


namespace 
{
    const std::string X_QPID_TRACE("x-qpid.trace");
}

bool Message::isExcluded(const std::vector<std::string>& excludes) const
{
    const FieldTable* headers = getApplicationHeaders();
    if (headers) {
        std::string traceStr = headers->getString(X_QPID_TRACE);
        if (traceStr.size()) {
            std::vector<std::string> trace = split(traceStr, ", ");

            for (std::vector<std::string>::const_iterator i = excludes.begin(); i != excludes.end(); i++) {
                for (std::vector<std::string>::const_iterator j = trace.begin(); j != trace.end(); j++) {
                    if (*i == *j) {
                        return true;
                    }
                }
            }
        }
    }
    return false;
}

void Message::addTraceId(const std::string& id)
{
    sys::Mutex::ScopedLock l(lock);
    if (isA<MessageTransferBody>()) {
        FieldTable& headers = getProperties<MessageProperties>()->getApplicationHeaders();
        std::string trace = headers.getString(X_QPID_TRACE);
        if (trace.empty()) {
            headers.setString(X_QPID_TRACE, id);
        } else if (trace.find(id) == std::string::npos) {
            trace += ",";
            trace += id;
            headers.setString(X_QPID_TRACE, trace);
        }        
    }
}
