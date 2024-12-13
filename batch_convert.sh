#!/bin/bash

# Debug mode
DEBUG=1

# Directories
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

# Log files
SKIPPED_LOG="$LOG_DIR/skipped_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/conversion_log.csv"

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
CSV_HEADER="Timestamp,Source,Output,Thumbnail,Status"

# Debug log function
log_debug() {
    [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] $1"
}

# Ensure directories and logs exist
setup_environment() {
    mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
    touch "$SKIPPED_LOG" "$SYSTEM_LOG"
    [[ ! -s "$CSV_LOG" ]] && echo "$CSV_HEADER" > "$CSV_LOG"
    log_debug "Environment setup complete: Directories and logs ensured."
}

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' \
        | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]//g'
}

# Convert video and generate thumbnail
process_video_file() {
    local input_file="$1"
    local base_name output_file thumbnail_file

    base_name=$(basename "$input_file" .mp4)
    output_file="$OUTPUT_DIR/$base_name.mp4"
    thumbnail_file="$THUMBNAIL_DIR/$base_name.jpg"

    # Skip if output file already exists
    if [[ -f "$output_file" ]]; then
        log_debug "Video already converted: $output_file. Skipping."
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$input_file,$output_file,$thumbnail_file,Skipped (Already converted)" >> "$CSV_LOG"
        return
    fi

    # Convert video
    log_debug "Converting video: $input_file"
    ffmpeg -y -i "$input_file" \
        -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        >> "$SYSTEM_LOG" 2>&1

    if [[ $? -eq 0 ]]; then
        log_debug "Video conversion successful: $output_file"
    else
        log_debug "Video conversion failed: $input_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$input_file,,,Conversion Failed" >> "$CSV_LOG"
        echo "$input_file" >> "$SKIPPED_LOG"
        return
    fi

    # Generate thumbnail
    log_debug "Generating thumbnail for: $input_file"
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" \
        >> "$SYSTEM_LOG" 2>&1

    if [[ $? -eq 0 ]]; then
        log_debug "Thumbnail generation successful: $thumbnail_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$input_file,$output_file,$thumbnail_file,Success" >> "$CSV_LOG"
    else
        log_debug "Thumbnail generation failed: $input_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$input_file,$output_file,,Thumbnail Failed" >> "$CSV_LOG"
    fi
}

# Process all videos in the input directory
process_all_videos() {
    for file_path in "$INPUT_DIR"/*; do
        [[ -f "$file_path" ]] || continue

        log_debug "Processing file: $file_path"
        process_video_file "$file_path"
    done
}

# Main script
setup_environment
process_all_videos
