#!/usr/bin/env bash

# Exit immediately if a command exits with a non-zero status
set -e

# Optional: Enable debug mode for troubleshooting
# set -x

# Root directory containing temp/online
ROOT_DIR="temp/online"

# Directories (use ROOT_DIR)
VIDEO_DIR="$ROOT_DIR/output_videos"
THUMB_DIR="$ROOT_DIR/thumbnails"
LOG_DIR="./logs"

# Ensure the log directory exists
mkdir -p "$LOG_DIR"

# Log files
LOG_FILE="$LOG_DIR/missing_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/report.csv"

# Thumbnail generation settings
DEFAULT_THUMBNAIL_TIME="00:00:01"      # Default time to capture thumbnail if video is too short
THUMBNAIL_QUALITY="2"                  # Quality scale (1-31, lower is better)

# Initialize CSV log with headers if it doesn't exist
if [ ! -f "$CSV_LOG" ]; then
    echo "Timestamp,Video_ID,Input_File,Thumbnail_File,Status" > "$CSV_LOG"
fi

# Helper function for debug logging
log_debug() {
    local message="$1"
    echo "$(date "+%Y-%m-%d %H:%M:%S") [DEBUG] $message" | tee -a "$SYSTEM_LOG"
}

# Function to get video duration in seconds using ffprobe
get_video_duration() {
    local video_file="$1"
    ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video_file"
}

# Clear the missing files log at the start of the run
> "$LOG_FILE"

echo "Checking for videos without thumbnails..." | tee -a "$LOG_FILE"

# Enable nullglob to handle no matches gracefully
shopt -s nullglob

# Iterate through each .mp4 video in VIDEO_DIR
for video in "$VIDEO_DIR"/*.mp4; do
    # Extract basename without .mp4
    base=$(basename "$video" .mp4)
    # Define corresponding thumbnail filename
    thumbnail_file="$THUMB_DIR/$base.jpg"
    # Define input file and video ID for logging
    input_file="$video"
    video_id="$base"

    # Check if thumbnail does not exist
    if [ ! -f "$thumbnail_file" ]; then
        echo "No thumbnail found for video: $video" | tee -a "$LOG_FILE"

        # Get video duration using ffprobe
        duration=$(get_video_duration "$input_file")
        duration=${duration%.*}  # Convert to integer by removing decimal part

        # Validate duration retrieval
        if [ -z "$duration" ] || ! [[ "$duration" =~ ^[0-9]+$ ]]; then
            log_debug "Failed to retrieve duration for: $input_file"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Duration Retrieval Failed" >> "$CSV_LOG"
            continue
        fi

        # Determine thumbnail extraction time
        if [ "$duration" -ge 5 ]; then
            thumbnail_time="00:00:05"
        elif [ "$duration" -ge 1 ]; then
            # Extract at half the duration using Bash arithmetic
            half_duration=$(( duration / 2 ))
            thumbnail_time=$(printf "00:00:%02d" "$half_duration")
        else
            # If video is less than 1 second, set to default thumbnail time
            thumbnail_time="$DEFAULT_THUMBNAIL_TIME"
        fi

        log_debug "Video duration for '$input_file' is $duration seconds. Setting thumbnail time to $thumbnail_time."

        # Generate thumbnail using ffmpeg
        ffmpeg -y -i "$input_file" -ss "$thumbnail_time" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" >> "$SYSTEM_LOG" 2>&1

        # Check if ffmpeg command was successful and thumbnail was created
        if [ -f "$thumbnail_file" ]; then
            log_debug "Thumbnail generation successful: $thumbnail_file"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Success" >> "$CSV_LOG"
        else
            log_debug "Thumbnail generation failed for: $input_file"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Thumbnail Failed" >> "$CSV_LOG"
        fi
    fi
done

echo | tee -a "$LOG_FILE"
echo "Checking for thumbnails without corresponding videos..." | tee -a "$LOG_FILE"

# Iterate through each .jpg thumbnail in THUMB_DIR
for thumbnail in "$THUMB_DIR"/*.jpg; do
    # Extract basename without .jpg
    base=$(basename "$thumbnail" .jpg)
    # Define corresponding video filename
    video="$VIDEO_DIR/$base.mp4"

    # Check if video does not exist
    if [ ! -f "$video" ]; then
        echo "No video found for thumbnail: $thumbnail" | tee -a "$LOG_FILE"
    fi
done

echo "Check complete. Results stored in $LOG_FILE, $SYSTEM_LOG, and $CSV_LOG." | tee -a "$LOG_FILE"
