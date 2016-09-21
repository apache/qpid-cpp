#!/bin/bash
# Smoke test the management tools with AMQP 1.0 protocol

set -e -x

DIR=$(mktemp -d)
PORT=$(qpidd -dp0 --ha-queue-replication=yes  --auth=no --protocols=amqp1.0 --data-dir $DIR)
trap "qpidd -qp $PORT; rm -rf $DIR" EXIT

qpid-config -b localhost:$PORT add queue test-foo
qpid-stat -b localhost:$PORT -q | grep test-foo

qpid-config -b localhost:$PORT add exchange topic test-ex
qpid-stat -b localhost:$PORT -e | grep test-ex

qpid-config -b localhost:$PORT add queue test-bar
qpid-config -b localhost:$PORT del queue test-bar
{ qpid-stat -b localhost:$PORT -q | grep test-bar; } && { echo not deleted; exit 1; }

qpid-stat -b localhost:$PORT -m | grep malloc_arena
qpid-stat -b localhost:$PORT -g | grep queue-depth
qpid-stat -b localhost:$PORT -c | grep Connections
qpid-stat -b localhost:$PORT -u | grep Subscriptions

qpid-ha -b localhost:$PORT query | grep standalone
qpid-ha -b localhost:$PORT status | grep standalone

qpid-send -b localhost:$PORT -a test-foo --content-string hello
qpid-receive -b localhost:$PORT -a test-foo | grep hello

echo PASS

