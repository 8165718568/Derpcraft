#!/bin/bash


#change the following to "false" to disable changing the default server name and motd
#Don't change this
setserver="true"
#change the following to "false" to disable updating of server jars and website
syncweb="true"
syncjars="true"
#server name and motd -- DO NOT USE BACKTICKS (`) within it!! -- stuff WONT work if you DO!! ALSO do not use "${anything}" UNLESS YOU KNOW WHAT YOU ARE DOING!!
#Doesn't work, left as default on purpose
srvname="Your Minecraft Server"
srvmotd="Minecraft Server"


#Intentionally left blank. Resets bukkit server. Emergency measure.
emergbukkit="false"



#~#       this code was smashed together by ayunami2000   #~#



echo ensuring old server process is truly closed...
nginx -s stop -c ~/$REPL_SLUG/nginx.conf -g 'daemon off; pid /tmp/nginx/nginx.pid;' -p /tmp/nginx -e /tmp/nginx/error.log
pkill java
pkill nginx
rm -rf /tmp/*

if [ ! -f "updated.yet" ]; then
  syncweb="true"
  syncjars="true"
fi
#This used to check curl and see if the eaglercraft repo is still active (it isnt.) To speed up boot time, this check was removed and just automatically fails.
echo checking if file still works...

if true ; then
  syncweb="false"
  syncjars="false"
else
  echo site is still up! downloading...
  curl -L -o stable-download.zip "$eagurl"
  echo extracting zip...
  mkdir /tmp/new
  cd /tmp/new
  jar xvf $HOME/$REPL_SLUG/stable-download.zip
  cd $HOME/$REPL_SLUG
  echo deleting original zip file...
  rm -rf stable-download.zip
  mkdir web
  mkdir java
  mkdir java/bungee_command
  mkdir java/bukkit_command
  if [ "$syncweb" = "true" ]; then
    echo updating web folder...
    rm -rf web/*
    cp -r /tmp/new/web/. ./web/
    echo backing up original index.html file...
    cp web/index.html web/index.html.ORIG
  fi
  if [ "$syncjars" = "true" ]; then
    echo updating bungeecord server...
    if [ -f "updated.yet" ]; then
      rm -f java/bungee_command/bungee-dist.jar
      cp /tmp/new/java/bungee_command/bungee-dist.jar ./java/bungee_command/
    else
      rm -rf java/bungee_command/*
      cp -r /tmp/new/java/bungee_command/. ./java/bungee_command/
      echo ensuring that bungeecord is hosting on the correct port...
      sed -i 's/host: 0\.0\.0\.0:[0-9]\+/host: 127.0.0.1:1/' java/bungee_command/config.yml
      sed -i 's/^server-ip=$/server-ip=127.0.0.1/' java/bukkit_command/server.properties
    fi
    echo updating bukkit server...
    if [ "$emergbukkit" = "true" ]; then
      rm -rf java/bukkit_command/*
      cp -r /tmp/new/java/bukkit_command/. ./java/bukkit_command/
    else
      rm -f java/bukkit_command/craftbukkit-1.5.2-R1.0.jar
      cp /tmp/new/java/bukkit_command/craftbukkit-1.5.2-R1.0.jar ./java/bukkit_command/
    fi
  fi
  echo removing update data...
  rm -rf /tmp/new
  echo deleting old directory if it exists for some reason...
  rm -rf old
fi

if [ ! -f "updated.yet" ]; then
  touch updated.yet
fi

echo starting bungeecord...
cd java/bungee_command
tmux new -d -s bungee java -Xmx32M -Xms32M -jar bungee-dist.jar
cd -
#I'm not sure what this does, really.
if [ "$setserver" = "true" -a "$syncweb" = "true" ]; then
  echo restoring original index.html...
  rm web/index.html
  cp web/index.html.ORIG web/index.html
  echo configuring local website...
  sed -i 's/https:\/\/g\.eags\.us\/eaglercraft/https:\/\/gnome\.vercel\.app/' web/index.html
  sed -i 's/alert/console.log/' web/index.html
  echo setting default server...
  sed -i "s/\"CgAACQAHc2VydmVycwoAAAABCAACaXAAIHdzKHMpOi8vIChhZGRyZXNzIGhlcmUpOihwb3J0KSAvCAAEbmFtZQAIdGVtcGxhdGUBAAtoaWRlQWRkcmVzcwEIAApmb3JjZWRNT1REABl0aGlzIGlzIG5vdCBhIHJlYWwgc2VydmVyAAA=\"/btoa(atob(\"CgAACQAHc2VydmVycwoAAAABCAAKZm9yY2VkTU9URABtb3RkaGVyZQEAC2hpZGVBZGRyZXNzAQgAAmlwAGlwaGVyZQgABG5hbWUAbmFtZWhlcmUAAA==\").replace(\"motdhere\",String.fromCharCode(\`$srvname\`.length)+\`$srvname\`).replace(\"namehere\",String.fromCharCode(\`$srvmotd\`.length)+\`$srvmotd\`).replace(\"iphere\",String.fromCharCode((\"ws\"+location.protocol.slice(4)+\"\/\/\"+location.host+\"\/server\").length)+(\"ws\"+location.protocol.slice(4)+\"\/\/\"+location.host+\"\/server\")))/" web/index.html
fi

echo starting nginx...
mkdir /tmp/nginx
rm -rf nginx.conf
sed "s/eaglercraft-server/$REPL_SLUG/" nginx_template.conf > nginx.conf
nginx -c ~/$REPL_SLUG/nginx.conf -g 'daemon off; pid /tmp/nginx/nginx.pid;' -p /tmp/nginx -e /tmp/nginx/error.log > /tmp/nginx/output.log 2>&1 &
#Looks like first boot stuff. Don't delete it though. In fact,
#don't delete ANYTHING!
#
#
#
#Looked like some DRM stuff. Just to be safe made sure it wouldn't run.
if false;
then
  echo resetting world and randomizing seed...
  rm base.repl
  rm -rf java/bukkit_command/world
  rm -rf java/bukkit_command/world_nether
  rm -rf java/bukkit_command/world_the_end
  rm -f java/bukkit_command/server.log.lck
  rm java/bukkit_command/server.log
  rm -f java/bungee_command/proxy.log.0.lck
  rm java/bungee_command/proxy.log.0
fi
#Have noticed less server falling behind messages since i implemented this.
echo starting bukkit...
cd java/bukkit_command
java -Xmx1024m -Xms1024M -jar craftbukkit-1.5.2-R1.0.jar
cd -

echo killing bungeecord and nginx...
nginx -s stop -c ~/$REPL_SLUG/nginx.conf -g 'daemon off; pid /tmp/nginx/nginx.pid;' -p /tmp/nginx -e /tmp/nginx/error.log
pkill java
pkill nginx

echo done!