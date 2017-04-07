#!/bin/sh

# need edit
readonly NGINX_PATH="/usr/local/webserver/nginx/";
readonly WEB_CONF_RELPATH="conf/sites/webs/";
readonly WEB_USER_DIR="/home/web/";
readonly LOG_PATH="/www/sh/logs/";
readonly LOCAL_IPS=(
"121.12.172.4"
"112.90.89.167"
);

# const
readonly WEB_ROOT_PATH="${WEB_USER_DIR}wwwroot/";
readonly DISABLED_NGINX_CONF_PATH="${WEB_USER_DIR}.disabled_nginx_conf/";
readonly LOG_FILE="${LOG_PATH}check_site_`date +%Y-%m-%d`.log";



# functions
function getIp() {
    if [ $# != 1 ]; then
        printf "\E[31m[%-7s]\E[0m%s\n" "ERROR" "function: getIP(): There must be a parameter.";
        exit;
    fi

    local SITE=$1;

    IP=`ping ${SITE} -c 1 | sed '1{s/[^(]*(//;s/).*//;q}'`;
}

function inArray() {
    if [ $# != 2 ]; then
        printf "\E[31m[%-7s]\E[0m%s\n" "ERROR" "function: getIP(item, array): There must be two parameter.";
        exit;
    fi

    local ITEM=$1
    local ARRAY=$2

    return `echo ${ARRAY[@]}|grep -wq "${ITEM}" &&  echo 1 || echo 0`;
}

function check() {
    local FIND_PATH="${NGINX_PATH}${WEB_CONF_RELPATH}";
    for FILE in `find ${FIND_PATH} -name *.conf`
    do
        local CONF_FILE_NAME=`echo ${FILE} | awk -F'/' '{print \$NF}'`;
        local WEB_DOMAIN=${CONF_FILE_NAME%'.conf'};

        getIp ${WEB_DOMAIN} > /dev/null 2>&1;
        local IP=${IP};

        # not in local server ips
        if [ ${#IP} -lt 4 ]; then
            echo ${WEB_DOMAIN} >> .check_site/faild.unknown.domain;
            echo ${FILE} >> .check_site/faild.nginx.conf;

            printf "\E[31m[%-7s]\E[0m%s\n" "ERROR" "unknown host ${WEB_DOMAIN}";
        else
            inArray ${IP} ${LOCAL_IPS};
            if [ $? == 0 ]; then
                echo ${WEB_DOMAIN} >> .check_site/faild.domain;
                echo ${FILE} >> .check_site/faild.nginx.conf;

                printf "\E[31m[%-7s]\E[0m%s\n" "ERROR" "ip${IP} parse error ${WEB_DOMAIN}";

                # remove web file
                local WEB_ROOT_DIR=`grep '^\s\{1,\}root\s\{1,\}.*;$' ${FILE}|awk '{print \$2}'|cut -d ";" -f 1`;
                # check dir in web_root_path
                local IN_WEB_ROOT_PATH=`expr index "${WEB_ROOT_DIR}" "${WEB_ROOT_PATH}"`;
                if [ -d "${WEB_ROOT_DIR}" ] && [ IN_WEB_ROOT_PATH != 0 ] && [ ${#WEB_ROOT_DIR} -gt 2 ] \
                && [ "${WEB_ROOT_DIR}" != "/" ]; then
                    echo ${WEB_ROOT_DIR} >> .check_site/faild.web.file.dir;
                fi
            else
                printf "\E[32m[%-7s]\E[0m%s\n" "SUCCESS" "is normal ${WEB_DOMAIN}";
            fi
        fi
    done

    # statistics
    printf "\n\n\E[1m%s\E[0m\n" "Check statistics:";
    if [ -d "/usr/local/webserver/nginx/conf/sites/webs/" ]; then
        local TOTAL=`ls -al /usr/local/webserver/nginx/conf/sites/webs/*.conf|wc -l`;
    fi
    if [ -f ".check_site/faild.unknown.domain" ]; then
        local UNKNOWN_HOST=`cat .check_site/faild.unknown.domain|wc -l`;
    fi
    if [ -f ".check_site/faild.domain" ]; then
        local IP_ERROR=`cat .check_site/faild.domain|wc -l`;
    fi
    if [ -f ".check_site/faild.nginx.conf" ]; then
        local FAILD=`cat .check_site/faild.nginx.conf|wc -l`;
    fi
    local NORMAL=`expr ${TOTAL:-0} - ${FAILD:-0}`;
    printf "\E[1m%-18s%-18s%-18s%-18s\E[0m\n" TOTAL UNKNOWN_HOST IP_ERROR NORMAL;
    printf "%-18s%-18s%-18s%-18s%-18s\n" ${TOTAL:-0} ${UNKNOWN_HOST:-0} ${IP_ERROR:-0} ${NORMAL:-0};
}

function remove() {
    local FIND_PATH="${NGINX_PATH}${WEB_CONF_RELPATH}";
    for FILE in `find ${FIND_PATH} -name *.conf`
    do
        local CONF_FILE_NAME=`echo ${FILE} | awk -F'/' '{print \$NF}'`;
        local WEB_DOMAIN=${CONF_FILE_NAME%'.conf'};

        echo "[${WEB_DOMAIN}]:" >> ${LOG_FILE};
        printf "\n\E[1m%s\E[0m\n" "In progress ${WEB_DOMAIN}:";
        printf "%5d) %s ... " "1" "Check Domain";

        getIp ${WEB_DOMAIN} > /dev/null 2>&1;
        local IP=${IP};
        local IS_FAILD=0;

        # not in local server ips
        if [ ${#IP} -lt 4 ]; then
            local IS_FAILD=1;
            local MESSAGE="unknown host";
            local LABEL="\E[32m[NEXT]\E[0m";
        else
            inArray ${IP} ${LOCAL_IPS};
            if [ $? == 0 ]; then
                local IS_FAILD=1;
                local MESSAGE="ip${IP} parse error";
                local LABEL="\E[32m[NEXT]\E[0m";
            else
                local MESSAGE="is normal";
                local LABEL="\E[33m[NORMAL]\E[0m";
            fi
        fi

        printf "%s ... %s\n" "${MESSAGE}" "${LABEL}";
        echo "    1) Check Domain: ${MESSAGE}" >> ${LOG_FILE};

        # Need further treatment
        if [ ${IS_FAILD} == 1 ]; then
            echo ${WEB_DOMAIN} >> .check_site/done.domain;

            # arguments
            local WEB_ROOT_DIR=`grep '^\s\{1,\}root\s\{1,\}.*;$' ${FILE}|awk '{print \$2}'|cut -d ";" -f 1`;

            # remove nginx conf file
            printf "%5d) %s ... " "2" "Delete Nginx Conf";
            mv ${FILE} ".check_site/conf.bak/";
            if [ $? == 0 ]; then
                echo ${FILE} >> .check_site/done.nginx.conf;
                echo "    2) Delete Nginx Conf: [SUCCESS]" >> ${LOG_FILE};

                local LABEL="\E[32m[SUCCESS]\E[0m";
            else
                echo "    2) Delete Nginx Conf: [ERROR]" >> ${LOG_FILE};

                local LABEL="\E[31m[ERROR]\E[0m";
            fi
            printf "%s\n" "${LABEL}";

            # remove web file
            printf "%5d) %s ... " "3" "Delete Web Files";
            # check dir in web_root_path
            local IN_WEB_ROOT_PATH=`expr index "${WEB_ROOT_DIR}" "${WEB_ROOT_PATH}"`;
            if [ -d "${WEB_ROOT_DIR}" ] && [ IN_WEB_ROOT_PATH != 0 ] && [ ${#WEB_ROOT_DIR} -gt 2 ] \
            && [ "${WEB_ROOT_DIR}" != "/" ]; then
                mv ${WEB_ROOT_DIR} "${WEB_ROOT_DIR%/}.bak";
                if [ $? == 0 ]; then
                    echo "${WEB_ROOT_DIR} -> ${WEB_ROOT_DIR%/}.bak" >> .check_site/done.web.file.dir;
                    echo "    3) Delete Web Files: [SUCCESS]" >> ${LOG_FILE};

                    local MESSAGE="";
                    local LABEL="\E[32m[SUCCESS]\E[0m";
                else
                    echo "    3) Delete Web Files: [ERROR]" >> ${LOG_FILE};

                    local MESSAGE="";
                    local LABEL="\E[31m[ERROR]\E[0m";
                fi

                # Change dir permissions
                chown -R web:www "${WEB_ROOT_DIR%/}.bak";
            else
                echo "    3) Delete Web Files: [IGNORE]" >> ${LOG_FILE};

                local MESSAGE="not exist";
                local LABEL="\E[33m[IGNORE]\E[0m";
            fi

            printf "%s ... %s\n" "${MESSAGE}" "${LABEL}";
        fi
    done
}

function clean() {
    if [ -d ".check_site/conf.bak/" ]; then
        mv ".check_site/conf.bak/" "${DISABLED_NGINX_CONF_PATH}`date +%Y%m%d`";
    fi

    if [ -d ".check_site" ]; then
        rm -rf .check_site;
    fi
}


# running
# lock & check lock
if [ -f ".check_site/.lock" ]; then
    printf "\E[31m[%-7s]\E[0m%s\n" "ERROR" "The program is being used.";
    exit;
fi
touch .check_site/.lock;

# init dir
if [ ! -d ".check_site" ]; then
    mkdir -p .check_site;
    mkdir -p .check_site/conf.bak/;
fi

printf "Can choose the parameters:
   1)\E[1m check \E[0m:
        Check and statistics to deal with the domain name.
   2)\E[1m remove\E[0m:
        Delete the invalid nginx configuration and web directory. You must first check!
   3)\E[1m clean \E[0m:
        Clean up the running cache.

Please input word:";
read CMD;

case ${CMD} in
    "check") check;;
    "remove") remove;;
    "clean") clean;;
    *)
        printf "\E[31m[%-7s]\E[0m%s\n" "ERROR" "Must enter the above parameters word.";
    ;;
esac

rm -f .check_site/.lock;