#!/bin/bash
#
# Copyright (c) 2019 Stephan Linz, linz@li-pro.net
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#
# Refer to:
#   https://docs.armbian.com/#supported-chips
#   https://docs.armbian.com/board_details/odroidc2/
#   https://www.armbian.com/odroid-c2/
#   https://wiki.odroid.com/odroid-c2/odroid-c2
#   https://dn.odroid.com/S905/
#
# ----------------------------------------------------------------------------
export LANG=""
exec ./compile.sh docker \
	BOARD=odroidc2 \
	BRANCH=dev \
	RELEASE=bionic \
	BUILD_DESKTOP=no \
	KERNEL_ONLY=no \
	KERNEL_CONFIGURE=no
