#!/bin/sh

cd `dirname $0`

while [ 1 ]; do
  ./zimHttpServer.pl wikipedia_en_all_2016.zim
  echo "Restarted after failure ..."
  sleep 1s
done

