#!/bin/bash

# Debug mode
DEBUG=1

# File Paths
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/conversion_log.csv"
PROCESSED_LOG="$LOG_DIR/processed_videos.csv"
STATUS_LOG="$LOG_DIR/status_log.csv"

# Video parameters
WIDTH="1280"
HEIGHT="720"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"

# Headers
CSV_HEADER="Timestamp,Video ID,Source,Thumbnail,Status"
PROCESSED_HEADER="Video ID,Output Source,Thumbnail Path"
STATUS_LOG_HEADER="Video ID,Source,Converted"

# Debug log function
log_debug() {
    [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] $1"
}

# Ensure directories and logs exist
setup_environment() {
    mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
    touch "$SKIPPED_LOG" "$SYSTEM_LOG"
    [[ ! -s "$CSV_LOG" ]] && echo "$CSV_HEADER" > "$CSV_LOG"
    [[ ! -s "$PROCESSED_LOG" ]] && echo "$PROCESSED_HEADER" > "$PROCESSED_LOG"
    [[ ! -s "$STATUS_LOG" ]] && echo "$STATUS_LOG_HEADER" > "$STATUS_LOG"
    log_debug "Environment setup complete: Directories and logs ensured."
}

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-zA-Z0-9._-]//g'
}

# Check if video is already converted
is_video_already_converted() {
    [[ -f "$1" ]]
}

# Convert video file and log status
convert_video_and_log_status() {
    local video_id="$1" input_file="$2" output_file="$3" thumbnail_file="$4"

    if is_video_already_converted "$output_file"; then
        log_debug "Video already converted: $output_file. Skipping."
        echo "$video_id,$input_file,Yes" >> "$STATUS_LOG"
        return
    fi

    # Convert video
    convert_video_file "$video_id" "$input_file" "$output_file" "$thumbnail_file"
    if [[ $? -eq 0 ]]; then
        echo "$video_id,$input_file,Yes" >> "$STATUS_LOG"
    else
        echo "$video_id,$input_file,No" >> "$STATUS_LOG"
    fi
}

# Process videos with updated logging
process_videos() {
    log_debug "Starting video processing..."
    while IFS=',' read -r video_id src; do
        [[ "$video_id" == "Video ID" ]] && continue # Skip header row
        
        local normalized_src input_file output_file thumbnail_file
        normalized_src=$(normalize_filename "$(basename "$src")")
        input_file=$(find "$INPUT_DIR" -type f -name "$normalized_src")

        log_debug "Checking source file for Video ID: $video_id, Source: $src (Normalized: $normalized_src)"
        
        if [[ -z "$input_file" ]]; then
            log_debug "Source file not found for Video ID: $video_id"
            echo "$video_id,$src,No,Source file not found" >> "$STATUS_LOG"
            continue
        fi

        output_file="$OUTPUT_DIR/${normalized_src%.*}.mp4"
        thumbnail_file="$THUMBNAIL_DIR/${normalized_src%.*}.jpg"

        if [[ -f "$output_file" ]]; then
            log_debug "Video already converted: $output_file"
            echo "$video_id,$src,Yes,Already converted" >> "$STATUS_LOG"
            continue
        fi

        convert_video_and_log_status "$video_id" "$input_file" "$output_file" "$thumbnail_file"
    done < "$VIDEO_IDS_CSV"
    log_debug "Video processing complete."
}


# Main script
setup_environment
process_videos
