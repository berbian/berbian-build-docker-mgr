#!/bin/bash


TOOL_NOM='berbian-build-docker-mgr'
TOOL_VERSIO='0.1.1'
TOOL_BRANCA='devel'

# Not used yet by this script:
# VERSIO_SCRIPTS_SHARED_FUNCS="021"

# Upstream-Name: berbian-build-docker-mgr
# Source: https://github.com/berbian/berbian-build-docker-mgr
  ## Script that manages docker containers with different build environments.
  ## Fork of Berbascum's "berb-droidian-kernel-build-docker-mgr" script, that was Droidian specific. The old one is abandoned at version 0.0.3.

# Copyright (C) 2022 Berbascum <berbascum@ticv.cat>
# All rights reserved.

# BSD 3-Clause License
#
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
  # To do:
    # Add cmd params support
    # Before compiling, script asks for remove out dir?


  # v_0.1.1: Renamed from "berb-droidian-kernel-build-docker-mgr" to "berbian-build-docker-mgr"
  
  # v_0.0.3: Renamed from "droidian-manage-docker-container to "berb-droidian-kernel-build-docker-mgr"
    # New: fn_configura_sudo
    # New: fn_configura_build_env
    # New: Implemented kernel path auto detection
    # New: fn_verificacions_path: Basic check to determine if start dir a kernel source root dir.
    # New: fn_create_outputs_backup: After compilation, script archives most output relevant files and archive them to tar.gz
    # New: fn_remove_container
    # Conf: Add net-tools to apt depends
    # Fix: docker image name for new container creation.
    # 

  # v_0.0.2-1
    # New: fn_ip_forward_activa

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

  # v_0.0.0
    # Starting version. Just create a conbtainer from Droidian build-essential image.
    

####################
## Configurations ##
####################
fn_configura_sudo() {
	if [ "$USER" != "root" ]; then SUDO='sudo'; fi
}

fn_verificacions_path() {
	DIR_INICIAL=$(pwd)
	# Cerca un aerxiu README de linux kernel
	if [ ! "$DIR_INICIAL/README" ]; then
		echo && echo "README file not found in current dir. Please launch this tool from the kernel sources root dir."
		echo
		exit 1
	else
		ES_KERNEL=$(cat $DIR_INICIAL/README | head -n 1 | grep -c "Linux kernel")
		if [ "$ES_KERNEL" -eq '0' ]; then
			echo && echo "No Linux kernel README file not found in current dir. Please launch this tool from the kernel sources root dir."
			echo
			exit 1
		fi
	fi
	## Cerca un arxiu Makefile
	if [ ! -f "$DIR_INICIAL/Makefile" ]; then
		echo && echo "Makefile not found in current dir. Please launch this tool from the kernel sources root dir."
		echo
		exit 1
	fi
}

fn_configura_build_env() {
	## get kernel info
	KERNEL_NOM=$(echo $DIR_INICIAL | awk -F'/' '{print $NF}')
		cd ..
	SOURCES_PATH=$(pwd)
		cd $DIR_INICIAL
	## kernel paths
	KERNEL_DIR="$DIR_INICIAL"
	KERNEL_INFO_MK="$KERNEL_DIR/debian/kernel-info.mk"
	## Set kernel build output paths
	KERNEL_BUILD_OUT_KOBJ_PATH="$KERNEL_DIR/out/KERNEL_OBJ"
	PACKAGES_DIR="$SOURCES_PATH/out-$KERNEL_NOM"
	KERNEL_BUILD_OUT_DEBS_PATH="$PACKAGES_DIR/debs"
	KERNEL_BUILD_OUT_DEBIAN_PATH="$PACKAGES_DIR/debian"
	KERNEL_BUILD_OUT_LOGS_PATH="$PACKAGES_DIR/logs"
	KERNEL_BUILD_OUT_OTHER_PATH="$PACKAGES_DIR/other"
	## Create kernel build output dirs
  	[ -d "$PACKAGES_DIR" ] || mkdir $PACKAGES_DIR
  	[ -d "$KERNEL_BUILD_OUT_DEBS_PATH" ] || mkdir $KERNEL_BUILD_OUT_DEBS_PATH
  	[ -d "$KERNEL_BUILD_OUT_DEBIAN_PATH" ] || mkdir $KERNEL_BUILD_OUT_DEBIAN_PATH
  	[ -d "$KERNEL_BUILD_OUT_LOGS_PATH" ] || mkdir $KERNEL_BUILD_OUT_LOGS_PATH
  	[ -d "$KERNEL_BUILD_OUT_OTHER_PATH" ] || mkdir $KERNEL_BUILD_OUT_OTHER_PATH
	## Kernel Info constants
	KERNEL_BASE_VERSION=$(cat $KERNEL_INFO_MK | grep 'KERNEL_BASE_VERSION' | awk -F' = ' '{print $2}')
	DEVICE_DEFCONFIG_FILE=$(cat $KERNEL_INFO_MK | grep 'KERNEL_DEFCONFIG' | awk -F' = ' '{print $2}')
	DEVICE_VENDOR==$(cat $KERNEL_INFO_MK | grep 'DEVICE_VENDOR' | awk -F' = ' '{print $2}')
	DEVICE_MODEL==$(cat $KERNEL_INFO_MK | grep 'DEVICE_MODEL' | awk -F' = ' '{print $2}')
	DEVICE_ARCH==$(cat $KERNEL_INFO_MK | grep 'KERNEL_ARCH' | awk -F' = ' '{print $2}')
	## Backups info
	BACKUP_FILE_NOM="Backup-kernel-build-outputs-$KERNEL_NOM.tar.gz"
	## Prints kernel paths
	echo && "Config defined:"
	echo && echo "KERNEL_NOM $KERNEL_NOM"
	echo "KERNEL_BASE_VERSION = $KERNEL_BASE_VERSION"
	echo "KERNEL_DIR = $KERNEL_DIR"
	echo "DEVICE_DEFCONFIG_FILE = $DEVICE_DEFCONFIG_FILE"
	echo "KERNEL_BUILD_OUT_KOBJ_PATH =$KERNEL_BUILD_OUT_KOBJ_PATH"
	echo "PACKAGES_DIR = $PACKAGES_DIR"
	echo "KERNEL_BUILD_OUT_DEBS_PATH = $KERNEL_BUILD_OUT_DEBS_PATH"
	echo "KERNEL_BUILD_OUT_DEBIAN_PATH = $KERNEL_BUILD_OUT_DEBIAN_PATH"
	echo "KERNEL_BUILD_OUT_LOGS_PATH = $KERNEL_BUILD_OUT_LOGS_PATH"
	echo "KERNEL_BUILD_OUT_OTHER_PATH = $KERNEL_BUILD_OUT_OTHER_PATH"
	echo "DEVICE_VENDOR = $DEVICE_VENDOR"
	echo "DEVICE_MODEL = $DEVICE_MODEL"
	echo "DEVICE_ARCH = $DEVICE_ARCH"
	read -p "Continue..."

	## Depends  ## To do: Get deps from kernel-info.mk
	APT_INSTALL_DEPS="net-tools vim locate git linux-packaging-snippets linux-initramfs-halium-generic:arm64 binutils-aarch64-linux-gnu \
	clang-android-6.0-4691093 android-sdk-ufdt-tests avbtool bc binutils-gcc4.9-aarch64-linux-android bison \
	cpio device-tree-compiler flex 	kmod libfdt1 libkmod2 libpcre3 libpython2-stdlib libpython2.7-minimal libpython2.7-stdlib libssl-dev \
	libyaml-0-2 linux-initramfs-halium-generic mkbootimg mkdtboimg python2 python2-minimal python2.7 python2.7-minimal \
	gcc-4.9-aarch64-linux-android g++-4.9-aarch64-linux-android libgcc-4.9-dev-aarch64-linux-android-cross"
	# clang-android-10.0-r370808 
	## Docker constants
	DEFAULT_CONTAINER_NAME='droidian-build-env'
	CONTAINER_NAME="$DEFAULT_CONTAINER_NAME"
	CONTAINER_COMMITED_NAME='droidian-build-env-custom'
	IMAGE_BASE_NAME='quay.io/droidian/build-essential:bookworm-amd64'
	IMAGE_BASE_TAG='bookworm-amd64'
	IMAGE_COMMIT_NAME='custom/build-essential'
	IMAGE_COMMIT_TAG='bookworm-amd64'
}

######################
## Config functions ##
######################
fn_ip_forward_activa() {
	## Activa ipv4_forward (requerit per xarxa containers) i reinicia docker.
	## És la primera funció que crida l'script
	FORWARD_ES_ACTIVAT=$(cat /proc/sys/net/ipv4/ip_forward)
	if [ "$FORWARD_ES_ACTIVAT" -eq "0" ]; then
		echo "" && echo "Activant ip4_forward..."
		sysctl -w net.ipv4.ip_forward=1
		systemctl restart docker
	else
		echo && echo "ip4_forward prèviament activat!"
	fi

}
fn_action_prompt() {
## Function to get a action
	echo && echo "Action is required:"
	echo && echo " 1 - Create container"
	echo " 2 - Remove container"
	echo && echo " 3 - Install build env from apt. OPTIONAL"
	echo && echo " 4 - Start container"
	echo " 5 - Stop container"
	echo && echo " 6 - Commit container:"
        echo "     Commits current container state."
        echo "     Then creates new container from the commit."
        echo "     Script permanent sets new container as default."
	echo "     ## Actually only support 1 existing commit at same time!"
	echo && echo " 7 - Shell to container"
#	echo " 8 - Command to container" # only internal use
#	echo echo " 9 - Setup build env. OPTIONAL Implies option 3."
	echo && echo "10 - Build kernel on container"
	echo && echo "11 - Backup kernel build output relevant files"
	echo && read -p "Input an option: " OPTION
	case $OPTION in
		1)
			ACTION="create"
			;;
		2)
			ACTION="remove"
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
#		8)
#			ACTION="command-to"
#			;;
#		9)
#			ACTION="setup-build-env"
#			;;
		10)
			ACTION="build-kernel-on-container"
			;;
		11)
			ACTION="create-outputs-backup"
			;;
		*)
			echo "" && echo "Option not implemented!" && exit 1
			;;
	esac
}

fn_install_apt_deps() {
	APT_UPDATE="apt-get update"
        APT_INSTALL="apt-get install $APT_INSTALL_DEPS -y"
	export CMD="$APT_UPDATE" && fn_cmd_on_container
	export CMD="$APT_INSTALL" && fn_cmd_on_container
}
fn_setup_build_env() {
	echo && echo "To do."
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
			IMAGE_NAME="$IMAGE_BASE_NAME"
		fi
		$SUDO docker -v create --name $CONTAINER_NAME -v $PACKAGES_DIR:/buildd \
			-v $KERNEL_DIR:/buildd/sources -i -t "$IMAGE_NAME"
	else
		echo && echo "Container already exists!" && exit 4
	fi
}
fn_remove_container() {
# Removes a the container
	CONTAINER_EXIST=$(docker ps -a | grep -c "$CONTAINER_NAME")
	CONTAINER_ID=$(docker ps -a | grep "$CONTAINER_NAME" | awk '{print $1}')
	if [ "$CONTAINER_EXIST" -eq '0' ]; then
		echo && echo "Container $CONTAINER_NAME not exists..."
		echo
	else
		echo && read -p "SURE to REMOVE container $CONTAINER_NAME [ yes | any-word ] ? " RM_CONT
	fi
	if [ "$RM_CONT" == "yes" ]; then
		echo && echo "Removing container..."
		fn_stop_container
		docker rm $CONTAINER_ID
	else
		echo && echo "Container $CONTAINER_NAME will NOT be removed as user choice"
		echo
	fi
}
fn_set_container_commit_if_exists() {
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
		$SUDO docker start $CONTAINER_NAME
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
		echo && echo "Creation of more than 1 commit is not supported."
		echo "You can change the consts IMAGE_COMMIT_NAME and CONTAINER_COMMITED_NAME values with a new name."
		echo "After run script again a new commit will be created."
		echo
		exit 3
	fi
	fn_get_default_container_id
	# Commit creation
	echo && echo "Creating commit \"$IMAGE_COMMIT_NAME\"..."
	echo "Please be patient!!!"
	docker commit $DEFAULT_CONT_ID $IMAGE_COMMIT_NAME
	echo && echo "Stoping original container..."
	docker stop $DEFAULT_CONTAINER_NAME
	# Set container commit name as current container
	CONTAINER_NAME="$CONTAINER_COMMITED_NAME"
	# Create new container from commit image.
	echo && echo "Creating new container from te commit..."
	fn_create_container
	echo && echo Creation of the new commit and container with the current state is finished!
	echo
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
fn_build_kernel_on_container() {
	[ -d "$PACKAGES_DIR" ] || mkdir $PACKAGES_DIR
	# Script creation to launch compilation inside the container.
	echo '#!/bin/bash' > $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export PATH=/proton-clang-11/bin:$PATH" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export R=llvm-ar" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export NM=llvm-nm" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export OBJCOPY=llvm-objcopy" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export OBJDUMP=llvm-objdump" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export STRIP=llvm-strip" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export CC=clang" >> $KERNEL_DIR/compile-droidian-kernel.sh
	#echo "export CROSS_COMPILE=aarch64-linux-gnu-" >> $KERNEL_DIR/compile-droidian-kernel.sh
	
	echo "export TOOLCHAINS_PATH='/buildd/sources/toolchains/android-ndk/toolchains'" >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "export CROSS_32_PATH=\"\$TOOLCHAINS_PATH/arm-linux-androideabi-4.9/prebuilt/linux-x86_64\""  >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "export PATH=\"\$CROSS_32_PATH:\$CROSS_32_PATH/bin:\$PATH\""  >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "export CROSS_COMPILE_ARM32='arm-linux-androideabi-'"  >> $KERNEL_DIR/compile-droidian-kernel.sh

	echo 'chmod +x /buildd/sources/debian/rules' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'cd /buildd/sources' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'rm -f debian/control' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'debian/rules debian/control' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo 'RELENG_HOST_ARCH="arm64" releng-build-package' >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "if [ \"\$?\" -eq '0' ]; then" >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "		echo  && echo "Compilation finished." && echo" >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "else" >> $KERNEL_DIR/compile-droidian-kernel.sh 
	echo "		echo  && echo "Compilation failed." && echo" >> $KERNEL_DIR/compile-droidian-kernel.sh
	echo "fi" >> $KERNEL_DIR/compile-droidian-kernel.sh
	chmod u+x $KERNEL_DIR/compile-droidian-kernel.sh
	vim $KERNEL_DIR/compile-droidian-kernel.sh
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
# fn_create_outputs_backup
}

fn_create_outputs_backup() {
	## Moving output deb files to $PACKAGES_DIR/debs
	echo && echo Moving output deb files to $KERNEL_BUILD_OUT_DEBS_PATH
	mv $PACKAGES_DIR/*.deb $KERNEL_BUILD_OUT_DEBS_PATH

	## Moving output log files to $PACKAGES_DIR/logs
	echo && echo Moving output log files to $KERNEL_BUILD_OUT_LOGS_PATH
	mv $PACKAGES_DIR/*.build* $KERNEL_BUILD_OUT_LOGS_PATH

	## Copyng out/KERNL_OBJ relevant files to $PACKAGES_DIR/other..."
	arr_OUT_DIR_FILES=( \
		'boot.img' 'dtbo.img' 'initramfs.gz' 'recovery*' 'target-dtb' 'vbmeta.img' 'arch/arm64/boot/Image.gz' \
		)
	echo && echo "Copyng out/KERNL_OBJ relevant files to $PACKAGES_DIR/other..."
	cd $KERNEL_BUILD_OUT_KOBJ_PATH
	for i in ${arr_OUT_DIR_FILES[@]}; do
		cp -a $i $KERNEL_BUILD_OUT_OTHER_PATH
	done
	cd $DIR_INICIAL

	## Copyng device defconfig file to PACKAGES_DIR..."
	echo && echo " Copyng $DEVICE_DEFCONFIG_FILE file to $PACKAGES_DIR..."
	cp -a "arch/$DEVICE_ARCH/configs/$DEVICE_DEFCONFIG_FILE" $PACKAGES_DIR
	
	## Copyng debian dir to final outputs dir..."
	arr_DEBIAN_FILES=( \
		'debian/copyright' 'debian/compat' 'debian/kernel-info.mk' 'debian/rules' 'debian/source' 'debian/initramfs-overlay'  \
		)
	echo && echo "Copying debian dir to $KERNEL_BUILD_OUT_DEBS_PATH..."
	cp -a debian/* $KERNEL_BUILD_OUT_DEBS_PATH/
	for i in ${arr_DEBIAN_FILES[@]}; do
		cp -a $KERNEL_BUILD_OUT_DEBS_PATH/$i debian/
	done
	## Make a tar.gz from PACKAGES_DIR
	echo && echo "Creating $BACKUP_FILE_NOM from $PACKAGES_DIR"
	cd $SOURCES_PATH
	tar zcvf $BACKUP_FILE_NOM $PACKAGES_DIR
	if [ "$?" -eq '0' ]; then
		echo && echo "Backup $BACKUP_FILE_NOM created on the parent dir"
	else
		echo && echo "Backup $BACKUP_FILE_NOM failed!!!"
	fi
	cd $DIR_INICIAL
}

############################
## Start script execution ##
############################
## Configuration
fn_ip_forward_activa
fn_configura_sudo
fn_verificacions_path
fn_configura_build_env
fn_action_prompt
fn_set_container_commit_if_exists
echo

## Execute action on container name
if [ "$ACTION" == "create" ]; then
	fn_create_container
elif [ "$ACTION" == "remove" ]; then
	fn_remove_container
elif [ "$ACTION" == "start" ]; then
	fn_start_container
elif [ "$ACTION" == "stop" ]; then
	fn_stop_container
elif [ "$ACTION" == "shell-to" ]; then
	fn_shell_to_container
#elif [ "$ACTION" == "command-to" ]; then
#	fn_cmd_on_container
#elif [ "$ACTION" == "setup-build-env" ]; then
#	fn_configura_build_env
elif [ "$ACTION" == "install-apt-deps" ]; then
	fn_install_apt_deps
elif [ "$ACTION" == "commit-container" ]; then
	fn_commit_container
elif [ "$ACTION" == "build-kernel-on-container" ]; then
	fn_build_kernel_on_container
elif [ "$ACTION" == "create-outputs-backup" ]; then
	fn_create_outputs_backup
else
	echo "SCRIPT END: Action not implemented."
fi

