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

%module cqmf2
%include "std_string.i"
%include "qpid/swig_python_typemaps.i"

/* Define the general-purpose exception handling */
%exception {
    bool failed = true;
    std::string error;
    Py_BEGIN_ALLOW_THREADS;
    try {
        $action
        failed = false;
    } catch (qpid::types::Exception& ex) {
        error = ex.what();
    }
    Py_END_ALLOW_THREADS;
    if (failed) {
        if (!error.empty()) {
            PyErr_SetString(PyExc_RuntimeError, error.c_str());
        }
        SWIG_fail;
    }
}

%include "qmf/qmf2.i"

