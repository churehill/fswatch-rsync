#!/bin/bash

# @author Clemens Westrup
# @date 07.07.2014

# This is a script to automatically synchronize a local project folder to a
# folder on a cluster server via a middle server.
# It watches the local folder for changes and recreates the local state on the
# target machine as soon as a change is detected.

# For setup and usage see README.md

################################################################################

PROJECT="fswatch-rsync"
VERSION="0.2.0"

# Set up your path to fswatch here if you don't want to / can't add it
# globally to your PATH variable (default is "fswatch" when specified in PATH).
# e.g. FSWATCH_PATH="/Users/you/builds/fswatch/fswatch"
FSWATCH_PATH="fswatch"

# Sync latency / speed in seconds
LATENCY="3"

# check color support
colors=$(tput colors)
if (($colors >= 8)); then
    red='\033[0;31m'
    green='\033[0;32m'
    nocolor='\033[00m'
else
  red=
  green=
  nocolor=
fi

# Check compulsory arguments
if [[ "$1" = "" || "$2" = "" ]]; then
  echo -e "${red}Error: $PROJECT takes 2 compulsory arguments.${nocolor}"
  echo "Usage: fswatch-rsync.sh src dest [ssh_port]"
  echo "Dest might be local path, or remote ssh path like [USER@]HOST:DEST"
  echo "Use ssh_port to specify ssh port"
  exit
else
  LOCAL_PATH="$1"
  TARGET_PATH="$2"
fi

# Check optional arguments
if [[ "$3" != "" ]]; then
  PORT="$3"
else
  PORT="22"
fi


# Welcome
echo      ""
echo -e   "${green}Hei! This is $PROJECT v$VERSION.${nocolor}"
echo      "Local source path:  \"$LOCAL_PATH\""
echo      "Remote target path: \"$TARGET_PATH\""
echo      "Using ssh port:   \"$PORT\""
echo      ""
echo -n   "Performing initial complete synchronization "
echo -n   "(Warning: one directory will be overwritten "
echo      "with another version if differences occur)."

# Perform initial complete sync
read -r -p "Please choose inital synchronization direction, up or down? [U/d]: " key
echo      ""
case "$key" in
  "u"|"U"|"up"|"")
    echo -n   "Synchronizing up... "
    rsync -avzr -q --delete --force --exclude=".*" \
    -e "ssh -p $PORT" $LOCAL_PATH $TARGET_PATH
    echo      "done."
    echo      ""
    ;;
  "d"|"D"|"down")
    echo -n   "Synchronizing down... "
    rsync -avzr -q --delete --force --exclude=".*" \
    -e "ssh -p $PORT" $TARGET_PATH $LOCAL_PATH
    echo      "done."
    echo      ""
    ;;
  *)
    echo "Unknown choice. Exiting..."
    exit 1
    ;;
esac


# Watch for changes and sync (exclude hidden files)
echo    "Watching for changes. Quit anytime with Ctrl-C."
${FSWATCH_PATH} -0 -r -l $LATENCY $LOCAL_PATH --exclude="/\.[^/]*$" \
| while read -d "" event
  do
    echo $event > .tmp_files
    echo -en "${green}" `date` "${nocolor}\"$event\" changed. Synchronizing... "
    rsync -avzr -q --delete --force \
    --include-from=.tmp_files \
    -e "ssh -p $PORT" \
    $LOCAL_PATH $TARGET_PATH
  echo "done."
    rm -rf .tmp_files
  done
