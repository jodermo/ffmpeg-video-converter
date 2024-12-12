#!/bin/bash

# Debug mode (set to 1 to enable debug logs, 0 to disable)
DEBUG=1

# Debug log function
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "[DEBUG] $1" | tee -a "$SYSTEM_LOG"
    fi
}

# File Paths
VIDEO_IDS_CSV="./csv_data/video_ids.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
COMPLETED_LOG="$LOG_DIR/completed_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/conversion_log.csv"

# Ensure directories and log files exist
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
touch "$COMPLETED_LOG" "$SKIPPED_LOG" "$SYSTEM_LOG"

log_debug "Directories and log files ensured: LOG_DIR=$LOG_DIR, OUTPUT_DIR=$OUTPUT_DIR, THUMBNAIL_DIR=$THUMBNAIL_DIR"

# Video parameters
WIDTH="1280"
HEIGHT="720"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"

# Initialize CSV log
echo "Timestamp,Video ID,Source,Thumbnail,Status" > "$CSV_LOG"

# Function to check if a file has already been processed
is_already_processed() {
    local input_file="$1"
    if grep -qF "$(basename "$input_file")" "$COMPLETED_LOG"; then
        return 0
    fi
    return 1
}

# Function to find the file in INPUT_DIR
find_video_file() {
    local src_filename="$1"
    local found_file=$(find "$INPUT_DIR" -type f -name "$(basename "$src_filename")" -print -quit)
    echo "$found_file"
}

# Function to convert video and generate thumbnail
convert_video_file() {
    local video_id="$1"
    local input_file="$2"
    local is_portrait="$3"
    local output_file="$4"
    local thumbnail_file="$5"

    local scale=""
    if [[ "$is_portrait" == "true" ]]; then
        scale="${HEIGHT}:${WIDTH}"
    else
        scale="${WIDTH}:${HEIGHT}"
    fi

    # Convert video
    ffmpeg -y -i "$input_file" \
        -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" 2>>"$SYSTEM_LOG"

    if [[ $? -eq 0 ]]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Success" >> "$CSV_LOG"
        echo "$(basename "$input_file")" >> "$COMPLETED_LOG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Failed" >> "$CSV_LOG"
        echo "Failed to convert video: $input_file" | tee -a "$SKIPPED_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" 2>>"$SYSTEM_LOG"

    if [[ $? -eq 0 ]]; then
        echo "[DEBUG] Thumbnail generated for video ID $video_id at $thumbnail_file" | tee -a "$SYSTEM_LOG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Thumbnail Failed" >> "$CSV_LOG"
        echo "Failed to generate thumbnail: $input_file" | tee -a "$SKIPPED_LOG"
    fi
}

# Main loop to process video sources
while IFS=',' read -r video_id src; do
    # Skip header row
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    log_debug "Processing video ID: $video_id, Source: $src"

    # Extract filename
    src_filename=$(basename "$src")
    input_file=$(find_video_file "$src_filename")
    output_file="$OUTPUT_DIR/$src_filename"
    thumbnail_file="$THUMBNAIL_DIR/${src_filename%.*}.jpg"

    # Check if file exists
    if [[ -z "$input_file" ]]; then
        echo "Video file not found: $src_filename" | tee -a "$SKIPPED_LOG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$src,,Skipped" >> "$CSV_LOG"
        continue
    fi


    # Detect orientation
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input_file")
    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)

    if (( height > width )); then
        is_portrait="true"
    else
        is_portrait="false"
    fi

    # Convert video and generate thumbnail
    convert_video_file "$video_id" "$input_file" "$is_portrait" "$output_file" "$thumbnail_file"
done < "$VIDEO_IDS_CSV"
