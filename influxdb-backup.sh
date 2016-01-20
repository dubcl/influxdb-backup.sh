#!/bin/bash
# 
# Carlos Albornoz <caralbornozc@gmail.com>
# http://albornoz.rocks
#
# Based on https://github.com/eckardt/influxdb-backup.sh
#          https://github.com/kipanshi/influxdb-backup.sh


function dep (){
  if [ ! -f /usr/bin/jq ] || [ ! -f /usr/bin/curl ] || [ ! -f /bin/gzip ]; then
    echo "jq, curl or gzip is not installed, please check and try again.";
    exit 1;
  fi
}

function usage() {
    echo -e "Usage: $0 dump DATABASE [options...] 
\t-u USERNAME (default: root)
\t-p PASSWORD (default: root)
\t-H HOST (default: localhost:8086)
\t-s (0 for HTTP, 1 for HTTPS, default: 0)
\t-r SERIES REGEXP (default: /.*/)"
  }

function parse_options {

  if [ "$#" -lt 2 ]; then
    usage; exit 1;
  fi

  date=$(date +"%H%M%d%m%Y")
  username=root
  password=root
  host=localhost:8086
  regexp=/.*/
  https=0
  shift
  database=$1
  shift
  filedump=BACKUP_${database}_${date}.influxdb.gz

  while getopts u:p:H:s:r:h opts
  do case "${opts}" in
    u) username="${OPTARG}";;
    p) password="${OPTARG}";;
    H) host="${OPTARG}";;
    s) https="${OPTARG}";;
    r) regexp="${OPTARG}";;
    h) usage; exit 1;;
    esac
  done
  if [ "${https}" -eq 1 ]; then
    scheme="https"
  else
    scheme="http"
  fi
}

function dump {
  parse_options $@
  echo "Processing, please wait..."
  curl -s -k -G "${scheme}://${host}/db/${database}/series?u=${username}&p=${password}&chunked=true" --data-urlencode "q=select * from ${regexp}" | jq . -c -M | gzip -c > ${filedump} &
  pid=$!
  while kill -0 $pid 1> /dev/null
  do
    printf "."
    sleep 1
  done
  exit
}

function restore {
  parse_options $@

  while read -r line
  do
    echo >&2 "Writing..."
    curl -X POST -d "[${line}]" "${scheme}://${host}/db/${database}/series?u=${username}&p=${password}"
  done
  exit
}

# Check if jq or curl is installed
dep $@;

case "$1" in
  dump)     dump $@;;
  restore)  restore $@;;
  *) usage $@;;
esac
