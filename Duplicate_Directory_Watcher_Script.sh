#!/usr/bin/env bash

# setsid ./Duplicate_Directory_Watcher_Script.sh ./Watching_folder 4 &> /dev/null

log_path="./directory_watch.log"
directory_watch_path_s=""
second_directory_switch=false

while getopts ":p:s:d:h:" OPTION; do
    case $OPTION in
        p)
            directory_watch_path="$OPTARG"
            if [[ $directory_watch_path != "/"* ]]; then 
                notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $directory_watch_path missing / \n- [!] END"
                exit 1
            fi
            ;;
        s)
            directory_watch_path_s="$OPTARG"
            if [[ $directory_watch_path_s != "/"* ]]; then 
                notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $directory_watch_path_s missing / \n- [!] END"
                exit 1
            fi
            second_directory_switch=true
            ;;
        d)
            re='^[0-9]+$'
            if ! [[ "$OPTARG" =~ $re ]] ; then
                notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- d directory_watch_depth not an integer \n- [!] END"
                exit 1
            fi
            directory_watch_depth="$OPTARG"
            ;;
        *)
            echo "Usage: $0 [-p directory_path] [-s directory_path] [-d directory_watch_depth]"
            exit 1
            ;;
    esac
done

echo "directory_watch_path: $directory_watch_path"
echo "directory_watch_path_s: $directory_watch_path_s"
echo "directory_watch_depth: $directory_watch_depth"
echo "second_directory_switch: $second_directory_switch"

if [ ! -d "$directory_watch_path" ]; then
    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $directory_watch_path does not exist.\n- [!] END"
    exit 1
fi

if [ $second_directory_switch == true ]; then
    if [ ! -d "$directory_watch_path_s" ]; then
        notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $directory_watch_path_s does not exist.\n- [!] END"
        exit 1
    fi
fi 

#if [ "$#" > 2 ] ; then
#fi

# If ./directory_watch.log does not exist, record filenames of all files in watched directory at n directory depth.
if [ ! -f $log_path ] ; then
    find $directory_watch_path -mindepth "$(($directory_watch_depth-1))" -maxdepth "$(($directory_watch_depth-1))" -type d | sort -V | while read -r line; do echo "$(date +"%FT%I:%M:%S%p%Z") CREATE,ISDIR $line" | tee -a $log_path; done
    if [ $second_directory_switch == true ]; then
        find $directory_watch_path_s -mindepth "$(($directory_watch_depth-1))" -maxdepth "$(($directory_watch_depth-1))" -type d | sort -V | while read -r line; do echo "$(date +"%FT%I:%M:%S%p%Z") CREATE,ISDIR $line" | tee -a $log_path; done
    fi
    notify-send --expire-time=0 --urgency=critical -i ~/vcs-locally-modified-unstaged.svg "$(date +"%FT%I:%M:%S%p%Z")" "\- $log_path does not exist.\n- Captured current state of watched folder(s)\n- [!] END"
    exit 1
fi

: '
# Use this instead: grep "CREATE,ISDIR" ./directory_watch.log > ./$(date +"%FT%I:%M:%S%p%Z")-directory_watch.log
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

# Example: find "$PWD" -ls | grep -P " /[^/]+/[^/]+/[^/]+/[^/]+/[^/]+/[^/]+$"
# Main > Category > Subfolders > Created_Folders
depth_pattern=""
for ((i = 1; i <= $directory_watch_depth ; i++));
    do depth_pattern+="/[^/]+"; 
done;
depth_pattern+="$"
echo -e "$depth_pattern"

# -m: Execute indefinitely. -r: Watch all subdirectories of any directories passed as arguments
inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' $directory_watch_path $directory_watch_path_s |
while read -r line; 
do
    # Ignore non-directory creations.
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
