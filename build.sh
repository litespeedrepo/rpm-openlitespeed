#!/bin/bash
#set -x
#set -v
target_server='repo-dev.litespeedtech.com'
prod_server='rpms.litespeedtech.com'
EPACE='        '
FPACE='    '
#PHP_V=84
product=$1
platforms=$2
input_archs=$3
lsapiver="8.3"
PUSH_FLAG='OFF'
version=
revision=

source ./functions.sh #2>/dev/null
if [ $(id -u) != "0" ]; then
    echo "Error: The user is not root "
    echo "Please run this script as root"
    exit 1
fi

show_help()
{
    echo -e "\033[1mExamples\033[0m"
    echo "${EPACE} ./build.sh openlitespeed [8|9|10] [x86_64|aarch64]"
    echo "${EPACE} ./build.sh openlitespeed 9 x86_64"    
    echo -e "\033[1mOPTIONS\033[0m"
    echow '--version [NUMBER]'
    echo "${EPACE}${EPACE}Specify package version number"    
    echo "${EPACE}${EPACE}Example:./build.sh openlitespeed 9 x86_64 --version 1.8.4"
    echow '--revision [NUMBER]'
    echo "${EPACE}${EPACE}Specify package revision number"    
    echo "${EPACE}${EPACE}Example:./build.sh openlitespeed 9 x86_64 --version 1.8.4 --revision 2"
    echow '--push-flag'
    echo "${EPACE}${EPACE}push packages to dev server."    
    echo "${EPACE}${EPACE}Example:./build.sh openlitespeed 9 x86_64 --push-flag"
    echow '-H, --help'
    echo "${EPACE}${EPACE}Display help and exit."
    exit 0
}
if [ -z "${1}" ]; then
    show_help
fi

while [ ! -z "${1}" ]; do
    case $1 in
        --version) shift
            version="${1}"
                ;;
        --revision) shift
            revision="${1}"
                ;;
        --push | --push-flag)
            PUSH_FLAG='ON'
                ;;
        -[hH] | --help)
            show_help
                ;;           
    esac
    shift
done

if [ -z "${version}" ]; then
    version="$(grep ${product}= VERSION.txt | awk -F '=' '{print $2}')"
fi

if [ -z ${input_archs} ]; then
    echoY 'input_archs is not found, use default value x86_64'
    archs='x86_64'
else    
    archs=${input_archs}
fi
set_paras
check_input
set_build_dir
generate_spec
prepare_source
build_rpms
list_packages
if [ ${PUSH_FLAG} = 'ON' ]; then
    upload_to_server
    gen_dev_release
fi
