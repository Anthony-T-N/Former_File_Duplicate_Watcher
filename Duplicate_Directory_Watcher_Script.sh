#!/usr/bin/env bash

#output=$("inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' ./Watching_folder/ | tee -a >> ./directory_watching_log.log | grep 'CREATE\|DELETE'")

#inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' ./Watching_folder/ | tee -a ./directory_watching.log |

# setsid ./Duplicate_Directory_Watcher_Script.sh ./Watching_folder &> /dev/null
# setsid ./Duplicate_Directory_Watcher_Script.sh ./Watching_folder 4 &> /dev/null
#./Duplicate_Directory_Watcher_Script.sh ./Watching_folder

log_path="./directory_watch.log"

if [ ! -d "$1" ]; then
    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $1 does not exist.\n- [!] END"
    exit 1
fi

# If ./directory_watch.log does not exist, record filenames of all files in watched directory.
# Search directories 3 levels deep.
if [ ! -f $log_path ] ; then
    find $1 -mindepth "$(($2-1))" -maxdepth "$(($2-1))" -type d | sort -V | while read -r line; do echo "$(date +"%FT%I:%M:%S%p%Z") CREATE,ISDIR $line" | tee -a $log_path; done
    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $log_path does not exist.\n- Captured current state of watched folder\n- [!] END"
    exit 1
fi

: '
# ./Duplicate_Directory_Watcher_Script.sh deletion_record
if [[ $1 == "deletion_record" ]] ; then
    echo -e "[+] Creating log file of file deletion logs:" "./$(date +"%FT%I:%M:%S%p%Z")-directory_watch.log"
    grep "DELETE" $log_path
    grep "DELETE" $log_path > ./$(date +"%FT%I:%M:%S%p%Z")-directory_watch.log
    echo "[!] END"
    exit 1
fi
'

notify-send -i ~/vcs-update-required.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- [Running Duplicate_Directory_Watcher_Script.sh]"

#export DISPLAY=:0.0
# -m: Execute indefinitely. -r: Watch all subdirectories of any directories passed as arguments
# Main > Category > Subfolders > Created_Folders
# find "$PWD" -ls
# ls -l | grep '^./*/*/*/*
# find "$PWD" -ls | grep -P "/.+/.+/.+/.+/"
# /media/user/device/Category/Sub-category/Item/IGNORE/IGNORE

depth_pattern="." 
for ((i = 1; i <= $2 ; i++));
    do depth_pattern+="/[^/]+"; 
done;
depth_pattern+="$"
echo -e "$depth_pattern"

inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' $1 |
while read -r line; 
do
    # Only match directory at certain depth here.
    # # Ignore non-directory creations.
    if echo -e "\033[1;32m$line\033[0m" | grep -P "CREATE,ISDIR $depth_pattern" ; then
        line_switch=false
        extracted_string="${line##*/}"
        while IFS= read -r log_line
        do
            if [[ $log_line == *"ISDIR"* ]] ; then
                # Identifies every line with "DELETE" keyword in log file and extract string after "/"
                if [[ $log_line == *"DELETE"*"/$extracted_string" ]] ; then
                    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "[Previously Deleted Directory Detected]" "$line\n$log_line"  
                    echo -e "\033[1;31m[Previously Deleted Directory Detected]\033[0m"
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
    # Append lines without "CREATE" keyword.
    fi
    if echo -e "\033[1;32m$line\033[0m" | grep -P "DELETE,ISDIR $depth_pattern" ; then
        echo $line >> $log_path;
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
# setsid ./Duplicate_Directory_Watcher_Script.sh ./Watching_folder &> /dev/null
# notify-send should continue to work when script is treated as background task and with terminal closed.

# Expected: Create file then delete. Create again in different location in watched directory and receive notification | Actual: Expected
# mkdir -p ./New_Folder/Test/ && touch ./New_Folder/Test/123.txt
# rm ./New_Folder/Test/123.txt
# touch ./123.txt

# Other use cases to consider:
# - Moving files from seperate folder into watched folder. Must be considered as "new" files.
# - Files moved to rubbish bin and not be logged as deleted.
