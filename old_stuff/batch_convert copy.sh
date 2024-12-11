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
FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
COMPLETED_LOG="$LOG_DIR/completed_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"

log_debug "Directories ensured: LOG_DIR=$LOG_DIR, OUTPUT_DIR=$OUTPUT_DIR, THUMBNAIL_DIR=$THUMBNAIL_DIR"

# Video parameters
WIDTH="1920"
HEIGHT="1080"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"

# Ensure CSV files exist
if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: CSV files are missing." | tee -a "$SKIPPED_LOG"
    log_debug "Missing CSV files: FILE_NAMES_CSV=$FILE_NAMES_CSV, VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"
    exit 1
fi

log_debug "CSV files validated: FILE_NAMES_CSV=$FILE_NAMES_CSV, VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"

# Function to find file in INPUT_DIR based on originalname
find_file_by_originalname() {
    local originalname="$1"
    local matched_file=$(find "$INPUT_DIR" -type f -name "$originalname" -print -quit)
    echo "$matched_file"
}

# Function to convert video and generate thumbnail
convert_video_file() {
    local input_file="$1"
    local is_portrait="$2"
    local output_filename="$3"
    local thumbnail_filename="$4"
    local output_file="$OUTPUT_DIR/${output_filename}.mp4"
    local thumbnail_file="$THUMBNAIL_DIR/${thumbnail_filename}.jpg"

    # Determine scale based on orientation
    local scale=""
    if [[ "$is_portrait" == "true" ]]; then
        scale="${HEIGHT}:${WIDTH}"
    else
        scale="${WIDTH}:${HEIGHT}"
    fi

    # Total duration of the input video
    local duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>>"$SYSTEM_LOG")
    duration=${duration%.*} # Round to nearest second

    # Convert video with progress
    ffmpeg -y -i "$input_file" \
        -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:2 2>&1 | while read -r line; do
            if [[ "$line" == "out_time_ms="* ]]; then
                current_time_ms=${line#out_time_ms=}
                current_time=$((current_time_ms / 1000000))
                progress=$((current_time * 100 / duration))
                printf "\rCompressing: [%3d%%] Output: %s" "$progress" "$output_file"
            fi
        done
    echo "" # New line after progress bar

    if [[ $? -eq 0 ]]; then
        echo "Video converted successfully: $output_file" | tee -a "$COMPLETED_LOG"
    else
        echo "Failed to convert video: $input_file" | tee -a "$SKIPPED_LOG"
        log_debug "Conversion failed for $input_file"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" 2>>"$SYSTEM_LOG"

    if [[ $? -eq 0 ]]; then
        echo "Thumbnail generated: $thumbnail_file" | tee -a "$COMPLETED_LOG"
    else
        echo "Failed to generate thumbnail: $input_file" | tee -a "$SKIPPED_LOG"
        log_debug "Thumbnail generation failed for $input_file"
    fi
}

# Main loop to process video sources
while IFS=',' read -r video_id src thumbnail file_id; do
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    # Extract file names from src and thumbnail
    src_filename=$(basename "$src" | sed 's/^"//;s/"$//')
    thumbnail_filename=$(basename "$thumbnail" | sed 's/^"//;s/"$//')

    # Find the original name in File.csv using file_id
    originalname=$(awk -F',' -v id="$file_id" 'BEGIN {OFS=","} $1 == id {print $5}' "$FILE_NAMES_CSV" | sed 's/^"//;s/"$//')
    
    if [[ -z "$originalname" ]]; then
        echo "Original name not found for File ID: $file_id" | tee -a "$SKIPPED_LOG"
        continue
    fi

    # Search for the video file in INPUT_DIR
    video_file=$(find_file_by_originalname "$originalname")

    if [[ -z "$video_file" ]]; then
        echo "Video file not found for Original Name: $originalname" | tee -a "$SKIPPED_LOG"
        continue
    fi

    # Determine video orientation
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file" 2>>"$SYSTEM_LOG")
    if [[ -z "$resolution" ]]; then
        echo "Unable to get resolution for file: $video_file" | tee -a "$SKIPPED_LOG"
        log_debug "Failed to get resolution for $video_file"
        continue
    fi

    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)

    is_portrait="false"
    if (( height > width )); then
        is_portrait="true"
    fi

    # Convert video and generate thumbnail using extracted names
    convert_video_file "$video_file" "$is_portrait" "${src_filename%.*}" "${thumbnail_filename%.*}"
done < "$VIDEO_SOURCES_CSV"

log_debug "Processing completed for VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"
