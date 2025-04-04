#!/bin/bash

# Global Vars
input="./locations.cfg"
line_number=0
restore_number=""
location_number=""
backup_flag=false
OPTSTRING="BR:L:"

# Function to ensure connection is awake
#   $1 - Location Path
wake_up(){
	host_only=${1%:*}
	echo "Waking up $host_only"
	remaining_attemps=10

	while (( remaining_attemps-- > 0 ))
	do
		# Attempt simple SSH command with immediate return
		ssh -o ConnectTimeout=5 "$host_only" "exit 0" >/dev/null 2>&1
		if [ $? -eq 0 ]; then
			echo "Host $host_only is now awake."
			return 0
		fi
		echo "Retrying connection to $host_only..."
		sleep 5
	done

	echo "ERROR: Failed to connect to $host_only after multiple attempts."
	return 1
}

# Function to connect to remote and detect/process Alien (.xyzar) files
#   $1 - Location Number
#   $2 - Location Path
#   $3 - Compression Flag
alien_scan() {
    local loc_num="$1"
    local loc_path="$2"
    local mode="$3"

    local host_only=${loc_path%:*}

    echo "Alien scan on location #$loc_num: $loc_path ($mode)"

    # If in backup mode, set up local logging
    local log_file=""
    if [[ "$mode" == "backup" ]]; then
        mkdir -p "alien_logs"
        log_file="alien_logs/alien_log_$(date +%F).log"
        echo "Alien file details will be appended to: $log_file"
    fi

    # Build the remote script as a heredoc
    local remote_script
    if [[ "$mode" == "backup" ]]; then
        remote_script='
            shopt -s globstar nullglob
            files=( **/*.xyzar )
            if [ ${#files[@]} -eq 0 ]; then
                exit 0
            fi
            for file in "${files[@]}"; do
                old_size=$(stat -c %s "$file" 2>/dev/null || echo 0)
                tar -czf "$file.tar" "$file"
                new_size=$(stat -c %s "$file.tar" 2>/dev/null || echo 0)
                echo "<$file> OriginalSize=$old_size CompressedSize=$new_size"
            done
        '
    else
        # Assume "restore"
        remote_script='
            shopt -s globstar nullglob
            files=( **/*.xyzar.tar )
            if [ ${#files[@]} -eq 0 ]; then
                exit 0
            fi
            for file in "${files[@]}"; do
                tar -xvzf "$file"
                echo "RESTORED: $file"
                rm "$file"
            done
        '
    fi

    # Run the remote script over SSH
    if [[ -n "$log_file" ]]; then
        # 1) SSH to remote host
        # 2) Pipe its output into a while-read loop
        # 3) Prepend server info + timestamp
        # 4) Append to the log
        ssh "$host_only" bash -s <<<"$remote_script" \
        | while IFS= read -r line; do
            echo "[$(date +%F_%T)] [$host_only] $line"
        done | tee -a "$log_file"
    else
        # Not in backup mode => no log file
        ssh "$host_only" bash -s <<<"$remote_script" \
        | while IFS= read -r line; do
            echo "[$(date +%F_%T)] [$host_only] $line"
        done
    fi

    echo "Alien scan complete for #$loc_num ($mode)."
}

# Function to backup a location
# Arguments:
#   $1 - Location number
#   $2 - Location path
backup_location() {
    echo "Backing up location $1: $2"
    # Get most recent backup #
    next_num=$(ls "./backups/$1" 2>/dev/null | sort -nr | head -n 1)
    if [ -z "$next_num" ]; then
    	next_num=0
    fi
    next_num=$((next_num + 1))
    back_loc="./backups/$1/$next_num/"
    mkdir -p "$back_loc" # Create folders as needed
    # Exclude the base alien files (only grab compressed copies)
    rsync -ah --exclude=*.xyzar --info=progress2 "$2/" "$back_loc"
    echo "Backup created at $back_loc"
}

# Function that restores a location
# Arguments:
#   $1 - Location number
#   $2 - Location path
#   $3 - Backup number
restore_location() {
    local loc_num="$1"
    local loc_path="$2"
    local nth_most_recent="$3"

    echo "Restoring backup number $nth_most_recent from the most recent backup for location $loc_num: $loc_path"

    # Grab all backup folders for this location and sort them in descending order
    local folder_list
    folder_list=$(ls "./backups/$loc_num" 2>/dev/null | sort -nr)

    # Pick out the Nth line (the Nth most recent folder)
    local actual_folder
    actual_folder=$(echo "$folder_list" | sed -n "${nth_most_recent}p")

    # If actual_folder is empty, it means there isn't that many backups
    if [ -z "$actual_folder" ]; then
        echo "ERROR: There are only $(echo "$folder_list" | wc -l) backups for location #$loc_num."
        echo "Cannot restore the $nth_most_recent-th most recent backup."
        exit 1
    fi

    local res_loc="./backups/$loc_num/$actual_folder"

    if [ ! -d "$res_loc" ]; then
        echo "ERROR: Backup directory $res_loc does not exist. Cannot proceed."
        exit 1
    fi

    # Perform the actual restore
    rsync -ah --info=progress2 "$res_loc/" "$loc_path"
    echo "Restoration complete for location #$loc_num: $loc_path (used folder $actual_folder)."
}

# Function which processes command line arguments
process_arguments() {
    while getopts ${OPTSTRING} opt; do
        case $opt in
            B)
                backup_flag=true
                ;;
            R)
                restore_number=$OPTARG
                ;;
            L)
                location_number=$OPTARG
                ;;
            \?)
                echo "Unsupported argument: -$OPTARG" >&2 # Note: Redirects to stderr
                exit 1
                ;;
            :)
                echo "Option -$OPTARG requires an argument." >&2
                exit 1
                ;;
        esac
    done
}

# Function which validates command line arguments
validate_arguments() {
    if $backup_flag && [ -n "$restore_number" ]; then
        echo "Error: Please specify whether you want to perform a backup or restore operation, not both."
        exit 1
    fi

    if [ -n "$location_number" ] && ! $backup_flag && [ -z "$restore_number" ]; then
        echo "Error: Location was provided, but no backup or restore operation was indicated. Cannot proceed."
        exit 1
    fi
}

# Function to process locations from the config file
process_locations() {
	# Open a unique FD for input (important later for SSH to use stdin)
	exec 3<"$input"
    while IFS= read -r line <&3; do
        ((line_number++))
        if $backup_flag; then
            if [ -z "$location_number" ] || [ "$location_number" -eq "$line_number" ]; then
            	wake_up $line
            	alien_scan "$line_number" "$line" "backup"
                backup_location "$line_number" "$line"
            fi
        elif [ -n "$restore_number" ]; then
            if [ -z "$location_number" ]; then
                echo "Please indicate which location you would like to restore."
                exit 1
            else
                if [ "$location_number" -eq "$line_number" ]; then
                	wake_up $line
                    restore_location "$line_number" "$line" "$restore_number"
                    alien_scan "$line_number" "$line" "restore"
                    exit 0 # Exit after restore (only one restore per run allowed).
                fi
            fi
        else
            # If no arguments passed, print location with line number
            echo "$line_number $line"
        fi
    done
    # Close the FD
    exec 3<&-
}

# Main script execution
process_arguments "$@"
validate_arguments
process_locations
