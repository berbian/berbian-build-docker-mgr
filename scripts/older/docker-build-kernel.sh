#!/bin/bash

## Entrant al dir del kernel sources
#cd /buildd/sources

## Preparant droidian kernel snippets
apt-get update
apt-get install linux-packaging-snippets
  # Sobrescriu kernel-snipet.mk amb info de debug
    # Es crearà arxiu ./out//kkrtts_vars_pre_mkbootimg.txt
#  cat kernel-snippet-DEBUG.mk > /usr/share/linux-packaging-snippets/kernel-snippet.mk

## Regenerant debian/control
cd /buildd/sources
chmod +x /buildd/sources/debian/rules
rm -f /buildd/sources/debian/control
/buildd/sources/debian/rules /buildd/sources/debian/control

# Iniciar compilació baixant entorn si no hi és:
RELENG_HOST_ARCH="arm64" releng-build-package
