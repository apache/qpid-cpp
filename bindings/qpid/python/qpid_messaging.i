/*
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
 */

%module qpid_messaging

%include "std_string.i"
%include "qpid/swig_python_typemaps.i"

/* Needed for get/setPriority methods.  Surprising SWIG 1.3.40 doesn't
 * convert uint8_t by default. */
%apply unsigned char { uint8_t };


/*
 * Exceptions
 *
 * The convention below is that exceptions in _qpid_messaging.so have the same
 * names as in the C++ library.  They get renamed to their Python
 * equivalents when brought into the Python wrapping
 */
%define QPID_EXCEPTION(exception, parent)
%{
static PyObject* exception;
%}
%init %{
    exception = PyErr_NewException(
        (char *) ("_qpid_messaging." #exception), parent, NULL);
    Py_INCREF(exception);
    PyModule_AddObject(m, #exception, exception);
%}
%pythoncode %{
    exception = _qpid_messaging. ## exception
%}
%enddef

 /* Python equivalents of C++ exceptions.                              */
 /*                                                                    */
 /* Commented out lines are exceptions in the Python library, but not  */
 /* in the C++ library.                                                */

QPID_EXCEPTION(MessagingError, NULL)

QPID_EXCEPTION(LinkError, MessagingError)
QPID_EXCEPTION(AddressError, LinkError)
QPID_EXCEPTION(ResolutionError, AddressError)
QPID_EXCEPTION(AssertionFailed, ResolutionError)
QPID_EXCEPTION(NotFound, ResolutionError)
QPID_EXCEPTION(InvalidOption, LinkError)
QPID_EXCEPTION(MalformedAddress, LinkError)
QPID_EXCEPTION(ReceiverError, LinkError)
QPID_EXCEPTION(FetchError, ReceiverError)
QPID_EXCEPTION(Empty, FetchError)
/* QPID_EXCEPTION(InsufficientCapacity, LinkError) */
/* QPID_EXCEPTION(LinkClosed, LinkError) */
QPID_EXCEPTION(SenderError, LinkError)
QPID_EXCEPTION(SendError, SenderError)
QPID_EXCEPTION(TargetCapacityExceeded, SendError)

QPID_EXCEPTION(ConnectionError, MessagingError)
QPID_EXCEPTION(ConnectError, ConnectionError)
/* QPID_EXCEPTION(AuthenticationFailure, ConnectError) */
/* QPID_EXCEPTION(VersionError, ConnectError) */
/* QPID_EXCEPTION(ConnectionClosed, ConnectionError) */
/* QPID_EXCEPTION(HeartbeartTimeout, ConnectionError) */

QPID_EXCEPTION(SessionError, MessagingError)
/* QPID_EXCEPTION(Detached, SessionError) */
/* QPID_EXCEPTION(NontransactionalSession, SessionError) */
/* QPID_EXCEPTION(ServerError, SessionError) */
/* QPID_EXCEPTION(SessionClosed, SessionError) */
QPID_EXCEPTION(TransactionError, SessionError)
QPID_EXCEPTION(TransactionAborted, TransactionError)
QPID_EXCEPTION(TransactionUnknown, TransactionError)
QPID_EXCEPTION(UnauthorizedAccess, SessionError)

/* QPID_EXCEPTION(InternalError, MessagingError) */

%define TRANSLATE_EXCEPTION(cpp_exception, py_exception)
    catch ( cpp_exception & ex) {
        pExceptionType = py_exception;
        error = ex.what();
    }
%enddef

/* Define the general-purpose exception handling */
%exception {
    PyObject * pExceptionType = NULL;
    bool failed = true;
    std::string error;
    Py_BEGIN_ALLOW_THREADS;
    try {
        $action
        failed = false;
    }
    /* Catch and translate exceptions. */
    TRANSLATE_EXCEPTION(qpid::messaging::NoMessageAvailable, Empty)
    TRANSLATE_EXCEPTION(qpid::messaging::NotFound, NotFound)
    TRANSLATE_EXCEPTION(qpid::messaging::AssertionFailed, AssertionFailed)
    TRANSLATE_EXCEPTION(qpid::messaging::ResolutionError, ResolutionError)
    TRANSLATE_EXCEPTION(qpid::messaging::TargetCapacityExceeded,
                        TargetCapacityExceeded)
    TRANSLATE_EXCEPTION(qpid::messaging::TransportFailure, ConnectError)
    TRANSLATE_EXCEPTION(qpid::messaging::MalformedAddress, MalformedAddress)
    TRANSLATE_EXCEPTION(qpid::messaging::AddressError, AddressError)
    TRANSLATE_EXCEPTION(qpid::messaging::FetchError, FetchError)
    TRANSLATE_EXCEPTION(qpid::messaging::ReceiverError, ReceiverError)
    TRANSLATE_EXCEPTION(qpid::messaging::SendError, SendError)
    TRANSLATE_EXCEPTION(qpid::messaging::SenderError, SenderError)
    TRANSLATE_EXCEPTION(qpid::messaging::InvalidOptionString, InvalidOption)
    TRANSLATE_EXCEPTION(qpid::messaging::LinkError, LinkError)
    TRANSLATE_EXCEPTION(qpid::messaging::TransactionAborted, TransactionAborted)
    TRANSLATE_EXCEPTION(qpid::messaging::TransactionUnknown, TransactionUnknown)
    TRANSLATE_EXCEPTION(qpid::messaging::TransactionError, TransactionError)
    TRANSLATE_EXCEPTION(qpid::messaging::UnauthorizedAccess, UnauthorizedAccess)
    TRANSLATE_EXCEPTION(qpid::messaging::SessionError, SessionError)
    TRANSLATE_EXCEPTION(qpid::messaging::ConnectionError, ConnectionError)
    TRANSLATE_EXCEPTION(qpid::messaging::KeyError, PyExc_KeyError)
    TRANSLATE_EXCEPTION(qpid::messaging::MessagingException, MessagingError)
    TRANSLATE_EXCEPTION(qpid::types::Exception, PyExc_RuntimeError)
    Py_END_ALLOW_THREADS;
    if (failed) {
        if (!error.empty()) {
            PyErr_SetString(pExceptionType, error.c_str());
        }
        SWIG_fail;
    }
}


/* This only renames the non-const version (I believe).  Then again, I
 * don't even know why there is a non-const version of the method. */
%rename(opened) qpid::messaging::Connection::isOpen();
%rename(_close) qpid::messaging::Connection::close();
%rename(_receiver) qpid::messaging::Session::createReceiver;
%rename(_sender) qpid::messaging::Session::createSender;
%rename(_acknowledge_all) qpid::messaging::Session::acknowledge(bool);
%rename(_acknowledge_msg) qpid::messaging::Session::acknowledge(
    Message &, bool);
%rename(_next_receiver) qpid::messaging::Session::nextReceiver;

%rename(_fetch) qpid::messaging::Receiver::fetch;
%rename(_get) qpid::messaging::Receiver::get;
%rename(unsettled) qpid::messaging::Receiver::getUnsettled;
%rename(available) qpid::messaging::Receiver::getAvailable;

%rename(unsettled) qpid::messaging::Sender::getUnsettled;
%rename(available) qpid::messaging::Sender::getAvailable;
%rename(_send) qpid::messaging::Sender::send;

%rename(_getReplyTo) qpid::messaging::Message::getReplyTo;
%rename(_setReplyTo) qpid::messaging::Message::setReplyTo;
%rename(_getTtl) qpid::messaging::Message::getTtl;
%rename(_setTtl) qpid::messaging::Message::setTtl;

%rename(_sync) qpid::messaging::Session::sync;

// Capitalize constant names correctly for python
%rename(TRACE) qpid::messaging::trace;
%rename(DEBUG) qpid::messaging::debug;
%rename(INFO) qpid::messaging::info;
%rename(NOTICE) qpid::messaging::notice;
%rename(WARNING) qpid::messaging::warning;
%rename(ERROR) qpid::messaging::error;
%rename(CRITICAL) qpid::messaging::critical;

%include "qpid/qpid.i"

%extend qpid::messaging::Connection {
    %pythoncode %{
         def __init__(self, url=None, **options):
             if url:
                 args = [str(url)]
             else:
                 args = []
             if options:
                 # remove null valued options
                 clean_opts = {}
                 for k, v in options.iteritems():
                     if v:
                         clean_opts[k] = v
                 args.append(clean_opts)
             this = _qpid_messaging.new_Connection(*args)
             try: self.this.append(this)
             except: self.this = this

         def attached(self):
             return self.opened()

         def close(self, timeout=None):
             #timeout not supported in c++
             self._close()
    %}

    /* Return a pre-existing session with the given name, if one
     * exists, otherwise return a new one.  (Note that if a
     * pre-existing session exists, the transactional argument is
     * ignored, and the returned session might not satisfy the desired
     * setting. */
    qpid::messaging::Session _session(const std::string & name,
                                     bool transactional) {
        if (!name.empty()) {
            try {
                return self->getSession(name);
            }
            catch (const qpid::messaging::KeyError &) {
            }
        }
        if (transactional) {
            return self->createTransactionalSession(name);
        }
        else {
            return self->createSession(name);
        }
    }

    %pythoncode %{
        def session(self, name=None, transactional=False) :
            if name is None :
                name = ''
            return self._session(name, transactional)
    %}

    %pythoncode %{
        @staticmethod
        def establish(url=None, timeout=None, **options) :
            if timeout and "reconnect-timeout" not in options:
                options["reconnect-timeout"] = timeout
            conn = Connection(url, **options)
            conn.open()
            return conn
    %}
}

%pythoncode %{
    # Disposition class from messaging/message.py
    class Disposition:
        def __init__(self, type, **options):
            self.type = type
            self.options = options

        def __repr__(self):
            args = [str(self.type)] + ["%s=%r" % (k, v) for k, v in self.options.items()]
            return "Disposition(%s)" % ", ".join(args)

    # Consntants from messaging/constants.py
    __SELF__ = object()

    class Constant:

      def __init__(self, name, value=__SELF__):
        self.name = name
        if value is __SELF__:
          self.value = self
        else:
          self.value = value

      def __repr__(self):
        return self.name

    AMQP_PORT = 5672
    AMQPS_PORT = 5671

    UNLIMITED = Constant("UNLIMITED", 0xFFFFFFFFL)

    REJECTED = Constant("REJECTED")
    RELEASED = Constant("RELEASED")
%}

%extend qpid::messaging::Session {
    %pythoncode %{
         def acknowledge(self, message=None, disposition=None, sync=True) :
             if message :
                 if disposition is None: self._acknowledge_msg(message, sync)
                 # FIXME aconway 2014-02-11: the following does not repsect the sync flag.
                 elif disposition.type == REJECTED: self.reject(message)
                 elif disposition.type == RELEASED: self.release(message)
             else :
                 if disposition : # FIXME aconway 2014-02-11: support this
                     raise Exception("SWIG does not support dispositions yet. Use "
                                     "Session.reject and Session.release instead")
                 self._acknowledge_all(sync)

         __swig_getmethods__["connection"] = getConnection
         if _newclass: connection = property(getConnection)

         def receiver(self, source, capacity=None):
             r = self._receiver(source)
             if capacity is not None: r.capacity = capacity
             return r

         def sender(self, target, durable=None, capacity=None) :
             s = self._sender(target)
             if capacity is not None: s.capacity = capacity
             s._setDurable(durable)
             return s

         def next_receiver(self, timeout=None) :
             if timeout is None :
                 return self._next_receiver()
             else :
                 # Python API uses timeouts in seconds,
                 # but C++ API uses milliseconds
                 return self._next_receiver(Duration(int(1000*timeout)))

         def sync(self, timeout=None):
             if timeout == 0: self._sync(False) # Non-blocking sync
             else: self._sync(True)             # Blocking sync, C++ has not timeout.

    %}
}


%extend qpid::messaging::Receiver {
    %pythoncode %{
         def _get_source(self):
             return self.getAddress().str()

         __swig_getmethods__["capacity"] = getCapacity
         __swig_setmethods__["capacity"] = setCapacity
         if _newclass: capacity = property(getCapacity, setCapacity)

         __swig_getmethods__["session"] = getSession
         if _newclass: session = property(getSession)

         __swig_getmethods__["source"] = _get_source
         if _newclass: source = property(_get_source)
    %}

    %pythoncode %{
         def fetch(self, timeout=None) :
             if timeout is None :
                 return self._fetch()
             else :
                 # Python API uses timeouts in seconds,
                 # but C++ API uses milliseconds
                 return self._fetch(Duration(int(1000*timeout)))
    %}

    %pythoncode %{
         def get(self, timeout=None) :
             if timeout is None :
                 return self._get()
             else :
                 # Python API uses timeouts in seconds,
                 # but C++ API uses milliseconds
                 return self._get(Duration(int(1000*timeout)))
    %}
}

%extend qpid::messaging::Sender {
    %pythoncode %{
         def _get_target(self):
             return self.getAddress().str()

         def _setDurable(self, d):
             self.durable = d

         def send(self, object, sync=True) :
             if isinstance(object, Message):
                 message = object
             else:
                 message = Message(object)
             if self.durable and message.durable is None:
                 message.durable = self.durable
             return self._send(message, sync)

         def sync(self, timeout=None): self.session.sync(timeout)

         __swig_getmethods__["capacity"] = getCapacity
         __swig_setmethods__["capacity"] = setCapacity
         if _newclass: capacity = property(getCapacity, setCapacity)

         __swig_getmethods__["session"] = getSession
         if _newclass: session = property(getSession)

         __swig_getmethods__["target"] = _get_target
         if _newclass: source = property(_get_target)

    %}
}


%extend qpid::messaging::Message {
    %pythoncode %{
         class MessageProperties:
             def __init__(self, msg):
                 self.msg = msg
                 self.properties = self.msg.getProperties()

             def __len__(self):
                 return self.properties.__len__()

             def __getitem__(self, key):
                 return self.properties[key];

             def get(self, key):
                 return self.__getitem__(key)

             def __setitem__(self, key, value):
                 self.properties[key] = value
                 self.msg.setProperty(key, value)

             def set(self, key, value):
                 self.__setitem__(key, value)

             def __delitem__(self, key):
                 del self.properties[key]
                 self.msg.setProperties(self.properties)

             def __iter__(self):
                 return self.properties.iteritems()

             def __repr__(self):
                 return str(self.properties)

         # UNSPECIFIED was module level before, but I do not
         # know how to insert python code at the top of the module.
         # (A bare "%pythoncode" inserts at the end.
         UNSPECIFIED=object()
         def __init__(self, content=None, content_type=UNSPECIFIED, id=None,
                      subject=None, user_id=None, reply_to=None,
                      correlation_id=None, durable=None, priority=None,
                      ttl=None, properties=None):
             this = _qpid_messaging.new_Message('')
             try: self.this.append(this)
             except: self.this = this
             if not content is None:
                 self.content = content
             if content_type != UNSPECIFIED :
                 self.content_type = content_type
             if id is not None :
                 self.id = id
             if subject is not None :
                 self.subject = subject
             if user_id is not None :
                 self.user_id = user_id
             if reply_to is not None :
                 self.reply_to = reply_to
             if correlation_id is not None :
                 self.correlation_id = correlation_id
             if durable is not None :
                 self.durable = durable
             if priority is not None :
                 self.priority = priority
             if ttl is not None :
                 self.ttl = ttl
             if properties is not None :
                 self.setProperties(properties)

         def _get_msg_props(self):
             try:
                 return self._msg_props
             except AttributeError:
                 self._msg_props = Message.MessageProperties(self)
                 return self._msg_props

         def _get_content(self) :
             obj = self.getContentObject()
             if obj is not None:
                 return obj
             if self.content_type == "amqp/list" :
                 return decodeList(self)
             if self.content_type == "amqp/map" :
                 return decodeMap(self)
             return self.getContent()

         def _set_content(self, content) :
             if isinstance(content, str) :
                 self.setContent(content)
             elif isinstance(content, unicode) :
                 if not self.content_type: self.content_type = "text/plain"
                 self.setContent(str(content))
             elif isinstance(content, list) or isinstance(content, dict) :
                 encode(content, self)
             else :
                 self.setContentObject(content)
         __swig_getmethods__["content"] = _get_content
         __swig_setmethods__["content"] = _set_content
         if _newclass: content = property(_get_content, _set_content)

         def _get_content_type(self) :
             ct = self.getContentType()
             if ct == "": return None
             else: return ct

         __swig_getmethods__["content_type"] = _get_content_type
         __swig_setmethods__["content_type"] = setContentType
         if _newclass: content_type = property(_get_content_type, setContentType)

         __swig_getmethods__["id"] = getMessageId
         __swig_setmethods__["id"] = setMessageId
         if _newclass: id = property(getMessageId, setMessageId)

         __swig_getmethods__["subject"] = getSubject
         __swig_setmethods__["subject"] = setSubject
         if _newclass: subject = property(getSubject, setSubject)

         __swig_getmethods__["priority"] = getPriority
         __swig_setmethods__["priority"] = setPriority
         if _newclass: priority = property(getPriority, setPriority)

         def getTtl(self) :
             return self._getTtl().getMilliseconds()/1000.0
         def setTtl(self, duration) :
             self._setTtl(Duration(int(1000*duration)))
         __swig_getmethods__["ttl"] = getTtl
         __swig_setmethods__["ttl"] = setTtl
         if _newclass: ttl = property(getTtl, setTtl)

         __swig_getmethods__["user_id"] = getUserId
         __swig_setmethods__["user_id"] = setUserId
         if _newclass: user_id = property(getUserId, setUserId)

         __swig_getmethods__["correlation_id"] = getCorrelationId
         __swig_setmethods__["correlation_id"] = setCorrelationId
         if _newclass: correlation_id = property(getCorrelationId, setCorrelationId)

         __swig_getmethods__["redelivered"] = getRedelivered
         __swig_setmethods__["redelivered"] = setRedelivered
         if _newclass: redelivered = property(getRedelivered, setRedelivered)

         __swig_getmethods__["durable"] = getDurable
         __swig_setmethods__["durable"] = setDurable
         if _newclass: durable = property(getDurable, setDurable)

         __swig_getmethods__["properties"] = _get_msg_props
         if _newclass: properties = property(_get_msg_props)

         def getReplyTo(self) :
             return self._getReplyTo().str()
         def setReplyTo(self, address_str) :
             self._setReplyTo(Address(address_str))
         __swig_getmethods__["reply_to"] = getReplyTo
         __swig_setmethods__["reply_to"] = setReplyTo
         if _newclass: reply_to = property(getReplyTo, setReplyTo)

         def __repr__(self):
             args = []
             for name in ["id", "subject", "user_id", "reply_to",
                          "correlation_id", "priority", "ttl",
                          "durable", "redelivered", "properties",
                          "content_type"] :
                 value = getattr(self, name)
                 if value : args.append("%s=%r" % (name, value))
             if self.content is not None:
                 if args:
                     args.append("content=%r" % self.content)
                 else:
                     args.append(repr(self.content))
             return "Message(%s)" % ", ".join(args)
    %}
}

%pythoncode %{
# Bring into module scope
UNSPECIFIED = Message.UNSPECIFIED
%}
