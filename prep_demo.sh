#!/usr/bin/env bash


# Wake_up function copied from main script
wake_up(){
    local loc="$1"
    local host_only=${loc%:*}
    echo "Waking up $host_only"

    local remaining_attempts=10
    while (( remaining_attempts-- > 0 )); do
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

set -e  # Exit on error

CONFIG_FILE="./locations.cfg"

echo "==> Clearing local backups and alien_logs..."
rm -rf ./backups ./alien_logs
echo "Local backups and alien logs removed."
echo ""

if [ ! -f "$CONFIG_FILE" ]; then
  echo "ERROR: '$CONFIG_FILE' not found. Exiting."
  exit 1
fi

echo "==> Preparing remote hosts..."
line_number=0
# Open a unique File Descriptor for input (important later for SSH to use stdin)
exec 3<"$CONFIG_FILE"
while IFS= read -r loc <&3; do
    ((line_number++))
    echo "[$line_number] Handling: $loc"

    host_only=${loc%:*}
    path_only=${loc#*:}

    # Wake up the remote host
    if ! wake_up "$loc"; then
        echo "WARNING: Skipping location $loc due to connection failure."
        continue
    fi

    # Building the remote script
    #   1) rm -rf ./* to nuke everything in the target
    #   2) Create normal files
    #   3) Create some .xyzar files
    remote_script=$(cat <<'EOF'
rm -rf ./*

# Make a normal text file and a subfolder for variety
echo "Just a normal text file" > normal_file.txt
mkdir -p subfolder
echo "Another text file" > subfolder/another_file.txt

# Create a few 10 MB alien files
echo "Creating alien .xyzar files..."
for i in 1 2 3; do
  dd if=/dev/zero of="alien_${i}.xyzar" bs=1M count=10 2>/dev/null
done
EOF
    )

    # SSH in to run the script at the target $path_only
    ssh -n "$host_only" bash -c "'
        cd \"$path_only\" 2>/dev/null || exit 1
        $remote_script
    '"

    echo "Finished prep for $loc."
    echo ""
done
# Close the FD
exec 3<&-
echo "==> All done! Remote hosts are prepped."
exit 0
