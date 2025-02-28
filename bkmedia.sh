#!/bin/bash

# Global Vars
input="./locations.cfg"
line_number=0

backup_location()
{
	echo "Backing up location $1: $2";
	# Get most recent backup #
	next_num=$(ls ./backups/$1 | sort -r | head -n 1);
	next_num=$((next_num+1));
	back_loc="./backups/$1/$next_num";
	mkdir -p $back_loc; # Create folders as needed
	rsync -ah --info=progress2 $2 $back_loc;
	# scp -rp $2 $back_loc; # TODO: Replace scp w/ rsync?
	echo "Backup created at $back_loc";
}

restore_location()
{
	echo "Restore initiated.";
}

# Process command for locations line-by-line
while IFS= read -r line
do
	((line_number++));
	if [ "$1" == "-B" ]; then
		if [[ -z "$2" || "$2" == "-L" && "$3" == "$line_number" ]]; then
			backup_location $line_number "$line"
		fi
	fi
	if [ "$1" == "-R" ]; then
		restore_location $2 $3
	fi
	# If no arguments passed, print location w/ line number
	if [ -z "${1}" ]; then
		echo "$line_number $line"
	fi
done < "$input"