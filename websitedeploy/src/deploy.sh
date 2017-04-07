#!/bin/sh

# need edit
readonly NGINX_PATH="/usr/local/webserver/nginx"
readonly WEB_CONF_RELPATH="conf/sites/webs"
readonly WEB_ROOT_PATH="/home/web/wwwroot"

# nginx setting
readonly NGINX_BIN="${NGINX_PATH}/sbin"
readonly SERVER_NAME_PATTERN="^([a-z0-9]+)((.[-a-z0-9]+)+)$"
DATE=`date '+%F %T'`

# input
if [ $# != 2 ]; then
    echo "The number of parameter is less than 2."
    exit;
fi

if [ -z $1 -a -z $2 ]; then
    read -p "server name: " serverName
    read -p "web root directory: ${WEB_ROOT_PATH}/" rootDir
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
    echo -e "\033[32m[success]\033[0m"
else
    echo -e "\033[31m[invalid]\033[0m"
    exit;
fi

echo -n "Check the web root directory ...... "
readonly WEB_ROOT_DIR="${WEB_ROOT_PATH}/${rootDir}"
if [ ! -d "${WEB_ROOT_DIR}" ]; then
    echo -e "\033[32m[success]\033[0m"
else
    echo -e "\033[31m[exist]\033[0m"
#    exit;
fi

echo -n "Check the nginx .conf file ........ "
readonly CONF_FILE="${NGINX_PATH}/${WEB_CONF_RELPATH}/${serverName}.conf"
if [ ! -f "${CONF_FILE}" ]; then
    echo -e "\033[32m[success]\033[0m"
else
    echo -e "\033[31m[exist]\033[0m"
    exit;
fi

# confirm
echo ""
echo -e "Please enter \033[1mYes\033[0m or other to confirm:"
echo -e "\033[1m  server name :\033[0m ${serverName}"
echo -e "\033[1m  web root dir:\033[0m ${WEB_ROOT_PATH}/${rootDir}"
read -p "Please Confirm: " confirm

if [ ${confirm} != "Yes" ]; then
    echo -e "\033[33m[Cancel]\033[0m The user to cancel the operation."
    exit;
fi

# make web root dir
echo -n "Create the web root directory ..................... "
if [ ! -d "${WEB_ROOT_DIR}" ]; then
    mkdir -p ${WEB_ROOT_PATH}/${rootDir} > /dev/null 2>&1
    chown -R web:www ${WEB_ROOT_PATH}/${rootDir} > /dev/null 2>&1

    if [ $? == 1 ]; then
        echo -e "\033[31m[faild]\033[0m"
        exit;
    else
        echo -e "\033[32m[success]\033[0m"
    fi
fi

# copy conf file.
echo -n "Generate a web site nginx configuration file ...... "
sed "s|SERVER_NAME|${serverName}|g; s|ROOT_DIR|${rootDir}|g" web.conf.ms > ${serverName}.conf.tmp
mv ${serverName}.conf.tmp ${CONF_FILE} > /dev/null 2>&1
if [ $? == 1 ]; then
    echo -e "\033[31m[faild]\033[0m"
    exit;
else
    echo -e "\033[32m[success]\033[0m"
fi

# write log
echo "${DATE} set ${serverName}:" >> run.log
echo "    file: ${NGINX_PATH}/${WEB_CONF_RELPATH}/${serverName}.conf" >> run.log
echo "    dir : ${WEB_ROOT_PATH}/${rootDir}" >> run.log
echo "" >> run.log

echo "Nginx configuration testing: "
${NGINX_BIN}/nginx -t

echo ""
read -p "Immediately overloaded nginx configuration? [Yes or any other]: " reloadNginx
if [ ${reloadNginx} == "Yes" ]; then
    echo -n "Overloading nginx configuration ................... "
    ${NGINX_BIN}/nginx -s reload && echo -e "\033[32m[success]\033[0m" || echo echo -e "\033[31m[faild]\033[0m"
    exit;
else
    echo -e "\033[33m[Warning]\033[0m Configuration has been completed, but not overloading nginx. Please manual operation."
fi

echo ""


