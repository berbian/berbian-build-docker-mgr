#!/bin/bash

## VARS PATHS
KERNEL_BASE_PATH="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources"

KERNEL_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/kernel-xiaomi-lavender"

PACKAGES_DIR="./Droidian/kernel/lavender/sources/droidian-lavender-4.4.192-2022-sources/compilat"

OLD_CONF_FILE="./Droidian/kernel/lavender/Config-Files/config_kernel_lavender_halium_original_BO"

## Accedint al dir dels kernel sources
cd $KERNEL_DIR

## Seleccionar branca bookworm
#git checkout -b bookworm

## oldconfig
#cp $OLD_CONF_FILE $KERNEL_DIR
#make olddefconfig

## Copia script build dins de Docker
cp -av $KERNEL_BASE_PATH/docker-build-kernel.sh $KERNEL_DIR
#cp -av $KERNEL_BASE_PATH/kernel-snippet-DEBUG.mk $KERNEL_DIR

## Inicia Docker instal·lant el build-essential de droidian si no hi és.
docker run --rm -v $PACKAGES_DIR:/buildd -v $KERNEL_DIR:/buildd/sources -it quay.io/droidian/build-essential:bookworm-amd64 bash
## amb --rm elimina el contenidor si existeix prèviament
#docker run --rm -v $PACKAGES_DIR:/buildd -v $KERNEL_DIR:/buildd/sources -it quay.io/droidian/build-essential:bookworm-amd64 bash

