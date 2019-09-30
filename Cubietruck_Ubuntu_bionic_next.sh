#!/bin/bash
#
# Copyright (c) 2016-2019 Stephan Linz, linz@li-pro.net
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#
# Refer to:
#   https://docs.armbian.com/#supported-chips
#   https://docs.armbian.com/Hardware_Allwinner-A20/#allwinner-a10-a20-boards
#   https://docs.armbian.com/boards/cubietruck/
#   https://www.armbian.com/cubietruck/
#   http://linux-sunxi.org/Cubietruck
#   http://dl.linux-sunxi.org/
#   http://cubieboard.org/model/cb3/
#   http://docs.cubieboard.org/tutorials/cubietruck/start
#   http://dl.cubieboard.org/
#
# Additional useful options:
#   DEFAULT_OVERLAYS="cubietruck-blue-heartbeat cubietruck-orange-stmmac-link cubietruck-white-disk-activity cubietruck-green-mmc0"
# ----------------------------------------------------------------------------
export LANG=""
exec ./compile.sh docker \
	BOARD=cubietruck \
	BRANCH=next \
	RELEASE=bionic \
	BUILD_DESKTOP=no \
	KERNEL_ONLY=no \
	KERNEL_CONFIGURE=no \
	CUSTOMIZE_WITH="DeadSnakes,python,python2.7,python3.8,python3.8-venv,python3.8-lib2to3&Docker,community,compose"
