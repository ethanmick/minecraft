#!/bin/bash

# Configuration
log_file="/var/log/minecraft_player_watchdog.log"
max_entries=5

# Function to update the log
update_log() {
    local count=$1
    local tmp_file="tmp.log"

    # Add the new count to the log
    echo "$count" >> "$log_file"

    # Keep only the last 'max_entries' lines
    tail -n "$max_entries" "$log_file" > "$tmp_file" && mv "$tmp_file" "$log_file"
}

# Check the number of players
output=$(docker exec -i efs-mc-1 rcon-cli list 2>/dev/null)
count=$(echo $output | cut -d ' ' -f 3)
if [ $? -ne 0 ]; then
    list=0
fi

# Update the log file
update_log "$count"

if [ $(wc -l < "$log_file") -ge "$max_entries" ]; then
    if [ $(awk '{sum += $1} END {print sum}' "$log_file") -eq 0 ]; then
        echo "The player count has been 0 for the last $max_entries checks."
        aws autoscaling set-desired-capacity --auto-scaling-group-name 'Minecraft ASG' --desired-capacity 0 --honor-cooldown
    fi
fi
