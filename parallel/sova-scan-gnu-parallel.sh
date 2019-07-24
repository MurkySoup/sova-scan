#!/usr/bin/env bash

# SOVA-SCAN-PARALLEL version 0.3.2-20161020-beta (do not distribute)
# by rick pelletier (rpelletier@gannett.com), july 2015
# last update: october 2016

# this is basically a wrapper script for file-metrics.sh

# uses a variety of common tools to build a database of files with odd properties that might indicate the
# presence of obfuscated code. output is in the form of a mysql flatfile (for easy database import).

if [ $# -lt 1 ]
then
  # specifying a directory is not optional
  echo "$0: Missing args. Try $0 [target_dir] [optional: host or system name]"
  exit_val="1"
else
  if [ -x /usr/local/bin/parallel ]
  then
    if [ -x file-metrics.sh ]
    then
      # this is optional, so a default value is needed
      if [ -z "$2" ]
      then
        host=$(hostname)
      else
        host="$2"
      fi

      stamp=$(date "+%Y%m%d.%H%M%S")
      job_log="job.${stamp}.log"
      scan_log="scan.${stamp}.log"
      output="${host}.scan.${stamp}.sql"

      exit_val="0"
      allclear_flag="0"
      dir="$1"

      echo "$(date) - $0: Scan cycle begins for target ${host}:${dir}" | tee -a ${scan_log}

      if [ -d "${dir}" ]
      then
        # build output header
        echo "USE sova_scan;" >> ${output}
        echo "/*!40101 SET @saved_cs_client     = @@character_set_client */;" >> ${output}
        echo "/*!40101 SET character_set_client = utf8 */;" >> ${output}
        echo "CREATE TABLE IF NOT EXISTS files (" >> ${output}
        echo "  record_id int(11) NOT NULL AUTO_INCREMENT," >> ${output}
        echo "  scan_date datetime DEFAULT NULL," >> ${output}
        echo "  host varchar(256) DEFAULT NULL," >> ${output}
        echo "  file_perm varchar(10) DEFAULT NULL," >> ${output}
        echo "  file_size bigint(16) DEFAULT NULL," >> ${output}
        echo "  file_date datetime DEFAULT NULL," >> ${output}
        echo "  file_owner varchar(64) DEFAULT NULL," >> ${output}
        echo "  file_group varchar(64) DEFAULT NULL," >> ${output}
        echo "  file_path varchar(1024) DEFAULT NULL," >> ${output}
        echo "  file_data varchar(128) DEFAULT NULL," >> ${output}
        echo "  hash varchar(64) DEFAULT NULL," >> ${output}
        echo "  l_string int(11) DEFAULT NULL," >> ${output}
        echo "  entropy float(14,13) DEFAULT NULL," >> ${output}
        echo "  PRIMARY KEY (record_id)" >> ${output}
        echo ") ENGINE=MyISAM AUTO_INCREMENT=1 DEFAULT CHARSET=latin1;" >> ${output}
        echo "/*!40101 SET character_set_client = @saved_cs_client */;" >> ${output}

        # build output details
        find ${dir} -type f | egrep '\.([a-z]{0,}htm[l]{0,}|pl[cd]{0,}|php[1234567890]{0,}|py|rb|js|jsp|jquery|javascript)$' | parallel --joblog ${job_log} ./file-metrics.sh {} ${host} >> ${output}

        # build output footer
        echo "/*!40000 ALTER TABLE files ENABLE KEYS */;" >> ${output}
        echo "UNLOCK TABLES;" >> ${output}

        if [ -f ${job_log} ]
        then
          echo "$(date) - $0: $(grep "^[0-9]" ${job_log} | wc -l) items scanned" | tee -a ${scan_log}

          # loop through exit values recorded in the job log (should be all zeros)
          for k in $(awk 'FNR > 1 {print $7}' ${job_log})
          do
            if [ "${k}" != "0" ]
            then
              allclear_flag="1"
            fi
          done

          if [ "${allclear_flag}" == "0" ]
          then
            echo "$(date) - $0: Scan cycle completed without errors" | tee -a ${scan_log}
            exit_val="0"
          else
            echo "$(date) - $0: Scan cycle completed with some errors" | tee -a ${scan_log}
          fi
        else
          echo "$(date) - $0: Job log ${job_log} missing!" | tee -a ${scan_log}
        exit_val="1"
        fi

        exit_val="0"
      else
        echo "$(date) - $0: ${dir} not found" | tee -a ${scan_log}
        exit_val="1"
      fi
    else
      echo "$(date) - $0: file-metrics.sh is missing or non-executable"  | tee -a ${scan_log}
      exit_val="1"
    fi
  else
    echo "$(date) - $0: /usr/local/bin/parallel is missing or non-executable"  | tee -a ${scan_log}
    echo "$(date) - $0: Please install GNU Parallel. See: https://www.gnu.org/s/parallel"  | tee -a ${scan_log}
    exit_val="1"
  fi
fi

exit ${exit_val}

# end of script
