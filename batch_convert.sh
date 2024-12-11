#!/bin/bash

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

# Video parameters
WIDTH="1920"
HEIGHT="1080"
QUALITY="30"        # CRF value (lower = higher quality, larger file size)
PRESET="slow"        # FFmpeg preset (slower = better compression)
AUDIO_BITRATE="128k" # Audio bitrate

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"  # Lower value = higher quality

# Ensure CSV files exist
if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: CSV files are missing." | tee -a "$SKIPPED_LOG"
    exit 1
fi

# Function to convert video and generate thumbnail
convert_video_file() {
    local input_file="$1"
    local output_file="$2"
    local thumbnail_file="$3"
    local is_portrait="$4"

    # Check if output already exists
    if [[ -f "$output_file" ]]; then
        echo "Video already converted: $output_file" | tee -a "$COMPLETED_LOG"
        return 0
    fi

    mkdir -p "$OUTPUT_DIR" "$THUMBNAIL_DIR"

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

    if [[ -z "$duration" || "$duration" -eq 0 ]]; then
        echo "Failed to get duration for $input_file. Skipping..." | tee -a "$SKIPPED_LOG"
        return 1
    fi

    # Convert video with progress bar
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
    echo ""

    if [[ $? -eq 0 ]]; then
        echo "Video converted successfully: $output_file" | tee -a "$COMPLETED_LOG"
    else
        echo "Failed to convert video: $input_file" | tee -a "$SKIPPED_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" \
        2>> "$THUMBNAIL_LOG"

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

    file_id=$(echo "$file_id" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    key=$(basename "$(dirname "$src")")
    thumbnail_name=$(basename "$thumbnail" 2>/dev/null || echo "${file_id}_fallback.jpg")

    echo "Processing Video ID: $video_id, File ID: $file_id" | tee -a "$COMPLETED_LOG"

    # Locate video file
    video_file=$(find "$INPUT_DIR" -type f -name "*${file_id}*" -o -name "*${key}*" | head -n 1)
    if [[ -n "$video_file" ]]; then
        # Determine video orientation
        resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file")
        width=$(echo "$resolution" | cut -d',' -f1)
        height=$(echo "$resolution" | cut -d',' -f2)

        if (( height > width )); then
            is_portrait="true"
        else
            is_portrait="false"
        fi

        # Define output file paths
        output_file="$OUTPUT_DIR/${key}.mp4"
        thumbnail_file="$THUMBNAIL_DIR/${thumbnail_name}"

        convert_video_file "$video_file" "$output_file" "$thumbnail_file" "$is_portrait"
    else
        echo "Video file not found for File ID: $file_id or Key: $key" | tee -a "$SKIPPED_LOG"
    fi
done < <(cat "$VIDEO_SOURCES_CSV")
