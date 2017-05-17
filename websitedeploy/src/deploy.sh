#!/bin/sh

readonly NGINX_BIN=`sed '/^nginx_bin_dir\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_CONF_DIR=`sed '/^web_nginx_conf_dir\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_ROOT_DIR=`sed '/^web_root_dir\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_USER=`sed '/^web_user\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`
readonly WEB_USER_GROUP=`sed '/^web_user_group\s*=.*$/!d;s/.*=\s*//;s/\s//g' config.ini`

# todo check params

# const
readonly SERVER_NAME_PATTERN="^([a-z0-9]+)((.[-a-z0-9]+)+)$"
readonly DATE=`date '+%F %T'`

# input
if [ $# != 2 ]; then
    echo "The number of parameter is less than 2."
    exit;
fi

if [ -z $1 -a -z $2 ]; then
    read -p "server name: " serverName
    read -p "web root directory: ${WEB_ROOT_DIR}/" rootDir
elif [ -n $1 -a -n $2 ]; then
    serverName=$1
    rootDir=$2
fi

readonly serverName
readonly rootDir

# check
echo ""
echo -n "Check the domain name ............. "
if [[ "${serverName}" =~ ${SERVER_NAME_PATTERN} ]]; then
    echo -e "\E[32m[success]\E[0m"
else
    echo -e "\E[31m[invalid]\E[0m"
    exit;
fi

echo -n "Check the web root directory ...... "
readonly SITE_ROOT_DIR="${WEB_ROOT_DIR}/${rootDir}"
if [ ! -d "${SITE_ROOT_DIR}" ]; then
    echo -e "\E[32m[success]\E[0m"
else
    echo -e "\E[31m[exist]\E[0m"
fi

echo -n "Check the nginx .conf file ........ "
readonly CONF_FILE="${WEB_CONF_DIR}/${serverName}.conf"
if [ ! -f "${CONF_FILE}" ]; then
    echo -e "\E[32m[success]\E[0m"
else
    echo -e "\E[31m[exist]\E[0m"
    exit;
fi

# confirm
printf "
Please refer to the following information is correct:
    \E[1m  server name :\E[0m ${serverName}
    \E[1m  web root dir:\E[0m ${SITE_ROOT_DIR}
    Please enter \E[1mYes\E[0m or other to confirm: "
read confirm

if [ ${confirm} != "Yes" ]; then
    echo -e "\E[33m[Cancel]\E[0m The user to cancel the operation."
    exit;
fi

# make web root dir
echo -n "Create the web root directory ..................... "
if [ ! -d "${SITE_ROOT_DIR}" ]; then
    mkdir -p ${SITE_ROOT_DIR} > /dev/null 2>&1
    chown -R ${WEB_USER}.${WEB_USER_GROUP} ${SITE_ROOT_DIR} > /dev/null 2>&1

    if [ $? == 1 ]; then
        echo -e "\E[31m[faild]\E[0m"
        exit;
    else
        echo -e "\E[32m[success]\E[0m"
    fi
else
    echo -e "\E[33m[exist]\E[0m"
fi

# copy conf file.
echo -n "Generate a web site nginx configuration file ...... "
sed "s|SERVER_NAME|${serverName}|g; s|ROOT_DIR|${rootDir}|g" web.conf.ms > ${serverName}.conf.tmp
mv ${serverName}.conf.tmp ${CONF_FILE} > /dev/null 2>&1
if [ $? == 1 ]; then
    echo -e "\E[31m[faild]\E[0m"
    exit;
else
    echo -e "\E[32m[success]\E[0m"
fi

# write log
echo "${DATE} set ${serverName}:" >> run.log
echo "    file: ${WEB_CONF_DIR}/${serverName}.conf" >> run.log
echo "    dir : ${SITE_ROOT_DIR}" >> run.log
echo "" >> run.log

echo ""
echo "Nginx configuration testing: "
${NGINX_BIN}/nginx -t

echo ""
read -p "Immediately overloaded nginx configuration? [Yes or any other]: " reloadNginx
if [ ${reloadNginx} == "Yes" ]; then
    echo -n "Overloading nginx configuration ................... "
    ${NGINX_BIN}/nginx -s reload && echo -e "\E[32m[success]\E[0m" || echo echo -e "\E[31m[faild]\E[0m"
    exit;
else
    echo -e "\E[33m[Warning]\E[0m Configuration has been completed, but not overloading nginx. Please manual operation."
fi

echo ""


