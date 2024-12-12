#!/bin/bash

# Debug mode
DEBUG=1

# Debug log function
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "[DEBUG] $1"
    fi
}

# File Paths
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

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

# Ensure directories and log files exist
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
touch "$SKIPPED_LOG" "$SYSTEM_LOG" "$CSV_LOG"

log_debug "Directories and log files ensured: LOG_DIR=$LOG_DIR, OUTPUT_DIR=$OUTPUT_DIR, THUMBNAIL_DIR=$THUMBNAIL_DIR"

# Initialize CSV log if empty
if [[ ! -s "$CSV_LOG" ]]; then
    echo "Timestamp,Video ID,Source,Thumbnail,Status" > "$CSV_LOG"
fi

# Function to normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-zA-Z0-9._-]//g'
}

# Function to convert video and generate thumbnail
convert_video_file() {
    local video_id="$1"
    local input_file="$2"
    local output_file="$3"
    local thumbnail_file="$4"

    # Get video duration
    local duration
    duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
    duration=${duration%.*} # Convert to integer seconds

    if [[ -z "$duration" || "$duration" -le 0 ]]; then
        log_debug "Could not determine duration for $input_file. Skipping."
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Conversion Failed (No duration)" >> "$CSV_LOG"
        return 1
    fi

    # Convert video with FFmpeg and display progress
    echo "Converting video: $input_file"
    ffmpeg -y -i "$input_file" \
        -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
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

    # Check FFmpeg exit status
    if [[ $? -eq 0 ]]; then
        log_debug "Video converted successfully: $input_file -> $output_file"
    else
        log_debug "Video conversion failed for: $input_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Conversion Failed" >> "$CSV_LOG"
        echo "Conversion failed for $input_file" >> "$SKIPPED_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" \
        >> "$SYSTEM_LOG" 2>&1

    if [[ $? -eq 0 ]]; then
        log_debug "Thumbnail generated successfully: $thumbnail_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Success" >> "$CSV_LOG"
    else
        log_debug "Thumbnail generation failed for: $input_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Thumbnail Failed" >> "$CSV_LOG"
        echo "Thumbnail generation failed for $input_file" >> "$SKIPPED_LOG"
    fi
}


# Process each file in INPUT_DIR
for file_path in "$INPUT_DIR"/*; do
    if [[ -f "$file_path" ]]; then
        file_name=$(basename "$file_path")
        normalized_file_name=$(normalize_filename "$file_name")

        log_debug "Processing file: $file_name (Normalized: $normalized_file_name)"

        # Search for normalized name in CSV
        found_in_csv=false
        while IFS=',' read -r video_id src; do
            csv_normalized_name=$(normalize_filename "$(basename "$src")")
            if [[ "$normalized_file_name" == "$csv_normalized_name" ]]; then
                found_in_csv=true
                log_debug "Match found in CSV: $csv_normalized_name for Video ID: $video_id"

                output_file="$OUTPUT_DIR/${file_name%.*}.mp4"
                thumbnail_file="$THUMBNAIL_DIR/${file_name%.*}.jpg"

                convert_video_file "$video_id" "$file_path" "$output_file" "$thumbnail_file"
                break
            fi
        done < <(tail -n +2 "$VIDEO_IDS_CSV")

        if [[ "$found_in_csv" == false ]]; then
            log_debug "No match found in CSV for file: $file_name"
            echo "No match for $file_name" >> "$SKIPPED_LOG"
        fi
    fi
done
