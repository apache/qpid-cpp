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

FROM quay.io/centos/centos:stream9 as builder

RUN dnf -y install epel-release 'dnf-command(config-manager)'
RUN dnf config-manager --set-enabled crb

# I am referring to the CentOS7 package (.spec file in the src.rpm) to look up dependencies
#  https://koji.fedoraproject.org/koji/buildinfo?buildID=1180279
# TODO seemingly unavailable packages:
#  xqilla-devel

RUN dnf -y --setopt=install_weak_deps=0 --setopt=tsflags=nodocs install \
    rpm-build \
    gcc gcc-c++ make cmake \
    boost-devel boost-filesystem boost-program-options \
    xerces-c-devel \
    rdma-core-devel \
    libdb-devel libdb-cxx-devel libaio-devel \
    qpid-proton-c-devel \
    swig perl-devel python3-devel ruby-devel rubygem-rexml \
    libuuid-devel nss-devel nspr-devel nss-tools cyrus-sasl cyrus-sasl-lib cyrus-sasl-devel \
    wget tar patch findutils git pkgconfig

# Workaround for latest release of qpid-python being incompatible with python 3
WORKDIR /build
RUN git clone https://github.com/apache/qpid-python.git \
    && cd qpid-python \
    && python3 setup.py install

# git clone https://github.com/apache/qpid-cpp.git
COPY . .
RUN eval "$(rpmbuild --eval '%set_build_flags')" \
    && cmake -S . -B cmake-build \
        -DBUILD_DOCS=OFF \
        -DBUILD_TESTING=OFF \
        -DCMAKE_INSTALL_PREFIX=/usr \
        -DPYTHON_EXECUTABLE=/usr/bin/python3 \
    && cmake --build "cmake-build" --parallel "$(nproc)" --verbose \
    && cmake --install "cmake-build"

EXPOSE 5672
CMD ["/usr/sbin/qpidd"]
