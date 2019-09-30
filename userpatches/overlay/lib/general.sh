#!/bin/bash
#
# Copyright (c) 2017-2019 Stephan Linz <linz@li-pro.net>
#
# This file is licensed under the terms of the GNU General Public
# License version 2. This program is licensed "as is" without any
# warranty of any kind, whether express or implied.
#
# This file is a part of tool chain https://github.com/lipro-armbian/build
#


# Variables:
# CUSTOMIZE_SERVICES (global indexed array)

# Hold all services that have to process for image customization.
declare -g -a CUSTOMIZE_SERVICES

# Hold all Docker related setup and configuration options.
declare -g -A DOCKER


# Functions:
# uniq_sorted
# uniq_orderly
# foreach
# __extend_service_list (internal used lambda function)
# create_service_list
# __extend_docker_options (internal used lambda function)
# create_service_options
# create_apt_source_list
# create_ppa_source_list
# install_apt_get
# purge_apt_get
# clean_apt_cache
# install_pipies


# uniq_sorted <string> <string> ...
#
# Helper function to sort the strings in alphapetical order and remove
# double strings.
#
uniq_sorted ()
{
	local -a sorted_list
	sorted_list=($(echo "$@" | tr ' ' '\n' | sort -u | tr '\n' ' '))
	echo -en ${sorted_list[@]}
}

# uniq_orderly <string> <string> ...
#
# Helper function to leave the strings in given order but remove
# double strings.
#
uniq_orderly ()
{
	local -a orderly_list
	orderly_list=($(echo "$@" | tr ' ' '\n' | awk '!a[$0]++' | tr '\n' ' '))
	echo -en ${orderly_list[@]}
}

# foreach <array> <function>
#
# Helper function to itterate over the given <array> and execute on each
# element the lambda <function> with the call syntax:
#
#   <function> <array_key> <array_value>
#
foreach ()
{
	arr="$(declare -p $1)" ; eval "declare -A f="${arr#*=};
	for i in ${!f[@]}; do $2 "$i" "${f[$i]}"; done
}

# __extend_service_list <index> <service>
#
# Extend the list of service (CUSTOMIZE_SERVICES) and its options.
# NOTE: This is an internal lambda function used by create_service_list().
#
# Parameters:
#  <index>     The index of given service option string.
#  <service>   The service option string with following syntax:
#
#              <service> := <name>,<opt0>,<opt1>, ... <optN>
#
#              Upper and lowercase of the option string has no matter.
#              All characters will converted into lowercase.
#
# Results:
#  CUSTOMIZE_SERVICES   The indexed array variable in the global environment
#                       with a list of services that have to process will be
#                       extended with the new service name.
#  <SERVICE>_OPTIONS    The indexed array variable in the global environment
#                       with a list of service options will be created.
#                       <SERVICE> is substitute with a single service name
#                       in uppercase from CUSTOMIZE_SERVICES -- so for each
#                       element in the list of services a <SERVICE>_OPTIONS
#                       variable will exist, either without or with content
#                       of given options in the origin customization string.
#
__extend_service_list ()
{
	local srv=$2

	if [[ -n $srv ]]; then

		# name , opt(N) , opt(N+1)
		local options=($(tr ',' ' ' <<< "$srv"))

		local name=${options[0]}
		unset options[0] # remove the name, the 1st element
		CUSTOMIZE_SERVICES+=(${name,,})

		eval "declare -g -a ${name^^}_OPTIONS"
		eval "${name^^}_OPTIONS=(${options[@],,})"

	fi
}

# create_service_list <customize_with_name>
#
# Create a list of services that have to process and additional
# lists of options, one list for each service.
#
# Parameters:
#  <customize_with_name>   The name of an environment variable that have to
#                          hold the customization string with following syntax:
#
#                          <customize_with> := <srv0>&<srv1>& ... <srvN>
#                                    <srvX> := <name>,<opt0>,<opt1>, ... <optN>
#
#                          Upper and lowercase of the customization string
#                          has no matter. All characters will converted into
#                          lowercase.
#
# Results:
#  CUSTOMIZE_SERVICES   The indexed array variable in the global environment
#                       with a list of services that have to process will be
#                       created. Each element holds a single service name.
#  <SERVICE>_OPTIONS    The indexed array variable in the global environment
#                       with a list of service options will be created.
#                       See __extend_service_list() for more details.
#
create_service_list ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "local c_str=${arg1#*=}"

	if [[ -n $c_str ]]; then

		# srv(N) & srv(N+1)
		local services=($(tr '&' ' ' <<< "$c_str"))
		foreach services __extend_service_list

	fi
}

# __extend_docker_options <index> <option>
#
# Extend the list of Docker options (DOCKER).
# NOTE: This is an internal lambda function used by create_service_options().
#
# Parameters:
#  <index>    The index of given option string.
#  <option>   The option string with syntax as defined for <docker_options>
#             in the calling function create_service_options(), see there.
#
# Results:
#   DOCKER[ogpgpub]   The OpenPGP public key of the remote APT repository.
#   DOCKER[repourl]   The URL of the remote APT repository.
#   DOCKER[repodir]   The DIR after URL of the remote APT repository (normal empty).
#   DOCKER[release]   The release string for the APT repository definition.
#   DOCKER[srcfile]   The Debian APT source list file name.
#
# See:
#   https://docs.docker.com/engine/installation/linux/debian/
#   https://docs.docker.com/engine/installation/linux/ubuntu/
#   https://docs.docker.com/install/linux/docker-ee/ubuntu/#prerequisites
#   https://docs.docker.com/install/linux/docker-ee/ubuntu/#install-docker-ee
#   https://docs.docker.com/compose/install/#install-using-pip
#
# OpenPGP:
#   2015:
#     EE: https://keyserver.ubuntu.com/pks/lookup?search=0xA178AC6C6238F52E&op=index
#     CE: https://keyserver.ubuntu.com/pks/lookup?search=0xF76221572C52609D&op=index
#   2017:
#     EE: https://keyserver.ubuntu.com/pks/lookup?search=0xBC14F10B6D085F96&op=index
#     CE: https://keyserver.ubuntu.com/pks/lookup?search=0x8D81803C0EBFCD88&op=index
#
# APT Repository:
#   2015:
#     EE: https://packages.docker.com/1.13/apt/repo
#     CE: https://apt.dockerproject.org/repo
#   2017:
#     EE: <personal subscription on Docker HUB> (TODO: setup from outside)
#     CE: https://download.docker.com/linux
#
# DEB Packages:
#   2015:
#     EE: docker-engine
#     CE: docker-engine
#   2017:
#     EE: docker-ee docker-ee-cli containerd.io
#     CE: docker-ce docker-ce-cli containerd.io
#
__extend_docker_options ()
{
	local opt=$2

	case $opt in
		stretch|buster)
			# The Debian release of the Docker Engine.
			# DOCKER[release]=debian-$opt # obsolete, since 2018
			DOCKER[repodir]=/debian
			DOCKER[release]=$opt
			;;
		xenial|bionic)
			# The Ubuntu release of the Docker Engine.
			# DOCKER[release]=ubuntu-$opt # obsolete, since 2018
			DOCKER[repodir]=/ubuntu
			DOCKER[release]=$opt
			;;
		commercial*)
			# The commercially supported version of the Docker Engine.
			DOCKER[ogpgpub]=0xBC14F10B6D085F96
			DOCKER[srcfile]=dockerproject.list
			# commercial : major_minor --> repository version (default 19.03)
			local rv=($(tr ':' ' ' <<< "$opt"))
			DOCKER[repourl]=https://packages.docker.com/${rv[1]:-19.03}/apt/repo
			DOCKER[pkgcomp]=main
			DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "docker-ee")
			DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "docker-ee-cli")
			DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "containerd.io")
			;;
		community*)
			# The community supported version of the Docker Engine.
			DOCKER[ogpgpub]=0x8D81803C0EBFCD88
			DOCKER[srcfile]=dockerproject.list
			DOCKER[repourl]=https://download.docker.com/linux
			DOCKER[pkgcomp]=stable
			DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "docker-ce")
			DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "docker-ce-cli")
			DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "containerd.io")
			;;
		compose*)
			# The Docker Compose tool.
			# compose* : major_minor_patch --> package version (default 1.24.1)
			local pv=($(tr ':' ' ' <<< "$opt"))
			# compose - inst_src --> installation source (default pip)
			local is=($(tr '-' ' ' <<< "${pv[0]}"))
			case ${is[1]:-pip} in
				pip*)
					DOCKER[pkglist]=$(uniq_sorted "${DOCKER[pkglist]}" "python-pip")
					DOCKER[pipies]=$(uniq_orderly "${DOCKER[pipies]}" "setuptools")
					DOCKER[pipies]=$(uniq_orderly "${DOCKER[pipies]}" "wheel")
					DOCKER[pipies]=$(uniq_orderly "${DOCKER[pipies]}" "pynacl:1.3.0")
					DOCKER[pipies]=$(uniq_orderly "${DOCKER[pipies]}" "docker-compose:${pv[1]:-1.24.1}")
					;;
			esac
	esac
}

# create_service_options <service_name> <service_options_name>
#
# Parse environment variable <SERVICE>_OPTIONS or the given arguments
# and create all further required environment variable to configure
# the installation and setup process.
#
# Parameters:
#   <service_name>           The name of a variable in the global environment
#                            that have to hold the service name whose options
#                            have to create (a string).
#   <service_options_name>   The name of an indexed array variable in the
#                            global environment that have to hold the
#                            configure and installation options string for
#                            the service with following syntax.
#
# Option string syntax (indexed array):
#   <service_options> := <docker_options>
#    <docker_options>    The Docker service option string.
#
# Docker option string syntax (indexed array):
#    <docker_options> := (<release> <version>)
#           <release> := stretch | buster | xenial | bionic
#           <version> := community | commercial[:<major_minor>]
#                        <major_minor> := 19.03 | 18.09 | 18.03 | 17.06
#
# Results:
#   optional, when supported / needed:
#     <SERVICE>[srcfile] The Debian APT source list file name.
#     <SERVICE>[ogpgpub] The OpenPGP publik key (64-bit).
#     <SERVICE>[ppaname] The Ubuntu PPA name.
#     <SERVICE>[repourl] The Debian package repository URL.
#     <SERVICE>[repodir] The Debian package repository DIR after URL.
#     <SERVICE>[release] The Debian OS release name.
#     <SERVICE>[pkgcomp] The Debian APT component name.
#   obligatory, must set at least:
#     <SERVICE>[pkglist] The list of Debian package names.
#
# See:
#   __extend_docker_options ()
#
create_service_options ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare service=${arg1#*=}"

	local arg2; arg2=$(declare -p $2) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$2" "err"
	eval "declare -a options=${arg2#*=}"

	case $service in
		omv)
			# your code here
			;;
		docker)
			# Prefer the community version as default. Will be
			# overridden by the commercial option in the rest of
			# the origin option list.
			options=(community ${options[@]})
			foreach options __extend_docker_options
			# TODO: error on commercial && community
			;;
	esac
}

# create_apt_source_list <option_array_name>
#
# Create a new Debian APT source list entry as specified by the given
# option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         ogpgpub   OpenPGP publik key, the last 64-bit from
#                                   the fingerprint beginning with 0x
#                         repourl   Debian package repository URL
#                         repodir   Debian package repository DIR after URL
#                         release   Debian OS release name
#                         pkgcomp   Debian APT component name
#                         srcfile   Debian APT source list file name
#
create_apt_source_list ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in ogpgpub repourl repodir release pkgcomp srcfile; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	display_alert "Download and install OpenPGP publik key" "${options[ogpgpub]}" "info"
	eval 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ${options[ogpgpub]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	if [ ! -f /etc/apt/sources.list.d/${options[srcfile]} ]; then
		display_alert "Create APT source list" \
			"${options[srcfile]} ${options[repourl]}${options[repodir]} ${options[release]}"
		echo "deb ${options[repourl]}${options[repodir]} ${options[release]} ${options[pkgcomp]}" > \
			/etc/apt/sources.list.d/${options[srcfile]}
	fi

	display_alert "Updating package list" "${options[srcfile]}::${options[release]}" "info"
	eval 'apt-get -q -y update' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Updating package lists..." $TTY_Y $TTY_X'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Updating package lists failed"
}

# create_ppa_source_list <option_array_name>
#
# Create a new Debian APT source list entry from an Ubuntu PPA as specified
# by the given option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         ogpgpub   OpenPGP publik key, the last 64-bit from
#                                   the fingerprint beginning with 0x
#                         ppaname   The Ubuntu PPA name
#
create_ppa_source_list ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in ogpgpub ppaname; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	display_alert "Download and install OpenPGP publik key" "${options[ogpgpub]}" "info"
	eval 'apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys ${options[ogpgpub]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	display_alert "Add and setup Ubuntu PPA" "${options[ppaname]}" "info"
	eval 'add-apt-repository --yes --no-update --keyserver hkp://keyserver.ubuntu.com:80 ${options[ppaname]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	display_alert "Updating package list" "${options[ppaname]}" "info"
	eval 'apt-get update' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Updating package lists..." $TTY_Y $TTY_X'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Updating package lists failed"
}

# install_apt_get <option_array_name>
#
# Install packages with Debian APT as specified by the given option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         pkglist   Space separated List of Debian package
#                                   names that have to install.
#
install_apt_get ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in pkglist; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	# fancy progress bars
	[[ -z $OUTPUT_DIALOG ]] && local apt_extra_progress="--show-progress -o DPKG::Progress-Fancy=1"

	display_alert "Installing packages" "${options[pkglist]}" "info"
	eval 'DEBIAN_FRONTEND=noninteractive apt-get -q -y \
		$apt_extra_progress --no-install-recommends install ${options[pkglist]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Installing packages..." $TTY_Y $TTY_X'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Installation of packages failed"
}

# purge_apt_get <option_array_name>
#
# Purge packages with Debian APT as specified by the given option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         pkglist   Space separated List of Debian package
#                                   names that have to purge.
#
purge_apt_get ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in pkglist; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	# fancy progress bars
	[[ -z $OUTPUT_DIALOG ]] && local apt_extra_progress="--show-progress -o DPKG::Progress-Fancy=1"

	display_alert "Remove and purge packages" "${options[pkglist]}" "info"
	eval 'DEBIAN_FRONTEND=noninteractive apt-get -q -y \
		$apt_extra_progress purge ${options[pkglist]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Remove and purge packages..." $TTY_Y $TTY_X'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Purging of packages failed"

	eval 'DEBIAN_FRONTEND=noninteractive apt-get -q -y \
		$apt_extra_progress autoremove --purge ${options[pkglist]}' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Remove and purge packages..." $TTY_Y $TTY_X'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Autoremove with purging of packages failed"
}

# clean_apt_cache
#
# Clean cache of packages with Debian APT.
#
clean_apt_cache ()
{
	# fancy progress bars
	[[ -z $OUTPUT_DIALOG ]] && local apt_extra_progress="--show-progress -o DPKG::Progress-Fancy=1"

	display_alert "Clean" "package cache" "info"
	eval 'DEBIAN_FRONTEND=noninteractive apt-get -q -y $apt_extra_progress clean' \
		${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
		${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Remove and purge packages..." $TTY_Y $TTY_X'} \
		${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

	[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Clean of package cache failed"
}

# install_pipies <option_array_name>
#
# Install Python packages with PIP as specified by the given option array.
#
# Parameters:
#   <option_array_name>   The name of an environment variable that have to
#                         hold all needed values. It must be an associative
#                         array with following keys:
#
#                         pipies   Space separated List of Python packages
#                                  and optional versions that have to install.
#
install_pipies ()
{
	local arg1; arg1=$(declare -p $1) || \
		display_alert "${FUNCNAME[0]}: EINVAL" "$1" "err"
	eval "declare -A options=${arg1#*=}"

	for i in pipies; do
		[[ -z ${options[$i]} ]] && \
			display_alert "${FUNCNAME[0]}: EINVAL" "$1[$i]" "err"
	done

	# Check Python pip environment
	[[ -z $pip_version ]] && pip_version=$(pip --version 2>/dev/null)
	[[ -n $pip_version ]] || return

	display_alert "Installing Python packages" "${options[pipies]}" "info"
	for pipy in ${options[pipies]}; do

		# name : major_minor_patch
		local pp=($(tr ':' ' ' <<< "$pipy"))
		local pn=${pp[0]}
		local pv=${pp[1]}
		local pipy_install="$pn${pv:+==$pv}"
		local -A pipy_prereq

		pip_pre() { "$@"; }
		case $pn in
			cryptography):
				pipy_prereq[pkglist]="python-dev libffi-dev libssl-dev"
				display_alert "With prerequests" "$(eval 'echo ${pipy_prereq[@]}')"
				install_apt_get pipy_prereq
				;;
			docker-compose):
				pipy_prereq[pkglist]="python-dev libffi-dev libssl-dev"
				display_alert "With prerequests" "$(eval 'echo ${pipy_prereq[@]}')"
				install_apt_get pipy_prereq
				;;
			PyNaCl|pynacl):
				pipy_prereq[pkglist]="python-dev libffi-dev libsodium-dev libssl-dev"
				display_alert "With prerequests" "$(eval 'echo ${pipy_prereq[@]}')"
				install_apt_get pipy_prereq
				pip_pre() { SODIUM_INSTALL=system "$@"; }
				;;
			*) ;;
		esac

		pip_pre eval 'pip install --disable-pip-version-check --system --no-cache-dir --compile $pipy_install' \
			${PROGRESS_LOG_TO_FILE:+' | tee -a $DEST/debug/output.log'} \
			${OUTPUT_DIALOG:+' | dialog --backtitle "$backtitle" --progressbox "Installing Python packages..." $TTY_Y $TTY_X'} \
			${OUTPUT_VERYSILENT:+' >/dev/null 2>/dev/null'}

		[[ ${PIPESTATUS[0]} -ne 0 ]] && exit_with_error "Installation of Python packages failed"
	done

	# Output all installed Python packages (for sanity)
	display_alert "Have installed Python packages" \
		"$(eval 'pip list --disable-pip-version-check --not-required --format=legacy' | tr '\n' ' ')"
}
