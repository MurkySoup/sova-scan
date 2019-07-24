#!/usr/bin/env bash

# FILE-METRICS version 0.2-20160715
# by rick pelletier (rpelletier@gannett.com), july 2016
# last update: july 2016

# we can roughly parallelize the data collection process, but this works best for local filesystems
# on servers with 2 or more CPUs. in such cases, more CPUs is definitely better. with remotely-
# mounted filesystems, you'll very likely hit an I/O bottleneck long before you saturate your CPUs.

# example usage: assumes local filesystem. has no explicit trapping for poopie filenames. you'll have
# to add the sql import header and footer manually or wrap this into a contol script
# find /var/www -type f | egrep '\.([a-z]{0,}htm[l]{0,}|pl[cd]{0,}|php[1234567890]{0,}|py|rb|js|jsp|jquery|javascript|java|class)$' | parallel ./file-metrics.sh

# example usage: includes hostname override and output to file (you'll have to add the sql import
# header and footer manually or wrap this in a control script
# find /var/www -type f | egrep '\.([a-z]{0,}htm[l]{0,}|pl[cd]{0,}|php[1234567890]{0,}|py|rb|js|jsp|jquery|javascript|java|class)$' | parallel ./file-metrics.sh {} "test-host" | tee output.sql

# as a minor point: this technique will also fix the issue of lagging scan timestamps.

run_stamp=$(date '+%F %H:%M:%S')
db="sova_scan"
table="files"

# you must specify at least the first arg for the filename to analyze
# you may optionally specify another arg to override the default hostname variable (good for identifying remotely-mounted filesystems)
# any args beyond the first two are ignored.

if [ $# -lt 1 ]
then
  echo "$0: Missing args" >&2
  exit 1
else
  if [ -z "$2" ]
  then
    target_host=$(hostname)
  else
    target_host="$2"
  fi

  # make sure 'ent' is present
  if ! local_ent=$(${local_which} ent)
  then
    echo "$0: 'ent' is required but not found (see http://www.fourmilab.ch/random/)" >&2
    exit 1
  fi

  # if i can 'stat' it, everything else _should_ work
  if stat_data=$(stat -c '%i %A %s %Y %U %G %n' "$1")
  then
    # XXX filename cleanup could be better (but there's such a huge variety of silly file-naming stupidity out there!)
    stat_name=$(echo -n "$1" | sed -e 's/\x20/\\\\\x20/g' -e 's/\x22/\\\\\x22/g' -e 's/\x27/\\\\\x27/g' -e 's/\x60/\\\\\x60/g')
    stat_inode=$(echo "${stat_data}" | awk '{printf $1}')
    stat_perm=$(echo "${stat_data}" | awk '{printf $2}')
    stat_size=$(echo "${stat_data}" | awk '{printf $3}')
    stat_stamp=$(echo "${stat_data}" | awk '{printf $4}')
    stat_own=$(echo "${stat_data}" | awk '{printf $5}')
    stat_grp=$(echo "${stat_data}" | awk '{printf $6}')
    file_data=$(file -bin "$1" | awk -F, '{printf $1}')
    hash_data=$(openssl dgst -sha256 "$1" | rev | cut -d " " -f1 | rev)
    entropy_data=$(ent -t "$1")
    entropy=$(echo "${entropy_data}" | tail -n 1 | awk -F, '{printf $3}')
    longest_string=$(awk '{ if (length($0) > longest) longest = length($0); } END { print longest }' "$1") # probably most portable and least troublesome

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
    echo "$0: Unable to stat $1." >&2
    exit 1
  fi
fi

exit 0

# end of script
