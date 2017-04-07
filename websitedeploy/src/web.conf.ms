server {
  listen 80;

  server_name  SERVER_NAME;
  index index.html index.htm;
  root  /home/web/wwwroot/ROOT_DIR;

  #charset  utf-8,gb2312,gb18030;

  if ($http_user_agent ~* (spider|Spider|soso|bing|sogou|yahoo|sohu-search|yodao|YoudaoBot|robozilla|msnbot|MJ12bot|NHN|Twiceler)){
    return 200;
  }

  location ~ .*\.(gif|jpg|jpeg|png|bmp|swf|js|css)$ {
    expires      7d;
    access_log  off;
  }

   access_log logs/web.access.log  main;
}
