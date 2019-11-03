#!/bin/bash
#
# Copyright (c) 2017-2019 Stephan Linz, linz@li-pro.net
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#
# Refer to:
#   https://docs.armbian.com/#supported-chips
#   https://docs.armbian.com/Hardware_Freescale-imx6/#cubox-and-hummingboard-boards
#   https://www.armbian.com/hummingboard/
#   https://developer.solid-run.com/products/imx6-som/
#   https://developer.solid-run.com/products/hummingboard-gate-edge/
#
# ----------------------------------------------------------------------------
export LANG=""
exec ./compile.sh docker \
	BOARD=hummingboard \
	BRANCH=current \
	RELEASE=bionic \
	BUILD_DESKTOP=no \
	KERNEL_ONLY=no \
	KERNEL_CONFIGURE=no \
	CUSTOMIZE_WITH="Docker,community,compose"
