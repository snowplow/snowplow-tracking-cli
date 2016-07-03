#!/bin/bash
set -e

# Constants
bintray_package=snowplow-tracking-cli
bintray_artifact_prefix=snowplow_tracking_cli_
bintray_user=$BINTRAY_SNOWPLOW_GENERIC_USER
bintray_api_key=$BINTRAY_SNOWPLOW_GENERIC_API_KEY
bintray_repository=snowplow/snowplow-generic
dist_path=dist
build_dir=/opt/gopath/src/github.com/snowplow/snowplow-tracking-cli
build_cmd="go build"

root=$(pwd)

# Next five arrays MUST match up: number of elements and order 
declare -a goos_types=( "linux" "windows" )
declare -a goos_archs=( "amd64" "386" )
declare -a cgo_enabled=( "1" "1" )
declare -a cc_command=( "" "i686-w64-mingw32-gcc -fno-stack-protector -D_FORTIFY_SOURCE=0 -lssp" )
declare -a binary_names=( "snowplow-tracking-cli" "snowplow-tracking-cli.exe" )

# Similar to Perl die
function die() {
    echo "$@" 1>&2 ; exit 1;
}

# Go to parent-parent dir of this script
function cd_root() {
    cd $root
}

# Create our version in BinTray. Does nothing
# if the version already exists
#
# Parameters:
# 1. artifact_version
# 1. out_error (out parameter)
function create_bintray_package() {
    [ "$#" -eq 2 ] || die "2 arguments required, $# provided"
    local __artifact_version=$1
    local __out_error=$2

    echo "========================================"
    echo "CREATING BINTRAY VERSION ${__artifact_version} in package ${bintray_package} *"
    echo "* if it doesn't already exist"
    echo "----------------------------------------"

    http_status=`echo '{"name":"'${__artifact_version}'","desc":"Release of '${bintray_package}'"}' | curl -d @- \
        "https://api.bintray.com/packages/${bintray_repository}/${bintray_package}/versions" \
        --write-out "%{http_code}\n" --silent --output /dev/null \
        --header "Content-Type:application/json" \
        -u${bintray_user}:${bintray_api_key}`

    http_status_class=${http_status:0:1}
    ok_classes=("2" "3")

    if [ ${http_status} == "409" ] ; then
        echo "... version ${__artifact_version} in package ${bintray_package} already exists, skipping."
    elif [[ ! ${ok_classes[*]} =~ ${http_status_class} ]] ; then
        eval ${__out_error}="'BinTray API response ${http_status} is not 409 (package already exists) nor in 2xx or 3xx range'"
    fi
}

# Zips all of our applications
#
# Parameters:
# 1. artifact_version
# 2. out_artifact_names (out parameter)
# 3. out_artifact_paths (out parameter)
function build_artifacts() {
    [ "$#" -eq 3 ] || die "3 arguments required, $# provided"
    local __artifact_version=$1
    local __out_artifact_names=$2
    local __out_artifact_paths=$3

    artifact_names=()
    artifact_paths=()

    for i in "${!goos_types[@]}"
        do 
            :
            goos_type="${goos_types[$i]}"
            goos_arch="${goos_archs[$i]}"
            cgo_enabled="${cgo_enabled[$i]}"
            cc_command="${cc_command[$i]}"
            binary_name="${binary_names[$i]}"

            artifact_root="${bintray_artifact_prefix}${__artifact_version}_${goos_type}_${goos_arch}"
            artifact_name="${artifact_root}.zip"

            echo "==========================================="
            echo "BUILDING ARTIFACT ${artifact_name}"
            echo "-------------------------------------------"

            export GOOS=${goos_type}
            export GOARCH=${goos_arch}
            export CGO_ENABLED=${cgo_enabled}
            export CC=${cc_command}

            # Build binary
            binary_path=./${dist_path}/${binary_name}
            ${build_cmd} -o ${binary_path}

            # Zip artifact
            artifact_path=./${dist_path}/${artifact_name}
            zip -rj ${artifact_path} ${binary_path}

            artifact_names+=($artifact_name)
            artifact_paths+=($artifact_path)
        done

    eval ${__out_artifact_names}=${artifact_names}
    eval ${__out_artifact_paths}=${artifact_paths}
}

# Uploads our artifact to BinTray
#
# Parameters:
# 1. artifact_version
# 1. artifact_names
# 2. artifact_paths
# 3. out_error (out parameter)
function upload_artifacts_to_bintray() {
    [ "$#" -eq 4 ] || die "4 arguments required, $# provided"
    local __artifact_version=$1
    local __artifact_names=$2[@]
    local __artifact_paths=$3[@]
    local __out_error=$4

    echo "==============================="
    echo "UPLOADING ARTIFACTS TO BINTRAY*"
    echo "* 5-10 minutes"
    echo "-------------------------------"

    artifact_names=("${!__artifact_names}")
    artifact_paths=("${!__artifact_paths}")

    for i in "${!artifact_names[@]}"
        do
            :
            echo "Uploading ${artifact_names[$i]} to package ${bintray_package} under version ${__artifact_version}..."

            http_status=`curl -T ${artifact_paths[$i]} \
                "https://api.bintray.com/content/${bintray_repository}/${bintray_package}/${__artifact_version}/${artifact_names[$i]}?publish=1&override=0" \
                -H "Transfer-Encoding: chunked" \
                --write-out "%{http_code}\n" --silent --output /dev/null \
                -u${bintray_user}:${bintray_api_key}`

            http_status_class=${http_status:0:1}
            ok_classes=("2" "3")

            if [[ ! ${ok_classes[*]} =~ ${http_status_class} ]] ; then
                eval ${__out_error}="'BinTray API response ${http_status} is not in 2xx or 3xx range'"
                break
            fi
        done
}


cd_root

version=$1

create_bintray_package "${version}" "error"
[ "${error}" ] && die "Error creating package: ${error}"

artifact_names=() && artifact_paths=() && build_artifacts "${version}" "artifact_names" "artifact_paths"

upload_artifacts_to_bintray "${version}" "artifact_names" "artifact_paths" "error"
if [ "${error}" != "" ]; then
    die "Error uploading package: ${error}"
fi
