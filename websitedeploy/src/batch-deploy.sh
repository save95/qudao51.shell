#!/bin/sh

# need edit
readonly MS_FILE_PATH="."
readonly NGINX_PATH="/usr/local/webserver/nginx"
readonly WEB_CONF_RELPATH="conf/sites/webs"
readonly WEB_ROOT_PATH="/home/web/wwwroot"
readonly WEB_DIR_USER_GROUP="web:www"

# nginx setting
readonly MS_FILE="$MS_FILE_PATH/web.conf.ms"
readonly NGINX_BIN="$NGINX_PATH/sbin"
readonly NGINX_CONF_PATH="$NGINX_PATH/$WEB_CONF_RELPATH"
readonly SERVER_NAME_PATTERN="^([a-z0-9]+)((.[-a-z0-9]+)+)$"

readonly LOCK_FILE="run.lock"
readonly VALID_TMP_FILE="valid.tmp"
readonly SUCCESS_LOG_FILE="success.log"
readonly FAILD_LOG_FILE="faild.log"
DATE=`date '+%F %T'`
BACKUP_EXT=`date '+%F_%T'`

# check lock
if [ -f $LOCK_FILE ]; then
    echo -e "\033[31m[Error]\033[0m The program is being used."
    exit;
fi

touch $LOCK_FILE


function quitRun() {
    rm -f $VALID_TMP_FILE
    rm -f $LOCK_FILE
    
    if [ -f $SUCCESS_LOG_FILE ]; then
        mv -f $SUCCESS_LOG_FILE "$SUCCESS_LOG_FILE.$BACKUP_EXT"
    fi
    if [ -f $FAILD_LOG_FILE ]; then
        mv -f $FAILD_LOG_FILE "$FAILD_LOG_FILE.$BACKUP_EXT"
    fi
    exit;
}

function check() {
    vaild=1
    serverName=$1
    rootDir=$2
    lineStr="$serverName $rootDir"
    
    printf "%-30s%-38s" "$serverName" "WEB_ROOT_PATH/$rootDir"
    
    # check domain
    if [[ "$serverName" =~ $SERVER_NAME_PATTERN ]]; then
        printf "\E[32m%-12s\E[0m" "[success]"
    else
        printf "\E[31m%-12s\E[0m" "[invalid]"
        vaild=0
    fi

    # check web dir
    WEB_ROOT_DIR="$WEB_ROOT_PATH/$rootDir"
    if [ ! -d "$WEB_ROOT_DIR" ]; then
        printf "\E[32m%-12s\E[0m" "[success]"
    else
        printf "\E[31m%-12s\E[0m" "[existed]"
        vaild=0
    fi


    # check the nginx .conf file"
    CONF_FILE="$NGINX_CONF_PATH/$serverName.conf"
    if [ ! -f "$CONF_FILE" ]; then
        printf "\E[32m%-12s\E[0m\n" "[success]"
        if [ $vaild == 1 ]; then
            echo $lineStr >> $VALID_TMP_FILE
        fi
    else
        printf "\E[31m%-12s\E[0m\n" "[existed]"
    fi
}

function setWeb() {
    ENTER_NEXT=0
    serverName=$1
    rootDir=$2
    lineStr="$serverName $rootDir"
    
    printf "%-30s%-38s" "$serverName" "WEB_ROOT_PATH/$rootDir"
    
    # make dir
    WEB_ROOT_DIR="$WEB_ROOT_PATH/$rootDir"
    if [ ! -d "$WEB_ROOT_DIR" ]; then
        mkdir -p $WEB_ROOT_DIR > /dev/null 2>&1
        chown -R $WEB_DIR_USER_GROUP $WEB_ROOT_DIR > /dev/null 2>&1

        if [ "$?" == 1 ]; then
            printf "\E[31m%-12s%-12s\E[0m\n" "[faild]" "[skip]"
            echo $lineStr >> $FAILD_LOG_FILE
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
    if [ "$ENTER_NEXT" == 1 ]; then
        CONF_FILE="$NGINX_CONF_PATH/$serverName.conf"
        if [ ! -f "$CONF_FILE" ]; then
            sed "s|SERVER_NAME|$serverName|g; s|ROOT_DIR|$rootDir|g" $MS_FILE > $serverName.conf.tmp
            mv $serverName.conf.tmp $CONF_FILE > /dev/null 2>&1
            if [ "$?" == 1 ]; then
                printf "\E[31m%-12s\E[0m\n" "[faild]"
                echo $lineStr >> $FAILD_LOG_FILE
            else
                printf "\E[32m%-12s\E[0m\n" "[success]"
                echo $lineStr >> $SUCCESS_LOG_FILE
            fi
        else
            printf "\E[31m%-12s\E[0m" "[existed]"
        fi
    else
        printf "\E[31m%-12s\E[0m" "[skip]"
    fi
}

function statistics() {
    LINE_NUM=`cat $1|wc -l`
    VALID_NUM=0
    SUCCESS_NUM=0
    FAILD_NUM=0

    if [ -f $VALID_TMP_FILE ]; then
        VALID_NUM=`cat $VALID_TMP_FILE|wc -l`
    fi

    if [ -f $SUCCESS_LOG_FILE ]; then
        SUCCESS_NUM=`cat $SUCCESS_LOG_FILE|wc -l`
    fi

    if [ -f $FAILD_LOG_FILE ]; then
        FAILD_NUM=`cat $FAILD_LOG_FILE|wc -l`
    fi
    
    printf "\E[1m%-12s%-12s%-12s%-12s\E[0m\n" TOTAL VALID SUCCESS FAILD
    printf "%-12s%-12s%-12s%-12s%-12s\n" $LINE_NUM $VALID_NUM $SUCCESS_NUM $FAILD_NUM
}

#
if [ ! -f $MS_FILE ]; then
    echo -e "\033[31m[Error]\033[0m MS file was not found."
    quitRun
fi

# input
if [ "$#" != 1 ]; then
    echo -e "\033[31m[Error]\033[0m Please enter the specified file."
    echo -e "The file format for: \033[1mDOMAIN WEB_ROOT_DIR\033[0m"
    echo "WEB_ROOT_DIR is relative to the path of the $WEB_ROOT_PATH/"
    quitRun
fi

readonly INPUT_FILE=$1

echo ""
echo -n "1) Checking the legitimacy of the file data..."
echo ""
printf "\E[1m%-30s%-38s%-12s%-12s%-12s\E[0m\n" DOMAIN WEB_DIR CK_DOMAIN CK_WEBDIR CK_CONFILE
cat $INPUT_FILE | while read line
do
    check $line
done

# check valid file
if [ ! -f $VALID_TMP_FILE ]; then
    echo "";
    echo -e "\033[33m[Cancel]\033[0m No legal data, the system automatically terminate."
    quitRun
fi

# confirm
echo ""
echo -en "2) Will automatically configure legal data, please confirm whether to enter \033[1mYes\033[0m or other: "
read confirm
if [ "$confirm" != "Yes" ]; then
    echo -e "\033[33m[Cancel]\033[0m The user to cancel the operation."
    quitRun
fi

echo ""
echo "    2.1) The batch configuration in the website..."
printf "\E[1m%-30s%-30s%-12s%-12s%-12s\E[0m\n" DOMAIN WEB_DIR MAKE_DIR COPY_CONF
cat $VALID_TMP_FILE | while read line
do
    setWeb $line
done


echo ""
echo "    2.2) Automatic configuration result statistics:"
statistics $INPUT_FILE

echo ""
echo "    2.3) Nginx configuration testing: "
$NGINX_BIN/nginx -t

echo ""
echo -en "3) Please enter \033[1mYes\033[0m or other to confirm reload NGINX configuration: "
read reloadNginx
if [ "$reloadNginx" == "Yes" ]; then
    echo -n "Overloading nginx configuration ................... "
    $NGINX_BIN/nginx -s reload && echo -e "\033[32m[success]\033[0m" || echo echo -e "\033[31m[faild]\033[0m"
else
    echo -e "\033[33m[Warning]\033[0m Configuration has been completed, but not overloading nginx. Please manual operation: "
    echo -e "Please Use:\033[1m $NGINX_BIN/nginx -s reload \033[0m"
fi

quitRun



