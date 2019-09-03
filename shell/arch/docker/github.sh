#!/bin/bash
# This script downloads github source releases in zipped format, it also has basic support for binary assets.

# exit script if return code != 0
set -e

# setup default values
readonly ourScriptName=$(basename -- "$0")
readonly defaultDownloadFilename="github-source.zip"
readonly defaultDownloadPath="/tmp"
readonly defaultDownloadRelease="true"
readonly defaultExtractPath="/tmp/extracted"
readonly defaultReleaseType="source"
readonly defaultQueryType="releases/latest"

download_filename="${defaultDownloadFilename}"
download_path="${defaultDownloadPath}"
download_release="${defaultDownloadRelease}"
extract_path="${defaultExtractPath}"
release_type="${defaultReleaseType}"
query_type="${defaultQueryType}"

function github_release_version() {

	echo -e "[info] Running function to identify latest release tag from GitHub..."

	# use github rest api to get app release info
	github_release_url="https://api.github.com/repos/${github_owner}/${github_repo}/${query_type}"

	echo -e "[info] Identifying GitHub release..."
	mkdir -p "${download_path}"

	if [ "${query_type}" == "tags" ]; then
		json_query=".[0].name"
	else
		json_query=".tag_name"
	fi

	curly.sh -rc 6 -rw 10 -of "${download_path}/github_release" -url "${github_release_url}"
	github_release=$(cat "${download_path}/github_release" | jq -r "${json_query}")
	rm -f "${download_path}/github_release"

	echo -e "[info] GitHub release is '${github_release}'"

}

function github_downloader() {

	filename=$(basename "${download_filename}")
	download_filename_ext="${filename##*.}"

	if [ "${release_type}" == "source" ]; then

		if [[ ! -z "${download_branch}" ]]; then

			echo -e "[info] Downloading latest commit on branch '${download_branch}' from GitHub..."
			curly.sh -rc 6 -rw 10 -of "${download_path}/${match_asset_name}" -url "https://github.com/${github_owner}/${github_repo}/archive/${download_branch}.zip"

		else

			github_release="${1}"
			echo -e "[info] Downloading release source from GitHub..."
			curly.sh -rc 6 -rw 10 -of "${download_path}/${match_asset_name}" -url "https://github.com/${github_owner}/${github_repo}/archive/${github_release}.zip"

		fi

	else

		# loop over list of assets to download, space separated
		all_asset_names=$(curl -s "https://api.github.com/repos/${github_owner}/${github_repo}/releases/latest" | jq -r '.assets[] | .name')
		match_asset_name=$(echo "${all_asset_names}" | grep -P -o -m 1 "${download_filename}")
		github_release="${1}"

		if [[ -z "${match_asset_name}" ]]; then

			echo -e "[warn] No assets matching pattern '${download_filename}' available for download, showing all available assets..."
			echo -e "${all_asset_names}"
			echo -e "[info] Exiting script..." ; exit 1

		fi

		echo -e "[info] Downloading release asset from GitHub..."
		curly.sh -rc 6 -rw 10 -of "${download_path}/${match_asset_name}" -url "https://github.com/${github_owner}/${github_repo}/releases/download/${github_release}/${match_asset_name}"

	fi

	if [ "${download_filename_ext}" == "zip" ]; then

		echo -e "[info] Removing previous extract path '${extract_path}' ..."
		rm -rf "${extract_path}/"

		echo -e "[info] Extracting to '${extract_path}' ..."
		mkdir -p "${extract_path}"
		unzip -o "${download_path}/${match_asset_name}" -d "${extract_path}"

		echo -e "[info] Removing source archive from '${download_path}/${match_asset_name}' ..."
		rm -f "${download_path}/${match_asset_name}"

		if [[ ! -z "${install_path}" ]]; then

			echo -e "[info] Copying from extraction path '${extract_path}/*/*' to install path '${install_path}' ..."
			mkdir -p "${install_path}"
			cp -R "${extract_path}"/*/* "${install_path}"

			echo -e "[info] Removing extract path ${extract_path} ..."
			rm -rf "${extract_path}/"

		fi

	else

		if [[ ! -z "${install_path}" ]]; then

			echo -e "[info] Copying from download path '${download_path}/${match_asset_name}' to install path '${install_path}/${match_asset_name}' ..."
			mkdir -p "${install_path}"
			cp -R "${download_path}/${match_asset_name}" "${install_path}/${match_asset_name}"

			echo -e "[info] Removing source archive from '${download_path}/${match_asset_name}' ..."
			rm -f "${download_path}/${match_asset_name}"

			echo -e "[info] Marking binary asset '${install_path}/${match_asset_name}' as executable..."
			chmod +x "${install_path}/${match_asset_name}"

		fi

	fi
}

function github_compile_src() {

	# install compilation tooling
	pacman -S --needed base-devel --noconfirm

	# run commands to compile
	/bin/bash -c "${compile_src}"

	# remove base devel excluding useful core packages
	pacman -Ru $(pacman -Qgq base-devel | grep -v awk | grep -v pacman | grep -v sed | grep -v grep | grep -v gzip | grep -v which) --noconfirm

}

function show_help() {
	cat <<ENDHELP
Description:
	Script to download GitHub releases.
Syntax:
	${ourScriptName} [args]
Where:
	-h or --help
		Displays this text.

	-df or --download-filename <filename.ext>
		Define name of the downloaded file
		Defaults to '${defaultDownloadFilename}'.

	-dp or --download-path <path>
		Define path to download to.
		Defaults to '${defaultDownloadPath}'.

	-db or --download-branch <branch name>
		Define GitHub branch to download.
		No default.

	-ep or --extract-path <path>
		Define path to extract the download to.
		Defaults to '${defaultExtractPath}'.

	-ip or --install-path <path>
		Define path to install to.
		No default.

	-go or --github-owner <owner>
		Define GitHub owners name.
		No default.

	-rt or --release-type <binary|source>
		Define whether to download binary artifacts or source from GitHub.
		Default to '${defaultReleaseType}'.

	-qt or --query-type <release/latest|tags>
		Define GitHub api query type for release or tags from GitHub.
		Default to '${defaultQueryType}'.

	-gr or --github-repo <repo>
		Define GitHub repository name.
		No default.

	-grs or --github-release <release name>
		Define GitHub release name.
		If not defined then latest release will be used.

	-dr or --download-release <true|false>
		Define whether to download the GitHub release artifact.
		Default to '${defaultDownloadRelease}'.

	-cs or --compile-src <commands to execute>
		Define commands to execute to compile source code.
		Default is not defined.

Example:
	./github.sh -df github-download.zip -dp /tmp -ep /tmp/extracted -ip /opt/binhex/deluge -go binhex -rt source -gr arch-deluge
ENDHELP
}

while [ "$#" != "0" ]
do
	case "$1"
	in
		-df|--download-filename)
			download_filename=$2
			shift
			;;
		-dp| --download-path)
			download_path=$2
			shift
			;;
		-db| --download-branch)
			download_branch=$2
			shift
			;;
		-ep|extract-path)
			extract_path=$2
			shift
			;;
		-ip|--install-path)
			install_path=$2
			shift
			;;
		-go|--github-owner)
			github_owner=$2
			shift
			;;
		-gr|--github-repo)
			github_repo=$2
			shift
			;;
		-grs|--github-release)
			github_release=$2
			shift
			;;
		-rt|--release-type)
			release_type=$2
			shift
			;;
		-qt|--query-type)
			query_type=$2
			shift
			;;
		-dr|--download-release)
			download_release=$2
			shift
			;;
		-cs|--compile-src)
			compile_src=$2
			shift
			;;
		-h|--help)
			show_help
			exit 0
			;;
		*)
			echo "${ourScriptName}: ERROR: Unrecognised argument '$1'." >&2
			show_help
			 exit 1
			 ;;
	 esac
	 shift
done

if [[ -z "${github_owner}" ]]; then
	echo "[warning] GitHub owner's name not defined via parameter -go or --github-owner, displaying help..."
	show_help
	exit 1
fi

if [[ -z "${github_repo}" ]]; then
	echo "[warning] GitHub repo name not defined via parameter -gr --github-repo, displaying help..."
	show_help
	exit 1
fi

# if we dont specify a branch then we assume release
if [[ -z "${download_branch}" ]]; then
	# if we dont define the tag/release then find out what it is
	if [[ -z "${github_release}" ]]; then
		github_release_version
	fi
fi

# if we dont specify a branch then we assume release
# if branch is specified then download without passing github release version
if [[ -z "${download_branch}" ]]; then
	# if we want to download the release artifact then do so, otherwise return release/tag only
	if [[ "${download_release}" == "true" ]]; then
		github_downloader "${github_release}"
	else
		echo "${github_release}"
	fi
else
	github_downloader
fi

# if we need to compile source then install base-devel and run commands to compile
if [[ -n "${compile_src}" ]]; then
	github_compile_src
fi
