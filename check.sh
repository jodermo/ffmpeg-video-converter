#!/bin/bash

# Debug mode
DEBUG=1

# File Paths
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
LOG_DIR="./logs"

INPUT_FILES_LOG="$LOG_DIR/input_files_log.csv"
OUTPUT_FILES_LOG="$LOG_DIR/output_files_log.csv"
FOUND_LOG="$LOG_DIR/found_log.csv"
NOT_FOUND_LOG="$LOG_DIR/not_found_log.csv"

# Headers
INPUT_FILES_HEADER="Timestamp,Filename,Normalized Filename"
OUTPUT_FILES_HEADER="Timestamp,Filename,Normalized Filename"
FOUND_LOG_HEADER="Timestamp,Video ID,Source,Normalized Source,Found,Reason"
NOT_FOUND_LOG_HEADER="Timestamp,Video ID,Source,Normalized Source,Found,Reason"

# Debug log function
log_debug() {
    [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] $1"
}

# Ensure directories and logs exist
setup_environment() {
    mkdir -p "$LOG_DIR"
    echo "$INPUT_FILES_HEADER" > "$INPUT_FILES_LOG"
    echo "$OUTPUT_FILES_HEADER" > "$OUTPUT_FILES_LOG"
    echo "$FOUND_LOG_HEADER" > "$FOUND_LOG"
    echo "$NOT_FOUND_LOG_HEADER" > "$NOT_FOUND_LOG"
    log_debug "Environment setup complete: Directories and logs ensured."
}

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-zA-Z0-9._-]//g'
}


# Log all files in a directory
log_files_in_directory() {
    local directory="$1"
    local log_file="$2"
    log_debug "Logging files in directory: $directory"

    find "$directory" -type f | while read -r file; do
        local filename normalized_filename
        filename=$(basename "$file")
        normalized_filename=$(normalize_filename "$filename")
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$filename,$normalized_filename" >> "$log_file"
    done
}

# Process videos and log found/not found
process_videos() {
    log_debug "Check for video files..."
    while IFS=',' read -r video_id src; do
        [[ "$video_id" == "\"id\"" ]] && continue # Skip header row

        local normalized_src input_file
        normalized_src=$(normalize_filename "$(basename "$src" | tr -d '\"')")
        input_file=$(find "$INPUT_DIR" -type f -iname "$normalized_src")

        log_debug "Checking source file for Video ID: $video_id, Source: $src (Normalized: $normalized_src)"
        
        if [[ -z "$input_file" ]]; then
            log_debug "Source file not found for Video ID: $video_id"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$src,$normalized_src,No,File not found in $INPUT_DIR" >> "$NOT_FOUND_LOG"
        else
            log_debug "Source file found for Video ID: $video_id"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$src,$normalized_src,Yes,File found" >> "$FOUND_LOG"
        fi
    done < "$VIDEO_IDS_CSV"
    log_debug "Video processing complete."
}

# Main script
setup_environment
log_files_in_directory "$INPUT_DIR" "$INPUT_FILES_LOG"
log_files_in_directory "$OUTPUT_DIR" "$OUTPUT_FILES_LOG"
process_videos
