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

# Function to check for a matching video file
get_video_file() {
    local file_id="$1"
    local src="$2"
    local match_found=false

    while IFS=',' read -r file_id_row userId name filename originalname mimetype destination path size created file_thumbnail location bucket key type progressStatus views topixId portrait; do
        if [[ "$file_id_row" == "id" ]]; then
            continue
        fi

        file_id_row=$(echo "$file_id_row" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')

        if [[ "$file_id" == "$file_id_row" ]]; then
            echo "Match Found for File ID: $file_id" | tee -a "$COMPLETED_LOG"
            echo "Source: $src" | tee -a "$COMPLETED_LOG"
            match_found=true
            break
        fi
    done < <(cat "$FILE_NAMES_CSV")

    if [[ "$match_found" == false ]]; then
        echo "No match found for File ID: $file_id in Source: $src" | tee -a "$SKIPPED_LOG"
    fi
}

# Function to convert video and generate thumbnail
convert_video_file() {
    local input_file="$1"
    local is_portrait="$2"
    local output_file="$OUTPUT_DIR/$(basename "${input_file%.*}").mp4"
    local thumbnail_file="$THUMBNAIL_DIR/$(basename "${input_file%.*}").jpg"

    # Determine scale based on orientation
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
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        2>> "$COMPLETED_LOG"

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
    echo "Processing Video ID: $video_id, File ID: $file_id" | tee -a "$COMPLETED_LOG"

    get_video_file "$file_id" "$src"

    video_file=$(find "$INPUT_DIR" -name "*$file_id*" -type f | head -n 1)
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

        # Extract file name from thumbnail URL
        thumbnail_file=$(basename "$thumbnail")
        echo "Extracted Thumbnail File: $thumbnail_file" | tee -a "$COMPLETED_LOG"

        convert_video_file "$video_file" "$is_portrait"
    else
        echo "Video file not found for File ID: $file_id" | tee -a "$SKIPPED_LOG"
    fi
done < <(cat "$VIDEO_SOURCES_CSV")
