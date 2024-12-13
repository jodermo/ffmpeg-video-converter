#!/bin/bash

# Debug mode
DEBUG=1

# File Paths
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
LOG_DIR="./logs"

INPUT_FILES_LOG="$LOG_DIR/input_files_log.csv"
FOUND_LOG="$LOG_DIR/found_log.csv"
NOT_FOUND_LOG="$LOG_DIR/not_found_log.csv"

# Headers
INPUT_FILES_HEADER="Timestamp,Filename,Normalized Filename"
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
    echo "$FOUND_LOG_HEADER" > "$FOUND_LOG"
    echo "$NOT_FOUND_LOG_HEADER" > "$NOT_FOUND_LOG"
    log_debug "Environment setup complete: Directories and logs ensured."
}

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' \
        | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]//g'
}

# Filter and log input files
log_files_in_directory() {
    local directory="$1"
    local log_file="$2"
    log_debug "Logging files in directory: $directory"

    find "$directory" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.wmv" \) ! -name '*Zone.Identifier' | while read -r file; do
        local filename normalized_filename
        filename=$(basename "$file")
        normalized_filename=$(normalize_filename "$filename")
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$filename,$normalized_filename" >> "$log_file"
    done
}

# Process videos
process_videos() {
    declare -A normalized_input_files

    # Build a map of normalized filenames in the input directory
    while IFS=',' read -r _ filename normalized_filename; do
        normalized_input_files["$normalized_filename"]="$filename"
    done < <(tail -n +2 "$INPUT_FILES_LOG")

    # Compare CSV entries with normalized filenames in the input directory
    while IFS=',' read -r video_id src; do
        [[ "$video_id" == "\"id\"" ]] && continue

        local raw_src normalized_src
        raw_src=$(echo "$src" | tr -d '"')
        normalized_src=$(normalize_filename "$(basename "$raw_src")")

        if [[ -v "normalized_input_files[$normalized_src]" ]]; then
            log_debug "File found for Video ID: $video_id, src: $raw_src, normalized_src: $normalized_src"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$raw_src,$normalized_src,Yes,File found" >> "$FOUND_LOG"
        else
            log_debug "File not found for Video ID: $video_id, src: $raw_src, normalized_src: $normalized_src"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$raw_src,$normalized_src,No,File not found in $INPUT_DIR" >> "$NOT_FOUND_LOG"
        fi
    done < "$VIDEO_IDS_CSV"
    log_debug "Video processing complete."
}

# Main script
setup_environment
log_files_in_directory "$INPUT_DIR" "$INPUT_FILES_LOG"
process_videos
