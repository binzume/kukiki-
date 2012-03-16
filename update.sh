#!/bin/sh

# usage: update.sh [target_dir]

TARGET=$1

cp -p kukiki.cgi $TARGET
cp -rp modules $TARGET

