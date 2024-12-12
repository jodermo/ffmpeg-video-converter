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
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
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
touch "$COMPLETED_LOG" "$SKIPPED_LOG" "$SYSTEM_LOG" "$CSV_LOG"

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

# Initialize CSV log if empty
if [[ ! -s "$CSV_LOG" ]]; then
    echo "Timestamp,Video ID,Source,Thumbnail,Status" > "$CSV_LOG"
fi

# Function to check if a video ID has already been processed
is_already_processed() {
    local video_id="$1"
    if grep -qF "$video_id" "$COMPLETED_LOG" || grep -qF "$video_id" "$CSV_LOG"; then
        return 0  # Already processed
    fi
    return 1  # Not processed
}

# Function to normalize filenames
normalize_filename() {
    echo "$1" | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]'
}

# Function to find the file in INPUT_DIR
find_video_file() {
    local normalized_name
    normalized_name=$(normalize_filename "$(basename "$1")")
    find "$INPUT_DIR" -type f -iname "$normalized_name" -print -quit
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

    # Get video duration
    local duration
    duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
    duration=${duration%.*} # Convert to integer seconds

    # Run ffmpeg with progress tracking
    echo "Converting video: $input_file (ID: $video_id)"
    ffmpeg -y -i "$input_file" \
        -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:1 2>&1 | while IFS="=" read -r key value; do
            if [[ "$key" == "out_time_us" ]]; then
                local current_time=$((value / 1000000)) # Convert microseconds to seconds
                local progress=$((current_time * 100 / duration))
                printf "\rProcessing ID: %s, Video: %s [%d%%]" "$video_id" "$(basename "$input_file")" "$progress"
            fi
        done

    echo "" # New line after progress bar

    # Check ffmpeg exit status
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
tail -n +2 "$VIDEO_IDS_CSV" | while IFS=',' read -r video_id src; do
    log_debug "Processing video ID: $video_id, Source: $src"

    # Check if video ID is already processed
    if is_already_processed "$video_id"; then
        log_debug "Video ID $video_id already processed. Fetching details from CSV_LOG."

        # Extract details from CSV_LOG
        existing_entry=$(grep -m 1 -F "$video_id" "$CSV_LOG")
        if [[ -n "$existing_entry" ]]; then
            log_debug "Re-logged entry: $existing_entry"
        fi
        continue
    fi

    src_filename=$(basename "$src")
    input_file=$(find_video_file "$src_filename")
    output_file="$OUTPUT_DIR/$(basename "$input_file")"
    thumbnail_file="$THUMBNAIL_DIR/$(basename "${input_file%.*}").jpg"

    if [[ -z "$input_file" ]]; then
        log_debug "File not found for video ID: $video_id, Source: $src_filename. Ensure it exists in $INPUT_DIR."
        echo "Missing file for video ID: $video_id, Source: $src_filename" >> "$SKIPPED_LOG"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$src,,Skipped" >> "$CSV_LOG"
        continue
    fi

    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$input_file")
    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)

    is_portrait="false"
    if (( height > width )); then
        is_portrait="true"
    fi

    convert_video_file "$video_id" "$input_file" "$is_portrait" "$output_file" "$thumbnail_file"
done
