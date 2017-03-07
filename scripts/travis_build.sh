#!/bin/bash
for x in $(ls);
do
  if [ -f $x/config.json ];   
  then
   bash scripts/build_debs_travis.sh  $x/config.json $x;
  fi;
done

