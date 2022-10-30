#!/bin/bash

# berb-droidian-kernel-build-docker-mgr
# Script that manages a custom docker container with Droidian build environment
# Version 0.0.1
# Branch develop

# Copyright (C) 2022 Berbasc
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#    * Redistributions of source code must retain the above copyright
#      notice, this list of conditions and the following disclaimer.
#    * Redistributions in binary form must reproduce the above copyright
#      notice, this list of conditions and the following disclaimer in the
#      documentation and/or other materials provided with the distribution.
#    * Neither the name of the <organization> nor the
#      names of its contributors may be used to endorse or promote products
#      derived from this software without specific prior written permission.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL <COPYRIGHT HOLDER> BE LIABLE FOR ANY
# DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

# Features:
  # Create container: Create containes from quay.io/droidian/build-essential:bookworm-amd64 docker image
  # Basic container management
  # Open a bash shell inside container
  # Commit container: Create a new image with the custom modifications, and create a neu container from it.
    # Only one commit is implemented.
  # Install build env dependences with apt-get
  # Custom configurations on container: To do.

####################
## Configurqtions ##
####################
## Path cons
KERNEL_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/kernel-xiaomi-lavender/"
PACKAGES_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/compilat/"

## Depends  ## To do: Get deps from kernel-info.mk
APT_INSTALL_DEPS="vim linux-packaging-snippets linux-initramfs-halium-generic:arm64 binutils-aarch64-linux-gnu \
	clang-android-6.0-4691093 gcc-4.9-aarch64-linux-android g++-4.9-aarch64-linux-android \
	libgcc-4.9-dev-aarch64-linux-android-cross"

## Docker cons
DEFAULT_CONTAINER_NAME='droidian-build-env'
CONTAINER_NAME="$DEFAULT_CONTAINER_NAME"
CONTAINER_COMMITED_NAME="droidian-build-env-custom"
IMAGE_COMMIT_NAME="droidian-build-env-custom"


#######################
## Config functions  ##
#######################
## Function to get a action
fn_action_prompt() {
	echo "" && echo "Action ir required:"
	echo "" && echo "1 - Create container"
	echo "2 - Setup build env. OPTIONAL Implies option 3."
	echo "3 - Install build env from apt. OPTIONAL"
	echo "" && echo "4 - Start container"
	echo "5 - Stop container"
	echo "6 - Commit container # Actually only support 1 commit"
	echo "" && echo "7 - Shell to container"
	# echo "" && echo "8 - Command to container" # only internal use
	echo "" && read -p "Input an option: " OPTION
	case $OPTION in
		1)
			ACTION="create"
			;;
		2)
			ACTION="setup-build-env"
			;;
		3)
			ACTION="install-apt-deps"
			;;
		4)
			ACTION="start"
			;;
		5)
			ACTION="stop"
			;;
		6)
			ACTION="commit-container"
			;;
		7)
			ACTION="shell-to"
			;;
		*)
			echo "" && echo "Option not implemented!" && exit 1
			;;
	esac
}
## Function to scan for a valid global paths
fn_set_global_paths() {
	# Scan const KERNEL_DIR
	if [ -z "$KERNEL_DIR" ]; then
		echo "" && echo "KERNEL_DIR const is not defined. You can set it in this script."
		echo "" && read -p "Enter the absolute path to your kernel source root dir: " KERNEL_DIR
		if [ ! -d "$KERNEL_DIR" ]; then echo "Dir $KERNEL_DIR not exist!" && exit 2; fi

	fi
	# Scan const PACKAGES_DIR
	if [ -z "$PACKAGES_DIR" ]; then
		echo "" && echo "PACKAGES_DIR const is not defined. You can set it in this script."
       		echo "" && read -p "Enter absolute path you want to output dir for deb packages: " PACKAGES_DIR
		if [ ! -d "$PACKAGES_DIR" ]; then echo "Dir $PACKAGES_DIR not exist!" && exit 2; fi
	fi
}
fn_install_apt_deps() {
	APT_UPDATE="apt-get update"
        APT_INSTALL="apt-get install $APT_INSTALL_DEPS -y"
	export CMD="$APT_UPDATE" && fn_cmd_on_container
	export CMD="$APT_INSTALL" && fn_cmd_on_container
}
fn_setup_build_env() {
	echo "To do."
}

######################
## Docker functions ##
######################
fn_create_container() {
# Creates the container
	CONTAINER_EXISTS=$(docker ps -a | grep -c $CONTAINER_NAME)
	if [ "$CONTAINER_EXISTS" -eq "0" ]; then
		docker -v create --name $CONTAINER_NAME -v $PACKAGES_DIR:/buildd -v $KERNEL_DIR:/buildd/sources \
			-i -t quay.io/droidian/build-essential:bookworm-amd64
	else
		echo "" && echo "Container already exists!" && exit 4
	fi
}
fn_set_commit_if_exists() {
	COMMIT_EXISTS=$(docker images -a | grep -c $IMAGE_COMMIT_NAME)
	if [ "$COMMIT_EXISTS" -eq "1" ]; then
		echo "" && echo "Setting detected commit as default container..."
		CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
	fi
}
fn_start_container() {
	IS_STARTED=$(docker ps -a | grep $CONTAINER_NAME | awk '{print $5}' | grep -c 'Up')
	if [ "$IS_STARTED" -eq "0" ]; then
		docker start $CONTAINER_NAME
	fi
}
fn_stop_container() {
	docker stop $CONTAINER_NAME
}
fn_shell_to_container() {
	docker exec -it $CONTAINER_NAME bash
}
fn_cmd_on_container() {
	docker exec -it $CONTAINER_NAME $CMD
}
fn_commit_container() {
	if [ "$CONTAINER_NAME" == "droidian-build-env-custom" ]; then
		echo "" && echo "Creation of more than 1 commit is not supported."
		echo "You can change the consts IMAGE_COMMIT_NAME and CONTAINER_COMMITED_NAME values with a new name."
		echo "After run script again a new commit will be created."
		echo ""
		exit 3
	fi
	docker commit $DEFAULT_CONTAINER_NAME $IMAGE_COMMIT_NAME
	docker stop $DEFAULT_CONTAINER_NAME
	# Set container commit name as current container
	CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
	# Create new container from commit image.
	fn_create_container
}
############################
## Start script execution ##
############################
## Configuration
fn_action_prompt
fn_set_global_paths
	#echo "KERNEL_DIR = $KERNEL_DIR"
	#echo "PACKAGES_DIR = $PACKAGES_DIR"
fn_set_commit_if_exists

## Execute action on container name
if [ "$ACTION" == "create" ]; then
	fn_create_container
elif [ "$ACTION" == "start" ]; then
	fn_start_container
elif [ "$ACTION" == "stop" ]; then
	fn_stop_container
elif [ "$ACTION" == "shell-to" ]; then
	fn_shell_to_container
elif [ "$ACTION" == "setup-build-env" ]; then
	fn_setup_build_env
elif [ "$ACTION" == "install-apt-deps" ]; then
	fn_install_apt_deps
elif [ "$ACTION" == "commit-container" ]; then
	fn_commit_container
fi



