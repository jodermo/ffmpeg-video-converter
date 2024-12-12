#!/bin/bash

# Debug mode
DEBUG=1

# Debug log function
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "[DEBUG] $1"
    fi
}

# File Paths
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
INPUT_DIR="./input_videos"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"

# Ensure directories and log files exist
mkdir -p "$LOG_DIR"
touch "$SKIPPED_LOG" "$SYSTEM_LOG"

log_debug "Directories and log files ensured: LOG_DIR=$LOG_DIR"

# Function to normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]' | sed 's/[^\w\.-]//g'
}

# Process each file in INPUT_DIR
for file_path in "$INPUT_DIR"/*; do
    if [[ -f "$file_path" ]]; then
        file_name=$(basename "$file_path")
        normalized_file_name=$(normalize_filename "$file_name")

        log_debug "Processing file: $file_name (Normalized: $normalized_file_name)"

        # Search for normalized name in CSV
        found_in_csv=false
        while IFS=',' read -r video_id src; do
            csv_normalized_name=$(normalize_filename "$(basename "$src")")
            if [[ "$normalized_file_name" == "$csv_normalized_name" ]]; then
                found_in_csv=true
                log_debug "Match found in CSV: $csv_normalized_name for Video ID: $video_id"
                break
            fi
        done < <(tail -n +2 "$VIDEO_IDS_CSV")

        if [[ "$found_in_csv" == false ]]; then
            log_debug "No match found in CSV for file: $file_name"
            echo "No match for $file_name" >> "$SKIPPED_LOG"
        fi
    fi
done
