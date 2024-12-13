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
    log_debug "Environment setup complete: Directories and logs ensured."
}

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' \
        | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]//g'
}

# Process video
convert_video_file() {
    local video_id="$1" input_file="$2" output_file="$3" thumbnail_file="$4"

    if [[ -f "$output_file" ]]; then
        log_debug "Video already converted: $output_file. Skipping."
        echo "$video_id,$output_file,$thumbnail_file" >> "$PROCESSED_LOG"
        return 0
    fi

    local is_portrait
    is_portrait=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$input_file" | awk -F'x' '{print ($2 > $1 ? "true" : "false")}')

    local scale_width="$WIDTH"
    local scale_height="$HEIGHT"
    if [[ "$is_portrait" == "true" ]]; then
        scale_width="$HEIGHT"
        scale_height="$WIDTH"
    fi

    echo "Converting video: $input_file"
    ffmpeg -y -i "$input_file" \
        -vf "scale=${scale_width}:${scale_height}:force_original_aspect_ratio=decrease,pad=${scale_width}:${scale_height}:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        >> "$SYSTEM_LOG" 2>&1

    if [[ $? -eq 0 ]]; then
        log_debug "Video conversion successful: $output_file"
        ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" >> "$SYSTEM_LOG" 2>&1
        if [[ $? -eq 0 ]]; then
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Success" >> "$CSV_LOG"
        else
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Thumbnail Failed" >> "$CSV_LOG"
        fi
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Conversion Failed" >> "$CSV_LOG"
        echo "$input_file" >> "$SKIPPED_LOG"
    fi
}

# Process each video with progress
process_videos() {
    local total_files processed_files=0
    total_files=$(find "$INPUT_DIR" -type f | wc -l)

    for file_path in "$INPUT_DIR"/*; do
        [[ -f "$file_path" ]] || continue
        ((processed_files++))

        local file_name normalized_file_name
        file_name=$(basename "$file_path")
        normalized_file_name=$(normalize_filename "$file_name")

        log_debug "Processing file: $file_name (Normalized: $normalized_file_name)"

        local output_file="$OUTPUT_DIR/${file_name%.*}.mp4"
        local thumbnail_file="$THUMBNAIL_DIR/${file_name%.*}.jpg"

        convert_video_file "$processed_files" "$file_path" "$output_file" "$thumbnail_file"

        local progress=$((processed_files * 100 / total_files))
        printf "\rProcessing videos... %d%% (%d/%d completed)" "$progress" "$processed_files" "$total_files"
    done
    echo "" # New line after progress bar
}

# Main script
setup_environment
process_videos
