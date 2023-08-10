#!/usr/bin/env bash

#output=$("inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' ./Watching_folder/ | tee -a >> ./directory_watching_log.log | grep 'CREATE\|DELETE'")

#inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' ./Watching_folder/ | tee -a ./directory_watching.log |

# setsid ./Directory_Watcher_Script.sh ./Watching_folder &> /dev/null
#./Directory_Watcher_Script.sh ./Watching_folder

log_path="./directory_watch.log"

if [ ! -d "$1" ]; then
    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $1 does not exist.\n- [!] END"
    exit 1
fi

# If ./directory_watch.log does not exist, record filenames of all files in watched directory.
# Search directories 2 levels deep.
if [ ! -f $log_path ] ; then
    find $1 -maxdepth 3 -type d | sort -V | while read line; do echo "$(date +"%FT%I:%M:%S%p%Z") CREATE,ISDIR $line" | tee -a $log_path; done
    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $log_path does not exist.\n- Captured current state of watched folder\n- [!] END"
    exit 1
fi

: '
# ./Directory_Watcher_Script.sh deletion_record
if [[ $1 == "deletion_record" ]] ; then
    echo -e "[+] Creating log file of file deletion logs:" "./$(date +"%FT%I:%M:%S%p%Z")-directory_watch.log"
    grep "DELETE" $log_path
    grep "DELETE" $log_path > ./$(date +"%FT%I:%M:%S%p%Z")-directory_watch.log
    echo "[!] END"
    exit 1
fi
'

notify-send -i ~/vcs-update-required.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- [Running Directory_Watcher_Script.sh]"
#exit 1
#export DISPLAY=:0.0
# -m: Execute indefinitely. -r: Watch all subdirectories of any directories passed as arguments
# TODO: Search directory n levels down.
# Main > Category > Subfolders > Created_Folders
# find "$PWD" -ls
# ls -l | grep '^./*/*/*/*
# find "$PWD" -ls | grep -P "/.+/.+/.+/.+/"
# /[^/]+/[^/]+/[^/]+/[^/]+/[^/]+/$
inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' $1 |
while read line; 
do
    # Only match directory at certain depth here.
    echo -e "[Debug] - $line"
    if echo -e "\033[1;32m$line\033[0m" | grep "CREATE,ISDIR" ; then
        echo ""
        # Ignore non-directory creations.
        if [[ $line == *"ISDIR"* ]] ; then
            line_switch=false
            extracted_string="${line##*/}"
            while IFS= read -r log_line
            do
                if [[ $log_line == *"ISDIR"* ]] ; then
                    # Identifies every line with "DELETE" keyword in log file and extract string after "/"
                    if [[ $log_line == *"DELETE"*"/$extracted_string" ]] ; then
                        notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "[Previously Deleted Directory Detected]" "$line\n$log_line"  
                        echo -e "\033[1;31m[Previously deleted file detected]\033[0m"
                        echo "Extracted_String:$extracted_string"
                        echo "$log_line"
                        line_switch=true
                        break
                    fi
                fi
            done < "$log_path"
            # Append newly created log lines to log file if previously deleted file not detected.
            if [[ ${line_switch} = false ]] ; then
                echo $line >> $log_path;
            fi
            if [[ ${line_switch} = true ]] ; then
                # Created files previously deleted added to log file as "REPEAT"
                line="${line/CREATE/REPEAT}"
                echo $line >> $log_path;
            fi
        # PROTOTYPE:
        #else
        #    echo "$(date +"%FT%I:%M:%S%p%Z") DIRCRE $line"
        fi
    # Append lines without "CREATE" keyword.
    else
        if [[ $line == *"ISDIR"* ]] ; then
            echo $line | tee -a $log_path;
        # PROTOTYPE:
        #else
        #    echo "$(date +"%FT%I:%M:%S%p%Z") DIRDEL $line"
        fi
    fi
done; 

# Testing Report:
# Script will not identify whether identical files are created in two seperate places unless a previously deleted record exist.

# Expected: All deleted log files recorded | Actual: Expected
# touch abc.txt 123.txt compressed.gz test.log
# rm abc.txt 123.txt compressed.gz test.log

# Expected: Newly created files reported as previously deleted file if deleted log already exist | Actual: Expected
# rm ~/directory_watch.log
# touch abc.txt 123.txt compressed.gz test.log
# rm abc.txt 123.txt compressed.gz test.log
# touch abc.txt 123.txt compressed.gz test.log
# rm ~/directory_watch.log

# Expected: Script to run in background and still append new lines to log file and send notifications | Actual: Expected
# export DISPLAY=:0.0
# setsid ./Directory_Watcher_Script.sh ./Watching_folder &> /dev/null
# notify-send should continue to work when script is treated as background task and with terminal closed.

# Expected: Create file then delete. Create again in different location in watched directory and receive notification | Actual: Expected
# mkdir -p ./New_Folder/Test/ && touch ./New_Folder/Test/123.txt
# rm ./New_Folder/Test/123.txt
# touch ./123.txt

# Other use cases to consider:
# - Moving files from seperate folder into watched folder. Must be considered as "new" files.
# - Files moved to rubbish bin and not be logged as deleted.
