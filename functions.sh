#!/bin/bash
#set -x
cur_path=$(pwd)
DIST_TAG=".el$(echo "$platforms" | grep -oP '\d+' | head -n1)"

echow()
{
    FLAG=${1}
    shift
    echo -e "\033[1m${EPACE}${FLAG}\033[0m${@}"
}
echoB()
{
    FLAG=$1
    shift
    echo -e "\033[38;1;34m$FLAG\033[39m$@"
}
echoY()
{
    FLAG=$1
    shift
    echo -e "\033[38;5;148m$FLAG\033[39m$@"
}
echoR()
{
    FLAG=$1
    shift
    echo -e "\033[38;5;203m$FLAG\033[39m$@"
}
echoG()
{
    FLAG=$1
    shift
    echo -e "\033[38;5;71m$FLAG\033[39m$@"
}
check_input()
{
    echo " ###########   Check_input  ############# "
    echo " Product name is ${product} "
    echo " Version number is ${version} "
    echo " Build revision is ${revision} "
    echo " Required archs are ${archs} "
    echo " Required platform is ${platforms} "
}

set_paras()
{
    if [[ "${platforms}" =~ ^[0-9]+$ ]]; then
        platforms=epel-${platforms}-$archs
    fi
    case "${platforms}" in
        e10x|epel-10-x86_64)  
            platforms="epel-10-x86_64"
            EPEL_TAG=10
            ;;        
        e9x|epel-9-x86_64)    
            platforms="epel-9-x86_64"
            EPEL_TAG=9   
            ;;
        e8x|epel-8-x86_64)    
            platforms="epel-8-x86_64"
            EPEL_TAG=8   
            ;;
        e7x|epel-7-x86_64)    
            platforms="epel-7-x86_64"
            EPEL_TAG=7   
            ;;
        e10a|epel-10-aarch64) 
            platforms="epel-10-aarch64"
            EPEL_TAG=10 
            ;;        
        e9a|epel-9-aarch64)   
            platforms="epel-9-aarch64"
            EPEL_TAG=9  
            ;;
        e8a|epel-8-aarch64)   
            platforms="epel-8-aarch64"
            EPEL_TAG=8  
            ;;
        e7a|epel-7-aarch64)   
            platforms="epel-7-aarch64"
            EPEL_TAG=7  
            ;;
        *)  
            echo "Unrecognized platform: ${platforms}"; 
            exit 1 
            ;;
    esac
    echo "The following platforms are specified: ${platforms}"

    if [ -z "${revision}" ]; then
        echo ${product} | grep '-' >/dev/null
        if [ $? = 0 ]; then 
            revision=$(curl -isk https://${prod_server}/centos/${EPEL_TAG}/${archs}/RPMS/ | grep ${product}-${version} | \
            sed -nE "s/.*${product}-${version}-([0-9]+)\.el.*/\1/p" | \
            sort -nr | head -n1)
        fi
        if [[ ${revision} == ?(-)+([[:digit:]]) ]]; then
            revision=$((revision+1))
        else
            echoY "${revision} is not a number, set value to 1"
            revision=1
        fi      
    fi

    PRODUCT_DIR=${cur_path}/packaging/build/${product}
    RESULT_DIR=${PRODUCT_DIR}/${version}-${revision}/result
    BUILD_DIR=${cur_path}/build
    BUILD_SPECS=${BUILD_DIR}/SPECS
    BUILD_SRPMS=${BUILD_DIR}/SRPMS
    BUILD_SOURCES=${BUILD_DIR}/SOURCES
    BUILDER_NAME="LiteSpeedTech"
    BUILDER_EMAIL="info@litespeedtech.com"
    PRODUCT_WITH_VER=${product}-${version}-${revision}
}

set_build_dir()
{
    echoB "${FPACE} - Set Build Dir"
    if [ -d ${RESULT_DIR} ]; then
        echoY 'Find build directory exists'
        clear_or_not=n
        read -p 'do you want to clear it before continuing? y/n:  ' -t 15 clear_or_not
        if [ x$clear_or_not == xy ]; then
            echo " now clean the build directory "
            rm -rf ${RESULT_DIR}/*
        else
            echo 'The build directory will be retained, keeping the existing build-result folder.'
            echo 'Only relevant files will be updated.'
            cd ${RESULT_DIR}/
            rm -rf `ls ${BUILD_DIR} | grep -v build-result`          
        fi
    else
        mkdir -p ${RESULT_DIR}               
    fi
 
    for platform in ${platforms};
    do
        mkdir -p ${RESULT_DIR}/${platform}
    done
}

generate_spec()
{
    echoB "${FPACE} - Generate spec"
    date=$(date +"%a %b %d %Y")
    echoG "BUILD_DIR is: ${BUILD_DIR}"
 
    if [ ! -f "${PRODUCT_DIR}/changelog" ]; then
        change_log="* ${date} ${BUILDER_NAME} ${BUILDER_EMAIL}\n- Initial spec creation for ${product} rpm";
    else
        change_log=$(cat ${PRODUCT_DIR}/changelog);
        change_log="* ${date} ${BUILDER_NAME} ${BUILDER_EMAIL}\n- ${version}-${revision} spec created" . ${change_log};
    fi

    if [ -f "${BUILD_SPECS}/${PRODUCT_WITH_VER}.spec" ]; then
        echoY 'Found existing spec file, delete it and create new one'
        rm -f ${BUILD_SPECS}/${PRODUCT_WITH_VER}.spec
    fi

    {
        echo "s:%%PRODUCT%%:${product}:g"
        echo "s:%%VERSION%%:${version}:g"
        echo "s:%%BUILD%%:${revision}:g"
        echo "s:%%REVISION%%:${revision}:g"
        echo "s:%%LSAPIVER%%:${lsapiver}:g"
        echo "s:%%PHP_VER%%:${php_ver}:g"
        echo "s:%%PHP_API%%:${php_api}:g"
        echo "s:%%CHANGE_LOG%%:${change_log}:"
    }  > ./.sed.temp
    sed -f ./.sed.temp ./specs/${SPEC_FILE} > "${BUILD_SPECS}/${PRODUCT_WITH_VER}.spec"
}

prepare_source()
{
    echoB "${FPACE} - Prepare source"
    case "${product}" in
        openlitespeed)
            echoG "${EPACE}- Match openlitespeed"
            source_url="https://openlitespeed.org/packages/openlitespeed-${version}-${archs}-linux.tgz"
            wget -qO ./$product-$version-${archs}-linux.tgz $source_url
            tar xzf $product-$version-${archs}-linux.tgz
        ;;
        *)
            echo "Currently this product is not supported"
        ;;
    esac

    echoG "${EPACE}SOURCE: ${BUILD_SOURCES}/${source}"
}

build_rpms()
{
    echoB "${FPACE} - Build rpms"
    if [ -f ${BUILD_SRPMS}/${PRODUCT_WITH_VER}.${DIST_TAG}.src.rpm ]; then
        echoY 'Found existing source rpm, delete it and create new one.'
        rm -f ${BUILD_SRPMS}/${PRODUCT_WITH_VER}.${DIST_TAG}.src.rpm
    fi

    echoB "${FPACE} - Build rpm source package"
    echoG "${EPACE}SPEC Location: ${BUILD_SPECS}/${PRODUCT_WITH_VER}.spec"
    rpmbuild --nodeps -bs ${BUILD_SPECS}/${PRODUCT_WITH_VER}.spec  \
      --define "_topdir ${BUILD_DIR}" \
      --define "dist ${DIST_TAG}"
    if [ $? != 0 ]; then
        echoR 'rpm source package has issue; exit!'; exit 1
    fi

    echoB "${FPACE} - Build rpm package with mock"
    SRPM=${BUILD_SRPMS}/${PRODUCT_WITH_VER}${DIST_TAG}.src.rpm
    for platform in ${platforms};
    do
        # Use mock -v to enable debug or mock --quiet to silence 
        mock --resultdir=${RESULT_DIR}/${platform} --disable-plugin=selinux -r ${platform} "${SRPM}"
        if [ ${?} != 0 ]; then
            echo 'rpm build package has issue; exit!'; exit 1
        fi
    done
}

list_packages()
{
    echoY "########### Build Result Content #################"
    ls -lRX ${RESULT_DIR}/${platforms}
    echoY " ################# End of Result #################"  
    ls -lRX ${RESULT_DIR} | grep ${PRODUCT_WITH_VER}${DIST_TAG}.*.rpm >/dev/null
    if [ ${?} != 0 ]; then
        echoR "${PRODUCT_WITH_VER}${DIST_TAG}.*.rpm is not found!"
        exit 1
    fi
}

upload_to_server(){
    cd ${RESULT_DIR}/${platforms}
    REP_LOC='/var/www/html'
    echoG "- Uploading rpm to dev - distribution ${EPEL_TAG}"
    eval `ssh-agent -s`
    echo "${BUILD_KEY}" | ssh-add - > /dev/null 2>&1
    if [ ${revision} -gt 1 ]; then
        TARGET_FD="${REP_LOC}/centos/${EPEL_TAG}/update/${archs}/RPMS/"
    else
        TARGET_FD="${REP_LOC}/centos/${EPEL_TAG}/${archs}/RPMS/"
    fi
    echoG '- Start to sync'
    new_rpms=$(find . -maxdepth 1 -type f -name '*.rpm' ! -name '*.src.*' ! -name '*debuginfo*' -printf '%f ')
    rsync -av --exclude '*.src.*' --exclude '*debuginfo*' ${RESULT_DIR}/${platforms}/*.rpm -e "ssh -oStrictHostKeyChecking=no" root@${target_server}:${TARGET_FD}
}

gen_dev_release(){
    echoG '- Generate dev release'
    ssh -oStrictHostKeyChecking=no root@${target_server} -t "/var/www/gen_rpm_release.sh ${EPEL_TAG} ${TARGET_FD} \"$new_rpms\""
}