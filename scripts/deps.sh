#!/usr/bin/bash

sudo dnf install -y git git-core make mock rpmdevtools
sudo dnf upgrade kernel
echo "kernel upgraded, you must reboot your machine so new kernel runs"
