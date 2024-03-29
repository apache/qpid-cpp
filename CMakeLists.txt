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

project(qpid-cpp)

if (NOT MSVC)
  cmake_minimum_required(VERSION 2.8.12 FATAL_ERROR)
else (NOT MSVC)
  # windows PDB file installation needs v3.1
  cmake_minimum_required(VERSION 3.1.3 FATAL_ERROR)
endif (NOT MSVC)

if (CMAKE_CONFIGURATION_TYPES)
  # There is no single "build type"...
  message(STATUS "Build types are ${CMAKE_CONFIGURATION_TYPES}")
else (CMAKE_CONFIGURATION_TYPES)
  # There is a single build configuration
  # If the build type is not set then set the default
  if (NOT CMAKE_BUILD_TYPE)
  set (CMAKE_BUILD_TYPE RelWithDebInfo CACHE STRING
       "Build type: Debug, Release, RelWithDebInfo or MinSizeRel (default RelWithDebInfo)" FORCE)
  endif ()

  if (CMAKE_BUILD_TYPE MATCHES "Deb")
    set (has_debug_symbols " (has debug symbols)")
  endif (CMAKE_BUILD_TYPE MATCHES "Deb")
  message(STATUS "Build type is \"${CMAKE_BUILD_TYPE}\"${has_debug_symbols}")
endif (CMAKE_CONFIGURATION_TYPES)

set(CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/CMakeModules)

file(READ VERSION.txt QPID_VERSION)
string(STRIP ${QPID_VERSION} QPID_VERSION_LINE)
string(REPLACE "-" ";" QPID_VERSION_SPLIT "${QPID_VERSION_LINE}")
list(GET QPID_VERSION_SPLIT 0 QPID_VERSION_CLEAN)
list(REMOVE_AT QPID_VERSION_SPLIT 0)
string(REPLACE ";" "-" QPID_VERSION_QUALIFIER "${QPID_VERSION_SPLIT}")
string(REGEX MATCHALL "[0-9]+" QPID_VERSION_LIST "${QPID_VERSION_CLEAN}")

list(GET QPID_VERSION_LIST 0 QPID_VERSION_MAJOR)
list(GET QPID_VERSION_LIST 1 QPID_VERSION_MINOR)
list(GET QPID_VERSION_LIST 2 QPID_VERSION_POINT)

set(QPID_VERSION_FULL "${QPID_VERSION_MAJOR}.${QPID_VERSION_MINOR}.${QPID_VERSION_POINT}")
set(qpidc_version ${QPID_VERSION_FULL})

include(BuildInstallSettings.cmake)

find_package(PythonInterp 2.7 REQUIRED)

enable_testing()
include (CTest)
configure_file(${CMAKE_SOURCE_DIR}/CTestCustom.cmake ${CMAKE_BINARY_DIR}/CTestCustom.cmake)

if (MSVC)
  # Change warning C4996 from level 1 to level 4. These are real and shouldn't
  # be completely ignored, but they're pretty well checked out and will throw
  # a run-time error if violated.
  # "warning C4996: 'std::equal': Function call with parameters that may be unsafe..."
  # https://learn.microsoft.com/en-us/cpp/error-messages/compiler-warnings/compiler-warning-level-3-c4996?view=msvc-140
  add_compile_options(/wd4996)
endif (MSVC)

# QPID-8605: silence the global placeholders deprecation warning from boost
add_compile_definitions(BOOST_BIND_GLOBAL_PLACEHOLDERS)

# Overall packaging/install options.
# This section also has all the setup for various packaging-specific options.
set (CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE.txt")
if (WIN32)
  # Include installing the MSVCRT library
  set (CMAKE_INSTALL_DEBUG_LIBRARIES ON)
  include(InstallRequiredSystemLibraries)
  set (CPACK_GENERATOR "NSIS")
  set (CPACK_NSIS_MUI_ICON "${CMAKE_CURRENT_SOURCE_DIR}/packaging/NSIS\\\\qpid-icon.ico")
  set (CPACK_NSIS_MUI_UNIICON "${CMAKE_CURRENT_SOURCE_DIR}/packaging/NSIS\\\\qpid-icon.ico")
  set (CPACK_PACKAGE_ICON "${CMAKE_CURRENT_SOURCE_DIR}/packaging/NSIS\\\\qpid-install-banner.bmp")
  set (CPACK_NSIS_URL_INFO_ABOUT "http://qpid.apache.org/")
  # Needs this to correctly set up Start menu links later.
  set (CPACK_PACKAGE_EXECUTABLES "")
endif (WIN32)

set_absolute_install_path (QPIDC_CONF_FILE ${QPID_INSTALL_CONFDIR}/qpidc.conf)
set_absolute_install_path (QPIDD_CONF_FILE ${QPID_INSTALL_CONFDIR}/qpidd.conf)

install(FILES  LICENSE.txt NOTICE.txt DESTINATION ${QPID_INSTALL_DOCDIR})
install(FILES  include/qmf/qmf2.i
        DESTINATION ${QPID_INSTALL_INCLUDEDIR}/qmf)

if (WIN32)
  set (CMAKE_DEBUG_POSTFIX "d")
endif (WIN32)

# set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CPACK_SET_DESTDIR ON)
set(CPACK_PACKAGE_NAME "qpid-cpp")
set(CPACK_PACKAGE_VENDOR "Apache Software Foundation")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Apache Qpid C++")
set(CPACK_PACKAGE_VERSION "${qpidc_version}")
set(CPACK_PACKAGE_VERSION_MAJOR "${QPID_VERSION_MAJOR}")
set(CPACK_PACKAGE_VERSION_MINOR "${QPID_VERSION_MINOR}")
set(CPACK_PACKAGE_VERSION_PATCH "0")
set(CPACK_PACKAGE_INSTALL_DIRECTORY "qpidc-${qpidc_version}")

# Add custom target for docs since we don't include a cmake file there directly.
add_custom_target(docs)

# uninstall target
configure_file(
    "${CMAKE_CURRENT_SOURCE_DIR}/cmake_uninstall.cmake.in"
    "${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake"
    IMMEDIATE @ONLY)

add_custom_target(uninstall
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_BINARY_DIR}/cmake_uninstall.cmake)

# Define windows versions and library helpers
include (src/msvc.cmake)

if (CMAKE_CXX_COMPILER_ID STREQUAL GNU)
  # Warnings: Enable as many as possible, keep the code clean. Please
  # do not disable warnings or remove -Werror without discussing on
  # qpid-dev list.
  #
  # The following warnings are deliberately omitted, they warn on valid code.
  # -Wunreachable-code -Wpadded -Winline
  # -Wshadow - warns about boost headers.
  set (WARNING_FLAGS
     "-pedantic -Wall -Wextra -Wno-shadow -Wpointer-arith -Wcast-qual -Wcast-align -Wno-long-long -Wvolatile-register-var -Winvalid-pch -Wno-system-headers -Woverloaded-virtual -Wno-deprecated-declarations")
  set (WARNING_ERROR "-Werror")

  if (CMAKE_CXX_COMPILER_VERSION VERSION_GREATER 8)
    set(WARNING_FLAGS "${WARNING_FLAGS} -Wno-error=cast-function-type")
  endif()

  set (CATCH_UNDEFINED "-Wl,--no-undefined")
  # gcc on SunOS uses native linker whose "-z defs" is too fussy
  if (CMAKE_SYSTEM_NAME STREQUAL SunOS)
    set (CATCH_UNDEFINED "")
  endif (CMAKE_SYSTEM_NAME STREQUAL SunOS)

  set (NOSTRICT_ALIASING "-fno-strict-aliasing")
  set (COMPILER_FLAGS "-fvisibility-inlines-hidden")
  # gcc 4.1.2 on RHEL 5 needs -Wno-attributes to avoid an error that's fixed
  # in later gcc versions.
  execute_process(COMMAND ${CMAKE_CXX_COMPILER} -dumpversion
                   OUTPUT_VARIABLE GCC_VERSION)
  if (GCC_VERSION VERSION_EQUAL 4.1.2)
    message (STATUS "Cannot restrict library symbol export on gcc 4.1.2")
    set (HIDE_SYMBOL_FLAGS "-fno-visibility-inlines-hidden")
  else (GCC_VERSION VERSION_EQUAL 4.1.2)
    set (HIDE_SYMBOL_FLAGS "-fno-visibility-inlines-hidden -fvisibility=hidden")
    set (QPID_LINKMAP ${CMAKE_CURRENT_SOURCE_DIR}/src/qpid.linkmap)
    set (LINK_VERSION_SCRIPT_FLAG "-Wl,--version-script=${QPID_LINKMAP}")
  endif (GCC_VERSION VERSION_EQUAL 4.1.2)

  if (NOT CMAKE_SYSTEM_NAME STREQUAL Windows)
    add_definitions(-pthread)
    set (CMAKE_EXE_LINKER_FLAGS "${CMAKE_EXE_LINKER_FLAGS} -pthread")
    set (CMAKE_SHARED_LINKER_FLAGS "${CMAKE_SHARED_LINKER_FLAGS} ${CATCH_UNDEFINED} -pthread")
    set (CMAKE_MODULE_LINKER_FLAGS "${CMAKE_MODULE_LINKER_FLAGS} ${CATCH_UNDEFINED} -pthread")
  endif (NOT CMAKE_SYSTEM_NAME STREQUAL Windows)
endif (CMAKE_CXX_COMPILER_ID STREQUAL GNU)

if (CMAKE_CXX_COMPILER_ID STREQUAL SunPro)
  set (COMPILER_FLAGS "-library=stlport4 -mt")
  set (WARNING_FLAGS "+w")
  set (CATCH_UNDEFINED "")
  set (HIDE_SYMBOL_FLAGS "")
endif (CMAKE_CXX_COMPILER_ID STREQUAL SunPro)

# XL is IBM XL C/C++
if (CMAKE_CXX_COMPILER_ID MATCHES XL)
  set (COMPILER_FLAGS "-qtls -qrtti")
endif (CMAKE_CXX_COMPILER_ID MATCHES XL)

if (CMAKE_SYSTEM_NAME STREQUAL Windows)
  # Allow MSVC user to select 'WinXP-SP3/Windows Server 2003' as build target version
  set (win32_winnt_default OFF)
  if (MSVC)
    set (win32_winnt_default ON)
  endif (MSVC)
  option(SET_WIN32_WINNT "In Windows-MSVC build: define _WIN32_WINNT=0x0502 to select target version: Windows XP with SP3" ${win32_winnt_default})
endif (CMAKE_SYSTEM_NAME STREQUAL Windows)

if (MSVC)
  add_definitions(
    /D "_CRT_NONSTDC_NO_WARNINGS"
    /D "NOMINMAX"
    /D "WIN32_LEAN_AND_MEAN"
    /wd4244
    /wd4800
    /wd4355
    /wd4267
  )

  if (SET_WIN32_WINNT)
    add_definitions(/D "_WIN32_WINNT=0x0502")
  endif (SET_WIN32_WINNT)

  # set the RelWithDebInfo compile/link switches to equal Release
  set (CMAKE_CXX_FLAGS_RELWITHDEBINFO "/MD /O2 /Ob2 /D NDEBUG")
  set (CMAKE_SHARED_LINKER_FLAGS_RELWITHDEBINFO "/debug /INCREMENTAL:NO")

  if (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/bindings/qpid/dotnet/src)
    # Set the windows version for the .NET Binding cpp project
    file(TO_CMAKE_PATH "${CMAKE_CURRENT_BINARY_DIR}/src/windows/resources" DOTNET_src)
    file(TO_CMAKE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/bindings/qpid/dotnet/src/resource1.h" DOTNET_tgt)
    file(RELATIVE_PATH DOTNET_relPathToResource ${DOTNET_src} ${DOTNET_tgt})
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/qpid/dotnet/src/org.apache.qpid.messaging.template.rc
                   ${CMAKE_CURRENT_BINARY_DIR}/src/windows/resources/org.apache.qpid.messaging.rc)
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/qpid/dotnet/src/AssemblyInfo-template.cpp
                   ${CMAKE_CURRENT_BINARY_DIR}/src/windows/generated_src/AssemblyInfo.cpp)
    # Set the windows version for the .NET Binding sessionreceiver project
    configure_file(${CMAKE_CURRENT_SOURCE_DIR}/bindings/qpid/dotnet/src/sessionreceiver/Properties/sessionreceiver-AssemblyInfo-template.cs
                   ${CMAKE_CURRENT_BINARY_DIR}/src/windows/generated_src/sessionreceiver-AssemblyInfo.cs)
  endif (EXISTS ${CMAKE_CURRENT_SOURCE_DIR}/bindings/qpid/dotnet/src)
endif (MSVC)

# Subdirectories
add_subdirectory(management/python)
add_subdirectory(managementgen)
add_subdirectory(src)
add_subdirectory(etc)
add_subdirectory(bindings)
add_subdirectory(docs/api)
add_subdirectory(docs/man)
add_subdirectory(examples)

include (CPack)
