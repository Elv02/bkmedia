#!/bin/bash

# TODO: Fix bug in alien scan if no alien files present!

# Global Vars
input="./locations.cfg"
line_number=0
restore_number=""
location_number=""
backup_flag=false
OPTSTRING="BR:L:"

# Function to ensure connection is awake
# TODO: FIX THIS FUNCTION
#   $1 - Location Path
wake_up(){
	host_only=${1%:*}
	echo "Waking up $host_only"
	remaining_attemps=10

	while (( remaining_attemps-- > 0 ))
	do
		[[ $(ssh $host_only) == 0 ]] && break
		sleep 5
	done
	echo "Host $host_only is now awake."
}

# Function to connect to remote and detect/process Alien (.xyzar) files
#   $1 - Location Number
#   $2 - Location Path
#   $3 - Compression Flag
alien_scan() {
	echo "$1 - $2 ($3)"
	host_only=${2%:*}
	echo "Scanning remote ${host_only} for alien files."
	ssh $host_only << EOF
		shopt -s globstar
		shopt -s nullglob
		echo "Processing alien files."
		pattern="**/*.xyzar"
		if [[ "$3" == "restore" ]]; then
			pattern="\${pattern}.tar"
		fi
		for file in \${pattern}; do
			echo "Processing alien record \$file"
			if [[ "$3" == "backup" ]]; then
				tar -czf "\$file.tar" "\$file"
			elif [[ "$3" == "restore" ]]; then
				tar -xvzf "\$file"
			fi
		done
EOF
	# TODO: Update daily log!
	echo "Daily log updated."

	echo "Scan complete."
}

# Function to backup a location
# Arguments:
#   $1 - Location number
#   $2 - Location path
backup_location() {
    echo "Backing up location $1: $2"
    # Get most recent backup #
    next_num=$(ls ./backups/$1 | sort -nr | head -n 1)
    next_num=$((next_num + 1))
    back_loc="./backups/$1/$next_num/"
    mkdir -p "$back_loc" # Create folders as needed
    rsync -ah --exclude=*.xyzar --info=progress2 "$2/" "$back_loc"
    echo "Backup created at $back_loc"
}

# Function to restore a location
# Arguments:
#   $1 - Location number
#   $2 - Location path
#   $3 - Backup number
restore_location() {
    echo "Restoring backup $3 to location $1: $2"
    res_loc="./backups/$1/$3/"
    rsync -ah --info=progress2 "$res_loc" "$2"
    echo "Restoration complete for: $1: $2"
}

# Function to process command line arguments
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

# Function to validate arguments
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
    while IFS= read -r line; do
        ((line_number++))
        if $backup_flag; then
            if [ -z "$location_number" ] || [ "$location_number" -eq "$line_number" ]; then
            	# wake_up $line
            	alien_scan "$line_number" "$line" "backup"
                backup_location "$line_number" "$line"
            fi
        elif [ -n "$restore_number" ]; then
            if [ -z "$location_number" ]; then
                echo "Please indicate which location you would like to restore."
                exit 1
            else
                if [ "$location_number" -eq "$line_number" ]; then
                	# wake_up $line
                    restore_location "$line_number" "$line" "$restore_number"
                    alien_scan "$line_number" "$line" "restore"
                    exit 0 # Exit after restore (only one restore per run allowed).
                fi
            fi
        else
            # If no arguments passed, print location with line number
            echo "$line_number $line"
        fi
    done < "$input"
}

# Main script execution
process_arguments "$@"
validate_arguments
process_locations
