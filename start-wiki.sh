#!/bin/sh

cd /128gb

echo "For some reason we get a lot of crashes initially, something is wrong with the kernel?"
while [ 1 ]; do
  ./zimHttpServer.pl wikipedia_en_all_2016.zim
  echo "Restarted after failure ..."
  sleep 1s
done

