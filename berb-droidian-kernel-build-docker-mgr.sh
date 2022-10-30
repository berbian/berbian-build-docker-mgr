#!/bin/bash

## berb-droidian-kernel-build-docker-mgr
## Script that manages a custom docker container with Droidian build environment
## Version 0.0.2
## Branch develop

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

################
## Changelog: ##
################
  # v_next
    # Add cmd params support
  # v_0.0.2
    # Added build-kernel-on-container feature 
      # Before compiling, script asks for remove out dir.
    # Added feature to enable/disable download build deps in kernel-info.mk
    # Improvements in commit_container function.
  # v_0.0.1
   # Features:
    # Create container: Create container from docker image:
      # quay.io/droidian/build-essential:bookworm-amd64
    # Basic container management
    # Open a bash shell inside container
    # Commit container:
      # Creates a new image with custom modifications, and 
      # Then creates a new container from it.
      # Only one commit is implemented.
    # Install build env dependences with apt-get
    # Custom configurations on container: To do.

####################
## Configurations ##
####################
## Path cons
KERNEL_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/kernel-xiaomi-lavender"
PACKAGES_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/compilat"
KERNEL_CONFIG_FILE_DEBIAN="$KERNEL_DIR/debian/kernel-info.mk"

## Depends  ## To do: Get deps from kernel-info.mk
APT_INSTALL_DEPS="net-tools vim linux-packaging-snippets linux-initramfs-halium-generic:arm64 binutils-aarch64-linux-gnu \
	clang-android-6.0-4691093 gcc-4.9-aarch64-linux-android g++-4.9-aarch64-linux-android \
	libgcc-4.9-dev-aarch64-linux-android-cross"

## Docker cons
DEFAULT_CONTAINER_NAME='droidian-build-env'
CONTAINER_NAME="$DEFAULT_CONTAINER_NAME"
CONTAINER_COMMITED_NAME='droidian-build-env-custom'
IMAGE_BASE_NAME='quay.io/droidian/build-essential:bookworm-amd64'
IMAGE_BASE_TAG='bookworm-amd64'
IMAGE_COMMIT_NAME='custom/build-essential'
IMAGE_COMMIT_TAG='bookworm-amd64'

#######################
## Config functions  ##
#######################
## Function to get a action
fn_action_prompt() {
	echo "" && echo "Action is required:"
	echo "" && echo " 1 - Create container"
	echo " 2 - Setup build env. OPTIONAL Implies option 3."
	echo " 3 - Install build env from apt. OPTIONAL"
	echo "" && echo " 4 - Start container"
	echo " 5 - Stop container"
	echo "" && echo " 6 - Commit container:"
        echo "     Commits current container state."
        echo "     Then creates new container from the commit."
        echo "     Script permanent sets new container as default."
	echo "     ## Actually only support 1 existing commit at same time!"
	echo "" && echo " 7 - Shell to container"
	echo "" && echo " 8 - Disable install deps by build script."
	echo " 9 - Enable install deps by build script."
	echo "" && echo "10 - Build kernel on container"
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
		8)
			ACTION="disable-install-deps-on-build"
			;;
		9)
			ACTION="enable-install-deps-on-build"
			;;
		10)
			ACTION="build-kernel-on-container"
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
		if [ "$IS_COMMIT" == "yes" ]; then
			IMAGE_NAME="$IMAGE_COMMIT_NAME:$IMAGE_COMMIT_TAG"
		else
			#IMAGE_NAME="$IMAGE_BASE_NAME:$IMAGE_BASE_TAG"
			IMAGE_NAME="$IMAGE_BASE_NAME"
		fi

		docker -v create --name $CONTAINER_NAME -v $PACKAGES_DIR:/buildd -v $KERNEL_DIR:/buildd/sources -i -t "$IMAGE_NAME"
	else
		echo "" && echo "Container already exists!" && exit 4
	fi
}
fn_set_commit_if_exists() {
	COMMIT_EXISTS=$(docker images -a | grep -c "$IMAGE_COMMIT_NAME")
	if [ "$COMMIT_EXISTS" -eq "1" ]; then
		echo "" && echo "Setting detected commit as default container..."
		CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
		IS_COMMIT='yes'
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
fn_get_default_container_id() {
	# Search for original container id
	DEFAULT_CONT_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
}
fn_commit_container() {
	if [ "$CONTAINER_NAME" == "droidian-build-env-custom" ]; then
		echo "" && echo "Creation of more than 1 commit is not supported."
		echo "You can change the consts IMAGE_COMMIT_NAME and CONTAINER_COMMITED_NAME values with a new name."
		echo "After run script again a new commit will be created."
		echo ""
		exit 3
	fi
	fn_get_default_container_id
	# Commit creation
	echo "" && echo "Creating commit \"$IMAGE_COMMIT_NAME\"..."
	echo "Please be patient!!!"
	docker commit $DEFAULT_CONT_ID $IMAGE_COMMIT_NAME
	echo "" && echo "Stoping original container..."
	docker stop $DEFAULT_CONTAINER_NAME
	# Set container commit name as current container
	CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
	# Create new container from commit image.
	echo "" && echo "Creating new container from te commit..."
	fn_create_container
	echo "" && echo Creation of the new commit and container with the current state is finished!
	echo ""
}
fn_shell_to_container() {
	docker exec -it $CONTAINER_NAME bash
}
fn_cmd_on_container() {
	docker exec -it $CONTAINER_NAME $CMD
}

############################
## Kernel build functions ##
############################
fn_disable_install_deps_on_build() {
	sed --debug -i 's/^DEB_TOOLCHAIN/# DEB_TOOLCHAIN/g' $KERNEL_CONFIG_FILE_DEBIAN
}
fn_enable_install_deps_on_build() {
	sed --debug -i 's/^# DEB_TOOLCHAIN/DEB_TOOLCHAIN/g' $KERNEL_CONFIG_FILE_DEBIAN
}
fn_build_kernel_on_container() {
	# Script creation to launch compilation inside the container.
	echo '#!/bin/bash' > $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'chmod +x /buildd/sources/debian/rules' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'cd /buildd/sources' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'rm -f debian/control' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'debian/rules debian/control' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'RELENG_HOST_ARCH="arm64" releng-build-package' >> $KERNEL_DIR/compile-droidian-kernel.sh
	chmod u+x $KERNEL_DIR/compile-droidian-kernel.sh
	# ask for disable install build deps in debian/kernel.mk if enabled.
	#INSTALL_DEPS_IS_ENABLED=$(grep -c "^DEB_TOOLCHAIN")
	#if [ "$INSTALL_DEPS_IS_ENABLED" -eq "1" ]; then
	#	echo "" && read -p "Want you disable install build deps? Say \"n\" if not sure! y/n:  " OPTION
	#	case $OPTION in
	#		y)
	#			fn_disable_install_deps_on_build
	#			;;
	#	esac
	#fi
	# Build execution command inide container
	docker exec -it $CONTAINER_NAME bash /buildd/sources/compile-droidian-kernel.sh

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
echo ""

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
elif [ "$ACTION" == "build-kernel-on-container" ]; then
	fn_build_kernel_on_container
elif [ "$ACTION" == "disable-install-deps-on-build" ]; then
	fn_disable_install_deps_on_build
elif [ "$ACTION" == "enable-install-deps-on-build" ]; then
	fn_enable_install_deps_on_build
else
	echo "SCRIPT END: Action not implemented."
fi



