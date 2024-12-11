#!/bin/bash

# Debug mode (set to 1 to enable debug logs, 0 to disable)
DEBUG=1

# Debug log function
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "[DEBUG] $1" | tee -a "$LOG_DIR/debug.log"
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
THUMBNAIL_LOG="$LOG_DIR/generated_thumbnails.log"

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

# Log files in INPUT_DIR for debugging
log_debug "Files in INPUT_DIR:"
ls -1 "$INPUT_DIR" | while read -r file; do
    log_debug "  - $file"
done

# Function to convert video and generate thumbnail
convert_video_file() {
    local input_file="$1"
    local is_portrait="$2"
    local base_name="$3"
    local output_file="$OUTPUT_DIR/${base_name}.mp4"
    local thumbnail_file="$THUMBNAIL_DIR/${base_name}.jpg"

    # Determine scale based on orientation
    local scale=""
    if [[ "$is_portrait" == "true" ]]; then
        scale="${HEIGHT}:${WIDTH}"
    else
        scale="${WIDTH}:${HEIGHT}"
    fi

    # Total duration of the input video
    local duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
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
                printf "\rConverting: [%-50s] %d%%" "$(printf "%0.s#" $(seq 1 $((progress / 2))))" "$progress"
            fi
        done
    echo "" # New line after progress bar

    if [[ $? -eq 0 ]]; then
        echo "Video converted successfully: $output_file" | tee -a "$COMPLETED_LOG"
    else
        echo "Failed to convert video: $input_file" | tee -a "$SKIPPED_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" 2>>"$THUMBNAIL_LOG"

    if [[ $? -eq 0 ]]; then
        echo "Thumbnail generated: $thumbnail_file" | tee -a "$THUMBNAIL_LOG"
    else
        echo "Failed to generate thumbnail: $input_file" | tee -a "$SKIPPED_LOG"
    fi
}

# Main loop to process video sources
while IFS=',' read -r video_id src thumbnail file_id; do
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    # Clean up inputs
    file_id=$(echo "$file_id" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    src=$(echo "$src" | sed 's/^"//;s/"$//')
    thumbnail=$(echo "$thumbnail" | sed 's/^"//;s/"$//')

    # Extract names
    thumbnail_name=$(basename "$thumbnail")
    video_name=$(basename "$src")

    log_debug "Processing Video ID=$video_id, File ID=$file_id, Thumbnail Name=$thumbnail_name, Video Name=$video_name"

    # Determine output base name
    base_name=""
    if [[ -n "$thumbnail_name" ]]; then
        base_name="${thumbnail_name%.*}"
    elif [[ -n "$video_name" ]]; then
        base_name="${video_name%.*}"
    else
        base_name="$file_id"
    fi

    echo "Processing Video ID: $video_id, File ID: $file_id, Base Name: $base_name" | tee -a "$COMPLETED_LOG"
    log_debug "Base name determined: $base_name"

    # Search for video file in the input directory
    video_file=$(find "$INPUT_DIR" -type f -name "*$file_id*" -print -quit)

    # Fallback to video_name if file_id fails
    if [[ -z "$video_file" && -n "$video_name" ]]; then
        log_debug "Fallback to video_name matching: $video_name"
        video_file=$(find "$INPUT_DIR" -type f -name "*$video_name*" -print -quit)
    fi

    # Fallback to thumbnail_name if video_name fails
    if [[ -z "$video_file" && -n "$thumbnail_name" ]]; then
        log_debug "Fallback to thumbnail_name matching: $thumbnail_name"
        video_file=$(find "$INPUT_DIR" -type f -name "*$thumbnail_name*" -print -quit)
    fi

    if [[ -z "$video_file" ]]; then
        echo "Video file not found for File ID: $file_id" | tee -a "$SKIPPED_LOG"
        log_debug "No matching video file found for File ID=$file_id in INPUT_DIR=$INPUT_DIR"
        continue
    fi

    log_debug "Video file found: $video_file"

    # Determine orientation
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file" 2>/dev/null)
    if [[ -z "$resolution" ]]; then
        echo "Unable to get resolution for file: $video_file" | tee -a "$SKIPPED_LOG"
        log_debug "Failed to get resolution for file: $video_file"
        continue
    fi

    log_debug "Resolution obtained: $resolution"

    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)

    is_portrait="false"
    if (( height > width )); then
        is_portrait="true"
    fi

    log_debug "Video orientation determined: is_portrait=$is_portrait"

    # Convert video and generate thumbnail
    convert_video_file "$video_file" "$is_portrait" "$base_name"
done < "$VIDEO_SOURCES_CSV"

log_debug "Processing completed for VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"
