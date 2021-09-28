#!/bin/bash

# script name and version
readonly ourScriptName="$(basename -- "$0")"
readonly ourScriptPath="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

readonly defaultNetworkType="bridge"
readonly defaultContainerName="test"
readonly defaultRetryCount="60"
readonly defaultProtocol="http"

# set defaults
network_type="${defaultNetworkType}"
container_name="${defaultContainerName}"
retry_count="${defaultRetryCount}"
protocol="${defaultProtocol}"

function cleanup() {

	echo "[debug] Running post test cleanup"

	echo "[debug] Deleting container '${container_name}'..."
	docker rm -f "${container_name}"

	echo "[debug] Deleting container bind mounts '/tmp/config', '/tmp/data', '/tmp/media' ..."
	sudo rm -rf '/tmp/config' '/tmp/data' '/tmp/media'
}

function test_result(){

	if [[ "${tests_passed}" == "false" ]]; then

		echo "[error] Tests failed"

		echo "[debug] Displaying docker logs..."
		docker logs "${container_name}"

		echo "[debug] Displaying contents of container log file '/tmp/config/supervisord.log'..."
		cat '/tmp/config/supervisord.log'

		echo "[debug] Displaying contents of curl log file '/tmp/curl/curl.log'..."
		cat '/tmp/curl/curl.log'
		cleanup
		exit 1
	fi

	echo "[debug] Tests passed"
	cleanup

}

function webui_test() {

	"[debug] Running Web UI test for application '${app_name}'..."

	while [ "$#" != "0" ]
	do
		case "$1"
		in
			-cp|--container-ports)
				container_ports="${2}"
				shift
				;;
			-cn|--container-name)
				container_name="${2}"
				shift
				;;
			-u|--url)
				url="${2}"
				shift
				;;
			-nt|--network-type)
				network_type="${2}"
				shift
				;;
			-rc|--retry-count)
				retry_count="${2}"
				shift
				;;
			-ev|--env-vars)
				env_vars="${2}"
				shift
				;;
			-aa|--additional-args)
				additional_args="${2}"
				shift
				;;
			-p|--protocol)
				protocol="${2}"
				shift
				;;
			-h|--help)
				show_help
				exit 0
				;;
			*)
				echo "[warn] Unrecognised argument '$1', displaying help..." >&2
				echo ""
				show_help_webui_test
				exit 1
				;;
		esac
		shift
	done

	mkdir -p '/tmp/curl'

	echo "[debug] Creating Docker container 'docker run -d --name ${container_name} --net ${network_type} ${env_vars} ${additional_args} -v '/tmp/config':'/config' -v '/tmp/data':'/data' -v '/tmp/media':'/media' ${container_ports} ${image_name}'"
	docker run -d --name ${container_name} --net ${network_type} ${env_vars}  ${additional_args} -v '/tmp/config':'/config' -v '/tmp/data':'/data' -v '/tmp/media':'/media' ${container_ports} ${image_name}

	echo "[debug] Showing running containers..."
	docker ps

	# get host ports to check
	host_ports=$(echo "${container_ports}" | grep -P -o -m 1 '(?<=-p\s)[0-9]+' | xargs)

	# split space separated host ports into array
	IFS=' ' read -ra host_ports_array <<< "${host_ports}"

	# loop over list of host ports
	for host_port in "${host_ports_array[@]}"; do

		echo "[debug] Waiting for port '${host_port}' to be in listen state..."
		while ! curl -s -v --cookie --insecure -L "${protocol}://localhost:${host_port}/${url}" >> /tmp/curl/curl.log 2>&1; do
			retry_count=$((retry_count-1))
			if [ "${retry_count}" -eq "0" ]; then
				tests_passed="false"
				test_result
			fi
			sleep 1s
		done
		echo "[debug] Success, port '${host_port}' is in listening state"

	done

	tests_passed="true"
	test_result
}

function run_test() {

	while [ "$#" != "0" ]
	do
		case "$1"
		in
			-ap|--app-name)
				app_name="${2}"
				shift
				;;
			-in|--image-name)
				image_name="${2}"
				shift
				;;
			-h|--help)
				show_help
				exit 0
				;;
			*)
				echo "[warn] Unrecognised argument '$1', displaying help..." >&2
				echo ""
				show_help
				exit 1
				;;
		esac
		shift
	done

	echo "[debug] Checking we have all required parameters before running..."

	if [[ -z "${app_name}" ]]; then
		echo "[warn] Please specify '--app-name' option, displaying help..."
		echo ""
		show_help
		exit 1
	fi

	if [[ -z "${image_name}" ]]; then
		echo "[warn] Please specify '--image-name' option, displaying help..."
		echo ""
		show_help
		exit 1
	fi

	common_options="--container-name test --network-type bridge --retry-count 60"

	if [[ "${app_name}" == "airsonic" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:4040'

	elif [[ "${app_name}" == "code-server" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8500'

	elif [[ "${app_name}" == "couchpotato" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:5050'

	elif [[ "${app_name}" == "crafty" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8000' --protocol 'https'

	elif [[ "${app_name}" == "deluge" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8112' --env-vars '-e VPN_ENABLED=no' --additional-args '--privileged=true' --protocol 'http'

	elif [[ "${app_name}" == "emby" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8096'

	elif [[ "${app_name}" == "jackett" ]]; then
		# force jackett to listen on ipv4
	    mkdir -p '/tmp/config/Jackett'
        echo '{ "urls": "http://0.0.0.0:9117" }' > '/tmp/config/Jackett/appsettings.json'

		webui_test ${common_options} --container-ports '-p 9999:9117'

	elif [[ "${app_name}" == "jellyfin" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8096'

	elif [[ "${app_name}" == "jenkins" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8090'

	elif [[ "${app_name}" == "lidarr" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8686'

	elif [[ "${app_name}" == "medusa" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8081'

	elif [[ "${app_name}" == "mineos-node" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8443'

	elif [[ "${app_name}" == "moviegrabber" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:9191'

	elif [[ "${app_name}" == "nzbget" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:6789'

	elif [[ "${app_name}" == "nzbhydra" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:5075'

	elif [[ "${app_name}" == "nzbhydra2" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:5076'

	elif [[ "${app_name}" == "plex" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:32400'

	elif [[ "${app_name}" == "privoxy" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8118' --env-vars '-e VPN_ENABLED=no' --additional-args '--privileged=true' --protocol 'http'

	elif [[ "${app_name}" == "prowlarr" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:9696'

	elif [[ "${app_name}" == "qbittorrent" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8080' --env-vars '-e VPN_ENABLED=no' --additional-args '--privileged=true' --protocol 'http'

	elif [[ "${app_name}" == "radarr" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:7878'

	elif [[ "${app_name}" == "resilio-sync" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8888'

	elif [[ "${app_name}" == "rtorrent" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:9080' --env-vars '-e VPN_ENABLED=no' --additional-args '--privileged=true' --protocol 'http'

	elif [[ "${app_name}" == "sabnzbd" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8080' --env-vars '-e VPN_ENABLED=no' --additional-args '--privileged=true' --protocol 'http'

	elif [[ "${app_name}" == "sickchill" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8081'

	elif [[ "${app_name}" == "sonarr" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8989'

	elif [[ "${app_name}" == "syncthing" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:8384'

	elif [[ "${app_name}" == "tvheadend" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:9981'

	elif [[ "${app_name}" == "urbackup" ]]; then
		webui_test ${common_options} --container-ports '-p 9999:55414'

	else
		echo "[error] Application name '${app_name}' unknown, exiting script..."
		exit 1
	fi

}

function show_help() {
	cat <<ENDHELP
Description:
	Testrunner for binhex repo's.
	${ourScriptName} - Created by binhex.
Syntax:
	${ourScriptName} [args]
Where:
	-h or --help
		Displays this text.

	-an or --app-name
		Define the application name to test.
		No default.

	-in or --image-name
		Define the image and tag name for the container.
		No default.

Examples:
	Run test for application airsonic:
		${ourScriptPath}/${ourScriptName} --app-name 'airsonic' --image-name 'binhex/arch-airsonic:latest'
ENDHELP
}

function show_help_webui_test() {
	cat <<ENDHELP
Description:
	Run Web UI tests.
	${ourScriptName} - Created by binhex.
Syntax:
	webui_test [args]
Where:
	-h or --help
		Displays this text.

	-cp or --container-ports
		Define the container port(s) for the container.
		No default.

	-cn or --container-name
		Define the name for the container.
		Defaults to '${defaultContainerName}'.

	-u or --url
		Define the URL to test for the container.
		No default.

	-nt or --network-type
		Define the network type for the container.
		Defaults to '${defaultNetworkType}'.

	-rc or --retry-count
		Define the number of retries before test is marked as failed
		Defaults to '${defaultRetryCount}'.

	-ev or --env-vars
		Define the env vars for the container.
		No default.

	-aa or --additional-args
		Define any additional docker arguments for the container.
		No default.

	-p or --protocol
		Define protocol for test, valid values are <http|https>.
		defaults to '${defaultProtocol}'.

Examples:
	Run Web UI test for image with VPN disabled via env var:
		webui_test --container-ports '-p 9999:8080' --container-name 'test' --network-type 'bridge' --retry-count '60' --env-vars '-e VPN_ENABLED=no' --additional-args '--privileged=true' --protocol 'http'
ENDHELP
}

echo "[debug] ${ourScriptName} script"
run_test "$@"