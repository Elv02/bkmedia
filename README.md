# BKMedia - The Latest and Greatest in Backup Utilities!

## Description

BKMedia was developed as part of an ongoing continuous education effort. It allows you to configure multiple remote locations to back up and restore, all in a single Bash script!  

It also includes a feature to detect and compress newly discovered “alien” files (`*.xyzar`) before backup, helping you manage larger-than-normal media files more efficiently.

## Requirements
- macOS/Linux (or any Unix-based environment)
- `rsync` (install via your package manager of choice)
- SSH key(s) configured for passwordless access to remote hosts

## How to Run
1. **Edit** `locations.cfg`, placing each remote location (e.g. `user@host:/path/to/backup`) on its own line.  
2. **Execute** `./bkmedia.sh` with the desired flags:  
   - **No flags**: Lists each location (with line numbers) from `locations.cfg`.  
   - **`-B`**: Backup mode. Compresses any `.xyzar` files it finds, then rsyncs the rest.  
     - Add **`-L <num>`** to back up only the specified line number in `locations.cfg`.  
   - **`-R <backup_num> -L <num>`**: Restore a specific backup to the location on line `<num>`. If `.xyzar.tar` files exist after restoration, it extracts them.  

Example:  
```bash
# List locations
./bkmedia.sh

# Backup all locations
./bkmedia.sh -B

# Backup only line 2
./bkmedia.sh -B -L 2

# Restore backup #3 to line 1
./bkmedia.sh -R 3 -L 1```

#Known Limitations / TODOs

1. One Restore per Run
    The script exits immediately after the first restore operation completes.

2. Ensure SSH Connectivity
    The script assumes the remote host is reachable via SSH. Make sure you have permissions and keys set up.

3. Archival Clean Up
	The script currently leaves .tars in backup locations. Once a .tar is downloaded or unpacked we should delete it.

# Contributing / Extending

* **Configuration:** Add or remove lines in `locations.cfg` to manage which servers are backed up.
* **Alien Handlers:** Modify the `alien_scan` function if you need additional logic (e.g., skipping certain directories).
* **Compression and Exclusion:** Adjust `rsync` options for different needs. The current setup excludes *.xyzar during backup because they’re handled by alien scanning.

# License

This script is provided as-is. Feel free to modify or distribute it as needed within your environment. Use at your own risk.