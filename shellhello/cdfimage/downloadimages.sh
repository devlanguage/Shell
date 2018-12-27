#!/bin/bash
#set default registry to docker hub
source /etc/profile
old=$(stty -g)
trap 'if [[ -f "/tmp/.image-sync-lock" ]] && [[ "$(cat /tmp/.image-sync-lock)" = "$$" ]] ; then stty $old ; rm -f /tmp/.image-sync-lock; fi ; exit' 1 2 3 8 9 14 15 EXIT
mkdir -p /var/opt/kubernetes/offline/temp_files
logfile="/tmp/downloadsuiteimages-`date "+%Y%m%d%H%M%S"`.log"
registryhost=""
dir="/var/opt/kubernetes/offline/suite_images/"
syncLogDir="/var/opt/kubernetes/offline/progress_log/"
tempDir="/var/opt/kubernetes/offline/temp_files/"
toolsDir="./"
jqFileName="jq"
imageListFileName="image-list.json"
deploymentsFileName="deployments.json"
imageSetFileName="image-set.json"
organization="hpeswitom/"
selectSuite=""
selectVersion=""
suiteJsonFile="${tempDir}suite-metadata/suiteinfo.json"
reTry=5
answer=""
noTaryServer="https://notary.docker.io"
suiteDataTag=latest
CDF_VERSION="2018.01"
quickFlag=on
userFlag=0
array=()
gzipList=
usage() {
    echo "Usage: ./downloadimages.sh [-l|--list] [-y|--yes] [-u|--user <username>] [-p|--pass <password>] [-r|--registry <registry-url>] [-c|--content-trust <on/off>] [-s|--suite <suite-name>] [-v|--version <version>] [-D|--toolsdir <toolsdir>] [-t|--retry <retry times>] "
    echo "       -l|--list           List all available suite versions."
    echo "       -y|--yes            Suite image tars will be covered by default when the suite images tar directory path exists."
    echo "       -d|--dir            Suite images tar directory path (The default value is /var/opt/kubernetes/offline/suite_images/)."
    echo "       -u|--user           Registry host account username. Mandatory when the \"-p|--pass\" is provided."
    echo "       -p|--pass           Registry host account password. Wrap the 'password' in single quotes."
    echo "       -r|--registry       The host name of the registry that you want to pull suite images from."
#    echo "       -o|--org            The organization within the registry where you pulled the suite images from."
    echo "       -c|--content-trust  Use \"on/off\" to enable/disable content trust."
#    echo "       -n|--notary-server  Change Notary Server URL (The default value is https://notary.docker.io)."
    echo "       -s|--suite          The name of the suite whose images you want to download."
    echo "       -D|--toolsdir       The path of jq image-list.json and deployments.json ."
    echo "       -v|--version        The version of the suite whose images you want to download."
    echo "       -t|--retry          The retry times when the image download fails."
    echo "       -q|--quick          Use \"on/off\" to enable/disable quick download mode. Downloaded images will not be deleted when you enabled this mode."
    echo "       -h|--help           Show help."
    exit 1
}

while [[ ! -z $1 ]] ; do
    case "$1" in
        -l|--list) opFlag="list" ; shift ;;
        -q|--quick) 
        case "$2" in
            -*) echo "-q|--quick parameter requires a value(on/off). " ; exit 1 ;;
            *)  if [[ -z $2 ]] || [[ ! "on off" =~ "$2" ]] ; then echo "-q|--quick parameter requires a value(on/off). " ; exit 1 ; fi ; quickFlag=$2 ; shift 2 ;;
        esac ;;
        -y|--yes) answer="Y" ; shift ;;
        -u|--user)
        case "$2" in
            -*) echo "-u|--user parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-u|--user parameter requires a value. " ; exit 1 ; fi ; username=$2 ; userFlag=1 ; shift 2 ;;
        esac ;;
        -p|--pass)
        case "$2" in
            -*) echo "-p|--pass parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-p|--pass parameter requires a value. " ; exit 1 ; fi ; password=$2 ; shift 2 ;;
        esac ;;
        -T|--tag)
        case "$2" in
            -*) echo "-T|--tag parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-T|--tag parameter requires a value. " ; exit 1 ; fi ; suiteDataTag=$2 ; shift 2 ;;
        esac ;;
        -r|--registry)
        case "$2" in
            docker) registryhost="" ; if [[ -z ${orgFlag} ]] ; then organization="hpeswitom/" ; fi ; regFlage=1 ; shift 2 ;;
            -*) echo "-r|--registry parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-r|--registry parameter requires a value. " ; exit 1 ; fi ; registryhost=$2 ; regFlage=1 ; shift 2 ;;
        esac ;;
        -o|--org)
        case "$2" in
            -*) echo "-o|--org parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-o|--org parameter requires a value. " ; exit 1 ; fi ; organization=$2 ; orgFlag=1 ; shift 2 ;;
        esac ;;
        -c|--content-trust)
        case "$2" in
            -*) echo "-c|--content-trust parameter requires a value. " ; exit 1 ;;
            on) dockerContentTrust=1 ; shift 2 ;;
            off) dockerContentTrust=0 ; shift 2 ;;
            *)  if [[ -z $2 ]] ; then echo "-c|--content-trust parameter requires a value. " ; exit 1 ; fi ; dockerContentTrust=0 ; shift 2 ;;
        esac ;;
        -n|--notary-server)
        case "$2" in
            -*) echo "-n|--notary-server parameter requires a value. " ; exit 1 ;;
            *) if [[ -z $2 ]] ; then echo "-n|--notary-server parameter requires a value. " ; exit 1 ; fi ; noTaryServer=$2 ; shift 2 ;;
        esac ;;
        -s|--suite)
        case "$2" in
            -*) echo "-s|--suite parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-s|--suite parameter requires a value. " ; exit 1 ; fi ; suiteSet=($(echo $2 | tr '[A-Z]' '[a-z]')) ; shift 2 ;;
        esac ;;
        -v|--version)
        case "$2" in
            -*) echo "-v|--version parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-v|--version parameter requires a value. " ; exit 1 ; fi ; versionSet=$2 ; shift 2 ;;
        esac ;;
        -t|--retry)
        case "$2" in
            -*) echo "-t|--retry parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-t|--retry parameter requires a value. " ; exit 1 ; fi ; maxRetry=$2 ; shift 2 ;;
        esac ;;
        -d|--dir)
        case "$2" in
            -*) echo "-d|--dir parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-d|--dir parameter requires a value. " ; exit 1 ; fi ; dir=$2 ; shift 2 ;;
        esac ;;
        -D|--toolsDir)
        case "$2" in
            -*) echo "-D|--toolsDir parameter requires a value. " ; exit 1 ;;
            *)  if [[ -z $2 ]] ; then echo "-D|--toolsDir parameter requires a value. " ; exit 1 ; fi ; toolsDir=$2 ; shift 2 ;;
        esac ;;
        *|-*|-h|--help|/?|help) usage ;;
#        *) shift ; break ;;
    esac
done

#############COMMON FUNC
#function for write log
write_log() {
   level=$1
    msg=$2
    exitCode=1
    if [[ ! -z $3 ]] ; then
        exitCode=$3
    fi
    case $level in
        debug)
            echo "" >> $logfile
            echo "[DEBUG] `date "+%Y-%m-%d %H:%M:%S"` : $msg  " >> $logfile ;;
        info)
            echo "$msg"
            echo "[INFO] `date "+%Y-%m-%d %H:%M:%S"` : $msg  " >> $logfile ;;
        error)
            echo "$msg"
            echo "[ERROR] `date "+%Y-%m-%d %H:%M:%S"` : $msg  " >> $logfile ;;
        warn)
            echo "$msg"
            echo "[WARN] `date "+%Y-%m-%d %H:%M:%S"` : $msg  " >> $logfile ;;
        begin)
            echo -e "$msg\c"
            echo -e "[INFO] `date "+%Y-%m-%d %H:%M:%S"` : $msg  \c" >> $logfile ;;
        end)
            echo "$msg"
            echo "$msg  " >> $logfile ;;
        fatal)
            echo "$msg"
            echo "[FATAL] `date "+%Y-%m-%d %H:%M:%S"` : $msg  " >> $logfile
            echo "[INFO] `date "+%Y-%m-%d %H:%M:%S"` : Please refer to the Troubleshooting Guide for help on how to resolve this error.  " >> $logfile
            unset DOCKER_CONTENT_TRUST
            unset DOCKER_CONTENT_TRUST_SERVER
            exit ${exitCode}
            ;;
        *)
            echo "$msg"
            echo "[INFO] `date "+%Y-%m-%d %H:%M:%S"` : $msg  " >> $logfile ;;
    esac
}


readLoginInfo() {
    if [[ ! -z ${username} ]] ; then
        usernameTemp="${username}"
        usernameTemp1="($usernameTemp)"
        username=""
    fi
    if [[ ${userFlag} -eq 0 ]] ; then
        read -p "Username${usernameTemp1}:" username
    fi
    if [[ "${username}" == "" ]] ; then
        username=${usernameTemp}
    fi
    stty -echo
    read -p "Password:" password
    stty $old
    echo ""
}

dockerLogin() {
#check if docker is installed on this host
    if [[ $(docker info >>${logfile} 2>&1; echo $?) != 0 ]] ; then
        write_log "fatal" "Docker does not seem to be installed on this host."
    fi
    i=0
    if [[ -z ${registryhost} ]] ; then
        hubName="Docker Hub"
    else
        hubName=${registryhost}
    fi
    write_log "begin" "Contacting ${hubName} ..."
    while [[ -z ${username} ]] || [[ -z ${password} ]] || [[ $(docker login -u ${username} -p ${password} ${registryhost} >>${logfile} 2>&1; echo $?) != 0 ]] ; do
        ((i++))
        if [[ ${i} == 4 ]]; then
            write_log "end" " FAILED"
            write_log "fatal" "Failed to login to ${hubName}, please make sure your user name, password and network/proxy configuration are correct."
        fi
        if [[ ${i} != 1 ]] ; then
            write_log "end" " FAILED"
            write_log "error" "Failed to login to ${hubName}, please make sure your user name, password and network/proxy configuration are correct."
            write_log "begin" "Retrying contacting ${hubName} ..."
        fi
        write_log "end" " "
        write_log "info" "Please enter your ${hubName} credentials."
        readLoginInfo
    done
    if [[ ${i} -gt 0 ]] ; then
        write_log "info" "Successfully logged into ${hubName}."
    else
        write_log "end" " OK"
    fi
    write_log "debug" "Successfully logged into ${hubName}."
}

loadImageSet() {
    suiteSet=`cat ${toolsDir}${imageSetFileName} | ${toolsDir}${jqFileName} --raw-output '.suite'`
#    selectSuite=`cat ${toolsDir}${imageSetFileName} | ${toolsDir}${jqFileName} --raw-output '.display_name'`
    organization=`cat ${toolsDir}${imageSetFileName} | ${toolsDir}${jqFileName} --raw-output '.org_name'`
    versionSet=`cat ${toolsDir}${imageSetFileName} | ${toolsDir}${jqFileName} --raw-output '.version'`
    selectVersion=${versionSet}
    selectSuite=${suiteSet}
    imageSetFlag=1
}

listSuite() {
    # get token
    echo "Retrieving token ..."
    TOKEN=$(curl -s --connect-timeout 20 -H "Content-Type: application/json" -X POST -d '{"username": "'${username}'", "password": "'${password}'"}' https://hub.docker.com/v2/users/login/ | ${toolsDir}${jqFileName} -r .token)
    if [[ -z ${TOKEN} ]] ; then
        write_log "error" "Unable to get Docker Hub Token."
        write_log "error" "Please check your ENV https_proxy on your host."
    fi
    # get list of repositories
    echo "Retrieving repository list ..."
    suiteNameListTmp=("")
    local sn=0
    REPO_LIST=$(curl -s --connect-timeout 20 -H "Authorization: JWT ${TOKEN}" https://hub.docker.com/v2/repositories/${organization}?page_size=100 | ${toolsDir}${jqFileName} -r '.results|.[]|.name')
    if [[ -z ${REPO_LIST} ]] ; then
        write_log "error" "Unable to get suite name list."
    fi
    #echo $REPO_LIST
    for repositories in ${REPO_LIST}
    do
        if [[ ${repositories} =~ "itom-platform-data-" ]] ; then
            repositorie=($(echo ${repositories##*-} | tr '[a-z]' '[A-Z]'))
            suiteNameListTmp[${sn}]=${repositorie}
            sn=$((sn+1))
        fi
    done
}

getDeploymentInfo() {
    local deploymentsJson="$1"
    organization=`cat ${deploymentsJson} | ${toolsDir}${jqFileName} --raw-output '.registry_orgname'`
    if [[ "${organization:$((-1))}" != "/" ]] && [[ ! -z ${organization} ]] ; then
        organization="${organization}/"
    fi
    orgFlag=1
    if [[ ! -z $(cat ${deploymentsJson} | ${toolsDir}${jqFileName} --raw-output '.deployments[]') ]] ; then
        installedSuiteSet=($(echo $(cat ${deploymentsJson} | ${toolsDir}${jqFileName} --raw-output '.deployments[].suites[].suite') | tr '[A-Z]' '[a-z]'))
        installed_suite_name_list=($(echo ${installedSuiteSet} | tr '[A-Z]' '[a-z]'))
        installedVersion=`cat ${deploymentsJson} | ${toolsDir}${jqFileName} --raw-output '.deployments[].suites[].version'`
        installedBaseVersion=`cat ${deploymentsJson} | ${toolsDir}${jqFileName} --raw-output '.deployments[].suites[].base_version'`
        suiteSet=${installedSuiteSet}
    else
        installedSuiteSet=("")
        installed_suite_name_list=("")
        installedVersionSet=""
        installedBaseVersion=""
    fi
}

getSuiteImageList() {
    local suiteImageListFull=("")
    suiteImageList=("")
    local suiteImageJson="$1"
    local suiteImageNum=`cat ${suiteImageJson} | ${toolsDir}${jqFileName} '.images | length'`
    local i=0
    while [[ ${i} -lt ${suiteImageNum} ]] ; do
        fullString=`cat ${suiteImageJson} | ${toolsDir}${jqFileName} --raw-output '.images['${i}'].image'`
        splitImageUrlElement ${fullString}
        suiteImageListFull[${i}]="${imageName}:${imageTag}"
        ((i++))
    done
    #get feature-set-image
    local featureSetsNum=`cat ${suiteImageJson} | ${toolsDir}${jqFileName} '.feature_sets? | length'`
    local j=0
    local featureSetSelected=(`cat ${suiteImageJson} | ${toolsDir}${jqFileName} '.feature_sets[]?.selected?'`)
    local feautreSetImages=("")
    while [[ ${j} -lt ${featureSetsNum} ]] ; do
        #if [[ ${featureSetSelected[${j}]} ]] ; then
        feautreSetImages=(`cat ${suiteImageJson} | ${toolsDir}${jqFileName} --raw-output '.feature_sets['${j}']?.images[]?.image'`)
        for featureImage in ${feautreSetImages[@]} ; do
            fullString=${featureImage}
            splitImageUrlElement ${fullString}
            suiteImageListFull[${i}]="${imageName}:${imageTag}"
            ((i++))
        done
        #fi
        ((j++))
    done
    suiteImageList=$(for tmp in ${suiteImageListFull[@]}; do echo $tmp; done|sort -u|xargs)
}

combineSuiteInfo() {
    local suiteJson="\"suiteInfoList\" : ["
    for suite in ${suite_name_list[@]} ; do
        suiteFile="${tempDir}suite-metadata/suiteinfo.json"
        if [[ -f "${suiteFile}" ]] ; then
            if [[ "${suiteJson:$((-1))}" == "[" ]] ; then
                suiteJson="${suiteJson} $(cat ${tempDir}suite-metadata/suiteinfo.json)"
            else
                suiteJson="${suiteJson} , $(cat ${tempDir}suite-metadata/suiteinfo.json)"
            fi
        fi
        if [[ "${suite_name_list[${#suite_name_list[*]}-1]}" == "${suite}" ]] ; then
            suiteJson="${suiteJson} ]"
        fi
    done
    cat > ${tempDir}suite-metadata/suiteinfo.json <<-JSON
{
$(echo $"$suiteJson")
}
JSON
}

runContainer() {
    suite_name=$1
    local currentPath=$(pwd)
    cd ${tempDir}
    if [[ -d "${tempDir}suite-metadata" ]] ; then
        rm -rf ${tempDir}suite-metadata
    fi
    mkdir -p ${tempDir}suite-metadata
    docker rm -f ${suite_name} >/dev/null 2>&1
    if [[ $(docker run -i -v ${tempDir}suite-metadata:/pv --name=${suite_name} ${registryhost}${organization}itom-platform-data-${suite_name}:${suiteDataTag} >>${logfile} 2>&1; echo $?) != 0 ]] ; then
        write_log "end" " FAILED"
        write_log "fatal" "Unable to run ${suite_name} data container."
    else
        docker rm -f ${suite_name} >>${logfile} 2>&1
        mv ${tempDir}suite-metadata/feature ${tempDir}suite-metadata/suite_feature
        combineSuiteInfo
        local versionListTmp=(`ls ${tempDir}suite-metadata/suite_feature`)
        mkdir -p ${tempDir}suite-metadata/suite_feature/${suite_name}
        for versionTmp in ${versionListTmp[@]} ; do
            if [[ "${versionTmp}" != "${suite_name}" ]] ; then
                mv ${tempDir}suite-metadata/suite_feature/${versionTmp} ${tempDir}suite-metadata/suite_feature/${suite_name}/${versionTmp}
            fi
        done
    fi
#    write_log "end" " OK"
    write_log "debug" "Successfully received the ${suite_name}-install-data."
}

imageOperation() {
  docker_operation=$1
  suite_name=$2
  op_target=0
  if [[ ${docker_operation} == "pull" ]] ; then
    operator="pull"
    op_target=1
  else
    operator="rmi -f"
    op_target=0
  fi
  j=0
  while [[ $(docker ${operator} ${registryhost}${organization}itom-platform-data-${suite_name}:${suiteDataTag} >>${logfile} 2>&1; echo $?) != 0 ]] ; do
    ((j++))
    if [[ ${j} == 4 ]]; then
        if [[ $(docker images|grep ${registryhost}${organization}itom-platform-data-${suite_name}|grep ${suiteDataTag}|wc -l) == ${op_target} ]] ; then
            break
        fi
        write_log "end" " FAILED"
        if [[ ${docker_operation} == "pull" ]] && [[ ${dockerContentTrust} == 1 ]] ; then
            write_log "error" "You have set Docker-Content-Trust on, please make sure the ${suite_name} data image is signed."
        fi
        if [[ "${docker_operation}" == "pull" ]] ; then
            write_log "error" "Failed to ${docker_operation} the ${suite_name} data image."
            write_log "error" "You may not have access or be entitled to the '${suite_name}' ITOM Suite."
            write_log "error" "Please request access to one of our operations team based on your geography: "
            write_log "fatal" "    dockersupport.apj@microfocus.com, dockersupport.emea@microfocus.com"
        else
            write_log "fatal" "Failed to ${docker_operation} the ${suite_name} data image."
        fi
    fi
  done
#  echo "Success ${docker_operation} ${suite_name} image."
}

getSuiteFeatureData() {
    write_log "begin" "Downloading suite release information ..."
    if [[ ! -z ${installedSuiteSet} ]] ; then
        suite_name_list=${installedSuiteSet}
        suiteSet=${installedSuiteSet}
    fi
    local currentPath=$(pwd)
    cd ${tempDir}
    temp_dir="suite-metadata"
    mkdir -p ${temp_dir}
    for suite in ${suite_name_list[@]} ; do
    #  echo ${suite}
        imageOperation pull ${suite}
        runContainer ${suite}
        imageOperation delete ${suite}
    done
    tar -czf ${suite}-install-data ${temp_dir}
    cd ${currentPath}
    mkdir -p ${dir}
    /usr/bin/rm -f ${dir}*-install-data >/dev/null 2>&1
    /usr/bin/mv -f ${tempDir}${suite}-install-data ${dir}.
    write_log "end" " OK"
    write_log "info" "Successfully downloaded the $(echo ${suite} | tr '[a-z]' '[A-Z]') suite metadata file: ${dir}${suite}-install-data ..."
    write_log "debug" "Successfully got the suite feature data."
}

getSuiteId() {
    local suite_name=$1
    suite_name_list=($(cat suiteinfo.json|${toolsDir}${jqFileName} '.suiteInfoList[].suite'|xargs))
    local i=0
    for suite in ${suite_name_list[@]}
    do
        if [[ ${suite} == ${suite_name} ]] ; then
            break
        else
            i=$((i+1))
        fi
    done
    echo $i
}

getLatestVersion() {
    local arr=($@)
    for (( i=0 ; i<${#arr[@]} ; i++ ))
    do
        for (( j=${#arr[@]} - 1 ; j>i ; j-- ))
        do
            if  [[ ${arr[j]} > ${arr[j-1]} ]]
            then
                t=${arr[j]}
                arr[j]=${arr[j-1]}
                arr[j-1]=$t
            fi
        done
    done
    echo ${arr[0]}
}

sortVersionList() {
    local arr=($@)
    for (( i=0 ; i<${#arr[@]} ; i++ ))
    do
        for (( j=${#arr[@]} - 1 ; j>i ; j-- ))
        do
            if  [[ ${arr[j]} < ${arr[j-1]} ]]
            then
                t=${arr[j]}
                arr[j]=${arr[j-1]}
                arr[j-1]=$t
            fi
        done
    done
    echo ${arr[@]}
}

listSuiteVersions() {
    local latestVersion=""
    for suite in ${suite_name_list[@]} ; do
        local suiteList="Suite ${suite}: "
        local version=""
        local versionList=($(cat ${tempDir}suite-metadata/suiteinfo.json|${toolsDir}${jqFileName} --raw-output '.suiteInfoList[].versions[].version'|xargs))
        local i=0
        local j=0
        local checkedVersionList=("")
        local checkKeyList=("simple_update" "complex_update")
        for versionCheck in ${versionList[@]} ; do
            local checkFlag=0
            if [[ "${versionCheck}" == "${installedVersion}" ]] ; then
                ((i++))
                continue
            fi
            for checkKey in ${checkKeyList[@]} ; do
                expression=$(cat ${tempDir}suite-metadata/suiteinfo.json|${toolsDir}${jqFileName} --raw-output '.suiteInfoList[].versions['${i}'].'${checkKey}'')
                supportedVersion=($(cat ${tempDir}suite-metadata/suite_feature/${suite}/${versionCheck}/${suite}_suitefeatures.${versionCheck}.json |${toolsDir}${jqFileName} --raw-output '.core_platform_versions_supported[]?'|xargs))
                if [[ "${expression}" == "'null'" ]] ; then
                    expression='^*'
                fi
                if ( [[ -z ${installedVersion} ]] || ( [[ $(echo "${installedVersion}"|grep "${expression}"|wc -l) -gt 0 ]] && [[ ${checkFlag} -ne 1 ]] )) && [[ "${supportedVersion[@]}" =~ ${CDF_VERSION} ]] && [[ ${checkFlag} -ne 1 ]] ; then
                    checkedVersionList[$j]="${versionCheck}"
                    checkFlag=1
                    ((j++))
                fi
            done
            ((i++))
        done
        #if [[ -z ${installedVersion} ]] ; then
        #    versionList=(`sortVersionList ${versionList[@]}`)
        #else
        versionList=(`sortVersionList ${checkedVersionList[@]}`)
        #fi
        local separator=""
        latestVersion=`getLatestVersion ${versionList[@]}`
        for version in ${versionList[@]} ; do
            if [[ "${suiteList:$((-1))}" == " " ]] ; then
                separator=""
            else
                separator=","
            fi
            if [[ "${latestVersion}" == "${version}" ]] ; then
                suiteList="${suiteList}${separator}${version} (latest)"
            else
                suiteList="${suiteList}${separator}${version}"
            fi
        done
        echo
        if [[ ${#versionList[@]} -eq 0 ]] && [[ ! -z ${installedVersion} ]] ; then
            write_log "fatal" "No version can upgrade from your installed version."
        elif [[ ${#versionList[@]} -eq 0 ]] && [[ -z ${installedVersion} ]] ; then
            write_log "fatal" "No version can install on your host."
        else
            echo ${suiteList}
        fi
        echo
#        write_log "info" "Successfully got $(echo $suite | tr '[a-z]' '[A-Z]') suite version list ... "
    done
    if [[ -z ${opFlag} ]] ; then
        if [[ -z ${suiteSet} ]] ; then
            read -p "Please enter the suite you want to download: " selectSuite
            selectSuite=$(echo $selectSuite | tr '[A-Z]' '[a-z]')
        else
            selectSuite=${suiteSet}
        fi
        if [[ "$(echo ${versionSet} | tr '[A-Z]' '[a-z]')" == "latest" ]] ; then
            versionSet=${latestVersion}
        fi
        local t=0
        selectVersion=${versionSet}
        if ! [[ "${versionList[@]}" =~ ${selectVersion} ]] ; then
            write_log "error" "You entered a wrong version."
        fi
        while [[ -z ${versionSet} ]] || ! [[ "${versionList[@]}" =~ ${versionSet} ]] ; do
            read -p "Please enter the version of the $(echo $selectSuite | tr '[a-z]' '[A-Z]') suite you want to download: " selectVersion
            if [[ -z ${selectVersion} ]] || [[ "$(echo ${selectVersion} | tr '[A-Z]' '[a-z]')" == "latest" ]] ; then
                selectVersion=${latestVersion}
            fi
            if [[ "${versionList[@]}" =~ ${selectVersion} ]] ; then
                break
            else
                write_log "error" "You entered a wrong version."
                ((t++))
            fi
        done
        write_log "info" "Starting the download of the $(echo $selectSuite | tr '[a-z]' '[A-Z]') suite, version ${selectVersion} ..."
    fi
}

getDownloadedImageList() {
    downloaded=$1
    targetImageName=$2
    if [[ -f "${dir}${downloaded}" ]] ; then
        tar -x -z -C ${dir} -f ${dir}${downloaded} repositories  >/dev/null 2>&1
        MSG=`cat ${dir}repositories 2>/dev/null`
        MSG1=${MSG%:*}
        NAC=${MSG1%:*}
        NAL=${NAC:2}
        NAF=${NAL%\"*}
        TAGR=${MSG1%\"*}
        TAGF=${TAGR##*\"}
        URL=${NAF%%/*}
        IMNA=${NAF##*/}
        if [[ "${IMNA}:${TAGF}" == "${targetImageName}" ]] ; then
            echo "0"
        else
            rm -f ${dir}${downloaded} >/dev/null 2>&1
            echo "1"
        fi
        #echo "$IMNA:$TAGF"
        rm -f ${dir}repositories >/dev/null 2>&1
    else
        echo "1"
    fi
}

splitImageUrlElement() {
    imageName=""
    imageTag=""
    imageNameAndTag=""
    imageUrl=$1
    OLD_IFS="$IFS"
    IFS="/"
    elementArr=(${imageUrl})
    IFS="$OLD_IFS"
    imageNameAndTag=${elementArr[${#elementArr[@]}-1]}
    imageName=${imageNameAndTag%%:*}
    imageTag=${imageNameAndTag##*:}
}

pullSuiteImages() {
    deltaImageList=("")
    deltaImageNum=0
    local file_count=0
    jsondir="${tempDir}suite-metadata/suite_feature/${suite}/${selectVersion}/${selectSuite}_suitefeatures.${selectVersion}.json"
    local file_count=$(ls ${dir}*.tar.gz 2>/dev/null|wc -w)
    if [ ${file_count} -eq 0 ]; then
        mkdir -p ${dir}
        write_log "info" "The images will be downloaded into path: ${dir}"
    else
        if [[ -z ${answer}  ]] ; then
            read -p "The images in the \"${dir}\" directory will be overwritten if you continue. Overwrite [Y/N]?" answer
            case $answer in
                Y | y)
                    write_log "info" "The images in the \"${dir}\" directory have been overwritten."
                    rm -f ${dir}*.tar.gz ${dir}repositories ${dir}*.json ${dir}*.tar;;
                N | n)
                    write_log "info" "The images in the \"${dir}\" directory will not be overwritten, make sure your image tar files are correct."
                    write_log "info" "Checking for breakpoint ..."
                    ;;
                *)
                    exit 0
                    ;;
            esac
        else
            write_log "info" "The images in the \"${dir}\" directory will be overwritten."
            rm -f ${dir}*.tar.gz ${dir}repositories ${dir}*.json ${dir}*.tar
        fi
    fi
    begin_time=$(date +%s)
    if [[ -z ${imageSetFlag} ]] ; then
        getSuiteImageList ${jsondir}
    elif [[ ${imageSetFlag} -eq 1 ]] ; then
        getSuiteImageList ${toolsDir}${imageSetFileName}
    fi
    if [[ ${imageListJsonFlag} -eq 1 ]] ; then
        registryImageList=("")
    else
        getRegistryImageList
    fi
    for checkImageExists in ${suiteImageList[@]} ; do
        if [[ ${#registryImageList[@]} -eq 0 ]] ; then
            deltaImageList=(${suiteImageList[@]})
            deltaImageNum=${#suiteImageList[@]}
        else
            local flag=0
            for registryImage in ${registryImageList[@]} ; do
                if [[ "${registryImage}" == "${organization}${checkImageExists}" ]] ; then
                    flag=1
                    break
                fi
            done
            if [[ ${flag} -eq 0 ]] ; then
                deltaImageList[${deltaImageNum}]=${checkImageExists}
                ((deltaImageNum++))
            fi
        fi
    done
    echo "${deltaImageList[@]}"|jq -R --slurp 'split(" ")'|jq ' {images: [{image: .[]}]}' > ${dir}delta_images.json
    imageMin=0
    mkdir -p "${syncLogDir}"
    echo -e "\c" > ${syncLogDir}download-suite-image-progress.log
    while [ ${imageMin} -lt ${deltaImageNum} ]
    do
        splitImageUrlElement ${deltaImageList[${imageMin}]}
        write_log "begin" "Downloading image [$((${imageMin} + 1))/${deltaImageNum}] ${registryhost}${organization}${imageName}:${imageTag} ..."
        if [[ $(getDownloadedImageList ${organization%%/*}-${imageName}-${imageTag}.tar.gz ${imageName}:${imageTag}) -eq 0 ]] ; then
            successFlag=1
            existsFlag=1
        else
            existsFlag=0
            local i=0
            local successFlag=0
            while [ ${i} -lt ${reTry} ]
            do
                write_log "debug" "docker pull ${registryhost}${organization}${imageName}:${imageTag}"
                docker pull ${registryhost}${organization}${imageName}:${imageTag} >>${logfile} 2>&1
                if [ $? -eq 0 ]; then
                    successFlag=1
                    break;
                else
                    write_log "debug" "${registryhost}${organization}${imageName}:${imageTag} pull failed, retry in 2 seconds ..."
                    i=$(( $i + 1 ))
                    sleep 2
                fi
            done
            write_log "debug" "docker save -o ${dir}${organization%%/*}-${imageName}-${imageTag}.tar ${registryhost}${organization}${imageName}:${imageTag}"
            docker save -o ${dir}${organization%%/*}-${imageName}-${imageTag}.tar ${registryhost}${organization}${imageName}:${imageTag} >>${logfile} 2>&1
            if [[ $? -eq 0 ]] && [[ ${successFlag} -ne 0 ]] ; then
                successFlag=1
            else
                successFlag=0
            fi
            write_log "debug" "gzip ${dir}${organization%%/*}-${imageName}-${imageTag}.tar"
            gzip ${dir}${organization%%/*}-${imageName}-${imageTag}.tar >>${logfile} 2>&1 &
            gzipList[${imageMin}]="$! ${registryhost}${organization}${imageName}:${imageTag} ${organization%%/*}-${imageName}-${imageTag}.tar.gz ${imageMin}"
            if [[ $? -eq 0 ]] && [[ ${successFlag} -ne 0 ]]; then
                successFlag=1
            else
                successFlag=0
            fi
        fi
        if [[ ${successFlag} -eq 1 ]] ; then
            if [[ ${existsFlag} -eq 1 ]] ; then
                write_log "end" " Already existed"
            else
                write_log "end" " OK"
            fi
            echo "${organization%%/*}-${imageName}-${imageTag}.tar.gz ${successFlag}" >> ${syncLogDir}download-suite-image-progress.log
        else
            write_log "end" " FAILED"
            array[${imageMin}]=${registryhost}${organization}${imageName}:${imageTag}
            echo "${organization%%/*}-${imageName}-${imageTag}.tar.gz ${successFlag}" >> ${syncLogDir}download-suite-image-progress.log
        fi
        imageMin=$(( ${imageMin} + 1 ))
    done
    if [[ "${#gzipList[@]}" -gt 0 ]] ; then
        write_log "info" "Starting gzip image tar files..."
    fi
    for gizpFile in "${gzipList[@]}" ; do
        gzipInfo=(${gizpFile})
        gzipPid=${gzipInfo[0]}
        gzipImageName=${gzipInfo[1]}
        gzipFileName=${gzipInfo[2]}
        imageNumber=${gzipInfo[3]}
        if [[ ! -z ${gzipPid} ]] ; then
            wait ${gzipPid}
            gzipRc=$?
            if [[ ${gzipRc} -eq 0 ]] ; then
                write_log "debug" "Successfully saved image ${gzipImageName} into file ${gzipFileName}."
            else
                write_log "error" "Failed to save image ${gzipImageName} into file ${gzipFileName}."
                array[${imageNumber}]=${gzipImageName}
                successedTmp="${gzipFileName} 1"
                failedTmp="${gzipFileName} 0"
                sed -i -e "s%${successedTmp}%${failedTmp}%g" ${syncLogDir}download-suite-image-progress.log
            fi
            if [[ "${quickFlag}" != "on" ]] ; then
                write_log "debug" "docker rmi ${registryhost}${organization}${imageName}:${imageTag}"
                docker rmi ${registryhost}${organization}${imageName}:${imageTag} >>${logfile} 2>&1
            fi
        else
            continue
        fi
    done
    end_time=$(date +%s)
    cost_time=$(( ${end_time} - ${begin_time} ))
    successNum=$((${deltaImageNum} - ${#array[@]} ))
    if [[ ${#array[@]} -gt 0 ]] ; then
        write_log "info" "${successNum} images downloaded successfully in ${cost_time} seconds."
        if [[ ${#array[@]} -gt 1 ]] ; then
            write_log "info" "${#array[@]} images failed to download."
        else
            write_log "info" "${#array[@]} image failed to download."
        fi
        if [[ ${dockerContentTrust} == 1 ]] ; then
            write_log "error" "You have set Docker-Content-Trust on, please make sure the ${suite_name} suite images are signed."
        fi
        write_log "debug" "Failed images:"
        for failImage in ${array[@]}
        do
            write_log "debug" "${failImage}"
        done
        write_log "info" "Download completed with errors."
    else
        write_log "info" "Download completed in ${cost_time} seconds."
    fi
    echo "[${successNum}/${deltaImageNum}] ${cost_time}" >> ${syncLogDir}download-suite-image-progress.log
}

getRegistryImageList() {
    local registryImageName=""
    local registryImageTag=""
    registryImageList=("")
    registryImageNum=`cat ${toolsDir}${imageListFileName} | ${toolsDir}${jqFileName} '.images | length'`
    local i=0
    local j=0
    while [ ${i} -lt ${registryImageNum} ] ; do
        local k=0
        registryImageName=`cat ${toolsDir}${imageListFileName} | ${toolsDir}${jqFileName} --raw-output '.images['${i}'].name'`
        #splitImageUrlElement ${registryImageName}
        #registryImageName=${imageName}
        registryImageTagNum=`cat ${toolsDir}${imageListFileName} | ${toolsDir}${jqFileName} '.images['${i}'].tags | length'`
        while [ ${k} -lt ${registryImageTagNum} ] ; do
            registryImageTag=`cat ${toolsDir}${imageListFileName} | ${toolsDir}${jqFileName} --raw-output '.images['${i}'].tags['${k}']'`
            registryImageList[${j}]="${registryImageName}:${registryImageTag}"
#            echo $j
#            echo ${registryImageList[@]}
            ((j++))
            ((k++))
        done
        ((i++))
    done
}

if [[ -f "/tmp/.image-sync-lock" ]] ; then
    write_log "error" "Error: one instance is already running and only one instance is allowed at a time. "
    write_log "error" "Check to see if another instance is running."
    write_log "fatal" "If the instance stops running, delete /tmp/.image-sync-lock file."
else
    echo "$$" > /tmp/.image-sync-lock
fi

if [[ "${toolsDir:$((-1))}" != "/" ]] ; then
    toolsDir="${toolsDir}/"
fi
if  [[ ! -f ${toolsDir}${jqFileName} ]] ; then
    write_log "error" "Can not find jq in ${toolsDir} ."
    write_log "error" "Or you can specify the path of jq with option \"-D\"."
    usage
fi
if [[ -z ${username} ]] && [[ ! -z ${password} ]] ; then
    write_log "error" "Cannot find the \"-u|--user\" option in case of the \"-p|--pass\" option is provided."
    usage
fi
if [[ ! -f ${toolsDir}${imageListFileName} ]] && [[ ! -f ${toolsDir}${deploymentsFileName} ]] && [[ ! -f ${toolsDir}${imageSetFileName} ]] ; then
    write_log "error" "Warning: Can not find deployments.json, image-list.json or image-set.json in ${toolsDir} ."
    write_log "error" "         Please wait a few minutes and make sure your suite-installer pods is running."
    write_log "error" "         Or you can specify the path of deployments.json, image-list.json or image-set.json with option \"-D\"."
fi
if [[ ! -f ${toolsDir}${imageListFileName} ]] ; then
    imageListJsonFlag=1
fi
if [[ ! -f ${toolsDir}${deploymentsFileName} ]] ; then
    deploymentsJsonFlag=1
fi
if [[ ${dockerContentTrust} -eq 1 ]] ; then
    if [[ $(curl --help >>${logfile} 2>&1; echo $?) -eq 0 ]] ; then
        if [[ $(curl -k --connect-timeout 10 ${noTaryServer} >>${logfile} 2>&1; echo $?) -eq 0 ]] ; then
            export DOCKER_CONTENT_TRUST=${dockerContentTrust}
            export DOCKER_CONTENT_TRUST_SERVER=${noTaryServer}
            write_log "info" "Successfully set Docker-Content-Trust on."
#            write_log "info" "Docker-Notary-Server is set to \"${noTaryServer}\"."
        else
            write_log "fatal" "Docker-Notary-Server(${noTaryServer}) can not be accessed, please make sure your host can access the Docker-Notary-Server URL."
        fi
    else
        write_log "fatal" "Command curl not found."
    fi
fi

if [[ "${dir:$((-1))}" != "/" ]] ; then
    dir="${dir}/"
fi
if [[ -f ${toolsDir}${deploymentsFileName} ]] ; then
    getDeploymentInfo "${toolsDir}${deploymentsFileName}"
elif [[ -f ${toolsDir}${imageSetFileName} ]] ; then
    loadImageSet
fi
dockerLogin
if [[ "${hubName}" == "Docker Hub" ]] && [[ -z ${imageSetFlag} ]] ; then
    listSuite
fi
if [[ -z ${suiteSet} ]] ; then
    if [[ ${#suiteNameListTmp[@]} -eq 2 ]] ; then
        suiteNameListTmp[1]="or ${suiteNameListTmp[1]}"
    elif [[ ${#suiteNameListTmp[@]} -gt 2 ]] ; then
        listi=0
        for suitename in ${suiteNameListTmp[@]} ; do
            if [[ ${listi} -eq $((${#suiteNameListTmp[@]}-1)) ]] ; then
                suiteNameListTmp[$((${#suiteNameListTmp[@]}-1))]="or ${suitename}"
            elif [[ ${listi} -ge 0 ]] && [[ ${listi} -lt $((${#suiteNameListTmp[@]}-2)) ]] ; then
                suiteNameListTmp[${listi}]="${suitename},"
            fi
            listi=$(( ${listi} + 1 ))
        done
    fi
    suitename=""
    if [[ ${#suiteNameListTmp[@]} -ne 0 ]] ; then
        suitename="(${suiteNameListTmp[@]})"
    fi
    echo "Which suite do you want to download? ${suitename} "
    read -p "Suite Name: " suiteSet
fi
if [[ ! -z ${maxRetry} ]] ; then
    reTry=${maxRetry}
fi
suiteSet=($(echo ${suiteSet} | tr '[A-Z]' '[a-z]'))
suite_name_list=($(echo ${suiteSet} | tr '[A-Z]' '[a-z]'))
if [[ "${registryhost:$((-1))}" != "/" ]] && [[ ! -z ${registryhost} ]] ; then
    registryhost="${registryhost}/"
fi

if [[ "${organization:$((-1))}" != "/" ]] && [[ ! -z ${organization} ]] ; then
    organization="${organization}/"
fi

getSuiteFeatureData
if [[ -z ${imageSetFlag} ]] ; then
    listSuiteVersions
else
    write_log "info" "Starting the download of the $(echo $selectSuite | tr '[a-z]' '[A-Z]') suite, version ${selectVersion} ..."
fi
if [[ "${opFlag}" != "list" ]] ; then
    if [[ "${quickFlag}" == "on" ]] ; then
        write_log "info" "You have enabled(by default) the quick download mode, downloaded images will not be deleted. Make sure that you have enough device space on your host."
        write_log "info" "Run downloadimages.sh with \"-q off\" to disable the quick download mode."
    fi
    pullSuiteImages
    if [[ ${deploymentsJsonFlag} -ne 1 ]] ; then
        cat ${toolsDir}${deploymentsFileName} | ${toolsDir}${jqFileName} '. |= .+ {"updates":[{"update_version": "'${selectVersion}'"}]}' > ${dir}${deploymentsFileName}
    else
        echo "{}" | ${toolsDir}${jqFileName} '. |= .+ {"updates":[{"update_version": "'${selectVersion}'"}]}' > ${dir}${deploymentsFileName}
    fi
    /bin/cp -f ${syncLogDir}download-suite-image-progress.log ${dir}download-suite-image-progress.log
    if [[ ${#array[@]} -eq 0 ]] ; then
        write_log "info" "Successfully downloaded the $(echo $selectSuite | tr '[a-z]' '[A-Z]') suite version: ${selectVersion}. "
    else
        write_log "info" "Downloaded the $(echo $selectSuite | tr '[a-z]' '[A-Z]') suite version: ${selectVersion} with errors. "
    fi
fi
rm -rf ${tempDir}suite-metadata
unset DOCKER_CONTENT_TRUST
unset DOCKER_CONTENT_TRUST_SERVER
