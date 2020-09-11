#!/usr/bin/env bash

# SOVA-SCAN version 0.7.9-20180212-beta (do not distribute)
# by rick pelletier (rpelletier@gannett.com), july 2015
# last update: febuary 2018

# uses a variety of common tools to build a database of files with odd properties that might indicate the
# presence of obfuscated code. output is in the form of a mysql flatfile (for easy database import).

# to kick of a quick scan and dump the results to aa timestamped filed, try something like:
# ./sova-scan.sh -d /opt/gmti | tee $(hostname).$(date "+%Y%m%d.%H%M%S").sql

# TODO
# in the event a file previously tagged by 'find' is removed before the scanner reaches it,
# a graceful way to move on should be implemented. at present, if it hits an MIA file, the
# script aborts. considered the time frames involved to rescan large file systems, this is
# a lucrative bug to fix.

# it's considered good practice to verify these prior to runtime

target_host=$(hostname) # default value (can be overridden from command line)
target_dir=""
run_stamp=$(date '+%F %H:%M:%S')
db="sova_scan"
table="files"

function display_header () {
  # sql import header info (customize as needed)
  echo "SET NAMES utf8mb4;"
  echo "DROP DATABASE IF EXISTS ${db};"
  echo "CREATE DATABASE IF NOT EXISTS ${db} CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;"
  echo "USE ${db};"
  echo "CREATE TABLE IF NOT EXISTS ${db}.${table} ("
  echo "  record_id  int(11) NOT NULL AUTO_INCREMENT,"
  echo "  scan_date  datetime DEFAULT NULL,"
  echo "  host       varchar(256) DEFAULT NULL,"
  echo "  file_perm  varchar(10) DEFAULT NULL,"
  echo "  file_size  bigint(16) DEFAULT NULL,"
  echo "  file_date  datetime DEFAULT NULL,"
  echo "  file_owner varchar(64) DEFAULT NULL,"
  echo "  file_group varchar(64) DEFAULT NULL,"
  echo "  file_path  varchar(1024) DEFAULT NULL,"
  echo "  file_data  varchar(128) DEFAULT NULL,"
  echo "  hash       varchar(64) DEFAULT NULL,"
  echo "  l_string   int(11) DEFAULT NULL,"
  echo "  entropy    float(14,13) DEFAULT NULL,"
  echo "  PRIMARY KEY (record_id)"
  echo ") ENGINE=MyISAM AUTO_INCREMENT=1;"
  #echo "TRUNCATE TABLE ${db}.${table};" # this can be commented out if you need to retain existing information in this table
  echo "LOCK TABLES ${db}.${table} WRITE;"
  #echo "ALTER TABLE ${db}.${table} DISABLE KEYS;"
}

function display_footer () {
  #echo "ALTER TABLE ${db}.${table} ENABLE KEYS;"
  echo "UNLOCK TABLES;"
}

# do the work

if [ $(id -u) -ne 0 ]
then
  echo "This script requires super-user privileges" >&2
  exit 1
else
  # make sure 'ent' is present
  if ! local_ent=$(which ent)
  then
    echo "'ent' is required but not found (see http://www.fourmilab.ch/random/)" >&2
    exit 1
  fi

  # process command-line arguments. getopts is evil(tm), but suited for our purpose
  while getopts h:d: opt
  do
    case "$opt" in
      h)  target_host="$OPTARG";;
      d)  target_dir="$OPTARG";;
      \?) # unknown flag
          echo "usage: $0 [ -h hostname ] [ -d /path/to/dir ]" >&2
          exit 1;;
    esac
  done
  shift $(expr $OPTIND - 1)

  if [ -z "${target_dir}" ]
  then
    echo "No starting directory given" >&2
    exit 1
  else
    if [ -d "${target_dir}" ]
    then
      display_header

      # search restricted to lucrative targets. use 'clamav' and/or 'maldet' for blanket malware scans
      # the following regex searches for python, perl, ruby php, java/class and ecma/javascripts, plus various flavors of html files
      find ${target_dir} -type f | grep -P '(?i)\.([a-z]{0,}htm[l]{0,}|pl[cd]{0,}|php[1234567890]{0,}|py|rb|js|jsp|jquery|javascript|java|sh)$' | while IFS=$'\n' read -r k
      do
        if [ -f "${k}" ]
        then
          # if i can 'stat' it, everything else should(?) work as expected (but your mileage may vary)
          if stat_data=$(stat -c '%i %A %s %Y %U %G %n' "${k}")
          then
            # XXX filename cleanup could be better (but there's such a huge variety of naming stupidity out there!)
            stat_name=$(echo -n "${k}" | sed -e 's/\x20/\\\\\x20/g' -e 's/\x22/\\\\\x22/g' -e 's/\x27/\\\\\x27/g' -e 's/\x60/\\\\\x60/g')
            stat_inode=$(echo "${stat_data}" | awk '{printf $1}')
            stat_perm=$(echo "${stat_data}" | awk '{printf $2}')
            stat_size=$(echo "${stat_data}" | awk '{printf $3}')
            stat_stamp=$(echo "${stat_data}" | awk '{printf $4}')
            stat_own=$(echo "${stat_data}" | awk '{printf $5}')
            stat_grp=$(echo "${stat_data}" | awk '{printf $6}')
            file_data=$(file -bin "${k}" | awk -F, '{printf $1}')
            hash_data=$(openssl dgst -sha256 "${k}" | rev | cut -d " " -f1 | rev)
            entropy_data=$(${local_ent} -t "${k}")
            entropy=$(echo "${entropy_data}" | tail -n 1 | awk -F, '{printf $3}')
            longest_string=$(awk '{ if (length($0) > longest) longest = length($0); } END { print longest }' "${k}")

            # data adjustment(s)
            if [ -z ${longest_string} ]
            then
              longest_string=0;
            fi

            echo -n "INSERT INTO ${db}.${table} VALUES (NULL,"
            echo -n "\"${run_stamp}\","
            echo -n "\"${target_host}\","
            echo -n "\"${stat_perm}\","
            echo -n "${stat_size},"
            echo -n "FROM_UNIXTIME(${stat_stamp}),"
            echo -n "\"${stat_own}\","
            echo -n "\"${stat_grp}\","
            echo -n "\"${stat_name}\","
            echo -n "\"${file_data}\","
            echo -n "\"${hash_data}\","
            echo -n "${longest_string},"
            echo -n "${entropy}"
            echo ");"
          else
            echo "Unable to stat ${k}." >&2
            display_footer
            exit 1
          fi
        fi
      done

      display_footer
    else
      echo "${target_dir} not found." >&2
      exit 1
    fi
  fi
fi

# end of script
