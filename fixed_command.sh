#!/bin/sh

inotifywait -mr -e delete,create --timefmt '%FT%I:%M:%S%p%Z' --format '%T %e %w%f' ./Watched_folder/ | tee -a ./directory_watching.log | grep 'CREATE\|DELETE'
