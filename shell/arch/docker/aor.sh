#!/bin/bash

# exit script if return code != 0
set -e

if [[ ! -z "${aor_packages}" ]]; then

	# split space seperated string of packages into list
	IFS=' ' read -ra aor_package_list <<< "${aor_packages}"

	# process each package in the list
	for aor_package_name in "${aor_package_list[@]}"; do

		echo "[info] attempting download for aor package ${aor_package_name}"
		
		# get repo and arch from aor using api (json format)
		curly.sh -rc 6 -rw 10 -of /tmp/aor_json -url "https://www.archlinux.org/packages/search/json/?q=${aor_package_name}&repo=Community&repo=Core&repo=Extra&repo=Multilib&arch=any&arch=x86_64"

		# filter based on exact package name to prevent fuzzy matching of wrong packages
		aor_package_json=$(cat /tmp/aor_json | jq -c --arg aor_package_name "$aor_package_name" '.results[] | select(.pkgname | startswith($aor_package_name) and endswith($aor_package_name))')

		aor_package_repo=$(echo $aor_package_json | jq -r ".repo")
		echo "[info] aor package repo is ${aor_package_repo}"

		aor_package_arch=$(echo $aor_package_json | jq -r ".arch")
		echo "[info] aor package arch is ${aor_package_arch}"

		# get latest compiled package from aor (required due to the fact we use archive snapshot)
		if [[ ! -z "${aor_package_repo}" && ! -z "${aor_package_arch}" ]]; then

			echo "[info] curly.sh -rc 6 -rw 10 -of /tmp/${aor_package_name}.tar.xz -url https://www.archlinux.org/packages/${aor_package_repo}/${aor_package_arch}/${aor_package_name}/download/"
			curly.sh -rc 6 -rw 10 -of "/tmp/${aor_package_name}.tar.xz" -url "https://www.archlinux.org/packages/${aor_package_repo}/${aor_package_arch}/${aor_package_name}/download/"
			pacman -U "/tmp/${aor_package_name}.tar.xz" --noconfirm

		else

			echo "[warn] unable to determine package repo and/or architecture, skipping package ${aor_package_name}"

		fi

	done

fi
