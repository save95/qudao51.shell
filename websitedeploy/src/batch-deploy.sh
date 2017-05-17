#!/bin/sh

readonly NGINX_BIN=`sed '/^nginx_bin_dir\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_CONF_DIR=`sed '/^web_nginx_conf_dir\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_ROOT_DIR=`sed '/^web_root_dir\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_USER=`sed '/^web_user\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_USER_GROUP=`sed '/^web_user_group\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`

# todo check params

# const
readonly MS_FILE='web.conf.ms'
readonly SERVER_NAME_PATTERN="^([a-z0-9]+)((.[-a-z0-9]+)+)$"

readonly LOCK_FILE='.lock'
readonly VALID_TMP_FILE='valid.tmp'
readonly SUCCESS_LOG_FILE='success.log'
readonly FAILD_LOG_FILE='faild.log'
readonly DATE=`date '+%F %T'`
readonly BACKUP_EXT=`date '+%F_%T'`

# check lock
if [ -f ${LOCK_FILE} ]; then
    printf "\E[31m[Error]\E[0m The program is being used.\n"
    exit;
fi

touch ${LOCK_FILE}


function quitRun() {
    rm -f ${VALID_TMP_FILE}
    rm -f ${LOCK_FILE}
    
    if [ -f ${SUCCESS_LOG_FILE} ]; then
        mv -f ${SUCCESS_LOG_FILE} "${SUCCESS_LOG_FILE}.${BACKUP_EXT}"
    fi
    if [ -f ${FAILD_LOG_FILE} ]; then
        mv -f ${FAILD_LOG_FILE} "${FAILD_LOG_FILE}.${BACKUP_EXT}"
    fi
    exit;
}

function check() {
    local vaild=1
    local serverName=$1
    local rootDir=$2
    local lineStr="${serverName} ${rootDir}"

    printf "%-30s%-38s" "${serverName}" "WEB_ROOT_PATH/${rootDir}"

    # check domain
    if [[ "${serverName}" =~ ${SERVER_NAME_PATTERN} ]]; then
        printf "\E[32m%-12s\E[0m" "[success]"
    else
        printf "\E[31m%-12s\E[0m" "[invalid]"
        vaild=0
    fi

    # check web dir
    local SITE_ROOT_DIR="${WEB_ROOT_DIR}/${rootDir}"
    if [ ! -d "${SITE_ROOT_DIR}" ]; then
        printf "\E[32m%-12s\E[0m" "[success]"
    else
        printf "\E[31m%-12s\E[0m" "[existed]"
        vaild=0
    fi


    # check the nginx .conf file"
    local CONF_FILE="${WEB_CONF_DIR}/${serverName}.conf"
    if [ ! -f "${CONF_FILE}" ]; then
        printf "\E[32m%-12s\E[0m" "[success]"
        if [ ${vaild} == 1 ]; then
            echo ${lineStr} >> ${VALID_TMP_FILE}
        fi
    else
        printf "\E[31m%-12s\E[0m" "[existed]"
    fi

    printf "\n"
}

function setWeb() {
    local ENTER_NEXT=0
    local serverName=$1
    local rootDir=$2
    local lineStr="${serverName} ${rootDir}"

    printf "%-30s%-38s" "${serverName}" "WEB_ROOT_PATH/${rootDir}"

    # make dir
    local SITE_ROOT_DIR="${WEB_ROOT_DIR}/${rootDir}"
    if [ ! -d "${SITE_ROOT_DIR}" ]; then
        mkdir -p ${SITE_ROOT_DIR} > /dev/null 2>&1
        chown -R ${WEB_USER}.${WEB_USER_GROUP} ${SITE_ROOT_DIR} > /dev/null 2>&1

        if [ "$?" == 1 ]; then
            printf "\E[31m%-12s%-12s\E[0m\n" "[faild]" "[skip]"
            echo ${lineStr} >> ${FAILD_LOG_FILE}
            ENTER_NEXT=0
        else
            printf "\E[32m%-12s\E[0m" "[success]"
            ENTER_NEXT=1
        fi
    else
        printf "\E[32m%-12s\E[0m" "[existed]"
        ENTER_NEXT=1
    fi

    # make .conf file
    if [ "${ENTER_NEXT}" == 1 ]; then
        local CONF_FILE="${WEB_CONF_DIR}/${serverName}.conf"
        if [ ! -f "${CONF_FILE}" ]; then
            sed "s|SERVER_NAME|${serverName}|g; s|ROOT_DIR|${rootDir}|g" ${MS_FILE} > ${serverName}.conf.tmp
            mv ${serverName}.conf.tmp ${CONF_FILE} > /dev/null 2>&1
            if [ "$?" == 1 ]; then
                printf "\E[31m%-12s\E[0m\n" "[faild]"
                echo ${lineStr} >> ${FAILD_LOG_FILE}
            else
                printf "\E[32m%-12s\E[0m\n" "[success]"
                echo ${lineStr} >> ${SUCCESS_LOG_FILE}
            fi
        else
            printf "\E[31m%-12s\E[0m" "[existed]"
        fi
    else
        printf "\E[31m%-12s\E[0m" "[skip]"
    fi
}

function statistics() {
    local LINE_NUM=`cat $1|wc -l`
    local VALID_NUM=0
    local SUCCESS_NUM=0
    local FAILD_NUM=0

    if [ -f ${VALID_TMP_FILE} ]; then
        VALID_NUM=`cat ${VALID_TMP_FILE}|wc -l`
    fi

    if [ -f ${SUCCESS_LOG_FILE} ]; then
        SUCCESS_NUM=`cat ${SUCCESS_LOG_FILE}|wc -l`
    fi

    if [ -f ${FAILD_LOG_FILE} ]; then
        FAILD_NUM=`cat ${FAILD_LOG_FILE}|wc -l`
    fi
    
    printf "\E[1m%-12s%-12s%-12s%-12s\E[0m\n" TOTAL VALID SUCCESS FAILD
    printf "%-12s%-12s%-12s%-12s%-12s\n" ${LINE_NUM} ${VALID_NUM} ${SUCCESS_NUM} ${FAILD_NUM}
}

#
if [ ! -f ${MS_FILE} ]; then
    printf "\E[31m[Error]\E[0m MS file was not found.\n"
    quitRun
fi

# input
if [ "$#" != 1 ]; then
    printf "\E[31m[Error]\E[0m Please enter the specified file.\n"
    printf "\nNotice: The line format for: \n"
    printf "\E[1mDOMAIN WEB_ROOT_DIR\E[0m\n"
    printf "\nWEB_ROOT_DIR is relative to the path of the ${WEB_ROOT_DIR}/\n"
    quitRun
fi

readonly INPUT_FILE=$1

printf "\n1) Checking the legitimacy of the file data...\n"
printf "\E[1m%-30s%-38s%-12s%-12s%-12s\E[0m\n" DOMAIN WEB_DIR CK_DOMAIN CK_WEBDIR CK_CONFILE
cat ${INPUT_FILE} | while read line
do
    check ${line}
done

# check valid file
if [ ! -f ${VALID_TMP_FILE} ]; then
    printf "\n\E[33m[Cancel]\E[0m No legal data, the system automatically terminate.\n"
    quitRun
fi

# confirm
printf "\n2) Will automatically configure legal data, please confirm whether to enter \E[1mYes\E[0m or other: "
read confirm
if [ "$confirm" != "Yes" ]; then
    printf "\n\E[33m[Cancel]\E[0m The user to cancel the operation.\n"
    quitRun
fi

printf "\n2.1) The batch configuration in the website...\n"
printf "\E[1m%-30s%-38s%-12s%-12s%-12s\E[0m\n" DOMAIN WEB_DIR MAKE_DIR COPY_CONF
cat ${VALID_TMP_FILE} | while read line
do
    setWeb ${line}
done


printf "\n2.2) Automatic configuration result statistics:\n"
statistics ${INPUT_FILE}

printf "\n2.3) Nginx configuration testing: \n"
${NGINX_BIN}/nginx -t

printf "\n3) Please enter \E[1mYes\E[0m or other to confirm reload NGINX configuration: "
read reloadNginx
if [ "$reloadNginx" == "Yes" ]; then
    printf "\nOverloading nginx configuration ................... "
    ${NGINX_BIN}/nginx -s reload && printf "\E[32m[success]\E[0m" || printf "\E[31m[faild]\E[0m"
    printf "\n"
else
    printf "\E[33m[Warning]\E[0m Configuration has been completed, but not overloading nginx."
    printf "Please Use:\E[1m ${NGINX_BIN}/nginx -s reload \E[0m"
    printf "\n"
fi

quitRun



