#!/bin/bash

# Define building variables
TF_VERSION=2.0.0a0-gpu-py3
USER_PASS=*****
JUPYTER_PASS=*****

# Build
docker build \
	-t dbuades/tensorflow:$TF_VERSION \
	--build-arg VERSION=$TF_VERSION \
	--build-arg UNAME="$(id -un)" \
	--build-arg UPWD=$USER_PASS \
	--build-arg UID="$(id -u)" \
	--build-arg GID="$(id -g)" \
	--build-arg JUPYTER_PWD="$(python -c "from hash_pass import hash_pass; print(hash_pass('$JUPYTER_PASS'))")" \
	--build-arg SSH_PUB_KEY="$(cat ~/.ssh/id_rsa.pub)" \
	--build-arg SSH_PORT="2222" .
