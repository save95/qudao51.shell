#!/bin/sh

# need edit
readonly WEB_ROOT_PATH="/home/web/wwwroot";
readonly CHECK_FILE="copyright.js";
readonly LOG_FILE="/www/sh/logs/set_file_readonly_`date +%Y-%m-%d`_run.log";

# functions
function setReadonly() {
  if [ $# != 1 ]; then
    echo "[FAILD  ]:setReadonly argument error." >> ${LOG_FILE};
    exit;
  fi

  local FIND_PATH=$1;

  for FILE in `find ${FIND_PATH} -name ${CHECK_FILE}`
  do
    local FILE_PRIVILEGE=`stat -c %a ${FILE}`;
    if [ ${FILE_PRIVILEGE} != 444 ]; then
      chmod 444 ${FILE};

      if [ $? == 1 ]; then
        echo "[FAILD  ][$FILE_PRIVILEGE -\- 444]:${FILE}" >> ${LOG_FILE};
      else
        echo "[SUCCESS][$FILE_PRIVILEGE --> 444]:${FILE}" >> ${LOG_FILE};
      fi
    else
      echo "[IGNORE ][$FILE_PRIVILEGE --- 444]:${FILE}" >> ${LOG_FILE};
    fi
  done
}

# handle
echo "RUNTIME: `date '+%F %T'`" >> ${LOG_FILE};
setReadonly ${WEB_ROOT_PATH};
echo "DONE: `date '+%F %T'`" >> ${LOG_FILE};
exit;

