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
QUALITY="30"        # CRF value (lower = higher quality)
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

# Function to find matching file.key for a given file_id in File.csv
get_file_key_from_csv() {
    local file_id="$1"
    local file_key=""
    while IFS=',' read -r f_id userId name filename originalname mimetype destination path size created file_thumbnail location bucket key type progressStatus views topixId portrait; do
        # Strip quotes
        f_id=$(echo "$f_id" | sed 's/^"//;s/"$//')
        key=$(echo "$key" | sed 's/^"//;s/"$//')

        if [[ "$f_id" == "$file_id" ]]; then
            file_key="$key"
            break
        fi
    done < <(tail -n +2 "$FILE_NAMES_CSV") # skip header

    echo "$file_key"
}

# Function to convert video and generate thumbnail
# Arguments:
# 1: input video path
# 2: is_portrait ("true" or "false")
# 3: output base name for video (without extension)
# 4: output filename for thumbnail (already has .jpg extension)
convert_video_file() {
    local input_file="$1"
    local is_portrait="$2"
    local output_basename="$3"
    local thumbnail_basename="$4"

    local output_file="$OUTPUT_DIR/$output_basename.mp4"
    local thumbnail_file="$THUMBNAIL_DIR/$thumbnail_basename"

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

    # Convert video
    ffmpeg -y -i "$input_file" \
        -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:2 2>&1 | while read -r line; do
            if [[ "$line" == "out_time_ms="* ]]; then
                current_time_ms=${line#out_time_ms=}
                current_time=$((current_time_ms / 1000000))
                if [[ $duration -gt 0 ]]; then
                    progress=$((current_time * 100 / duration))
                    printf "\rConverting: [%-50s] %d%%" "$(printf "%0.s#" $(seq 1 $((progress / 2))))" "$progress"
                fi
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
    # Skip header
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    # Clean and strip quotes
    video_id=$(echo "$video_id" | sed 's/^"//;s/"$//')
    file_id=$(echo "$file_id" | sed 's/^"//;s/"$//')
    src=$(echo "$src" | sed 's/^"//;s/"$//')
    thumbnail=$(echo "$thumbnail" | sed 's/^"//;s/"$//')

    echo "Processing Video ID: $video_id, File ID: $file_id" | tee -a "$COMPLETED_LOG"

    # Get the file.key from File.csv for the given file_id
    file_key=$(get_file_key_from_csv "$file_id")

    if [[ -z "$file_key" ]]; then
        echo "No match found for File ID: $file_id in File.csv" | tee -a "$SKIPPED_LOG"
        continue
    else
        echo "Matched file.key for File ID $file_id: $file_key" | tee -a "$COMPLETED_LOG"
    fi

    # Find the local input video file
    video_file=$(find "$INPUT_DIR" -type f -name "*$file_id*" | head -n 1)
    if [[ -z "$video_file" ]]; then
        echo "Video file not found for File ID: $file_id" | tee -a "$SKIPPED_LOG"
        continue
    fi

    # Determine video orientation
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file")
    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)

    if (( height > width )); then
        is_portrait="true"
    else
        is_portrait="false"
    fi

    # Determine the thumbnail output filename
    # If thumbnail is empty or NULL, fallback to using file_key as jpg
    if [[ -z "$thumbnail" || "$thumbnail" == "NULL" ]]; then
        thumbnail_basename="${file_key}.jpg"
    else
        # Extract the filename from the thumbnail URL
        thumbnail_filename=$(basename "$thumbnail")
        # If for some reason no extension is found, add .jpg as fallback
        if [[ "$thumbnail_filename" != *.* ]]; then
            thumbnail_filename="${thumbnail_filename}.jpg"
        fi
        thumbnail_basename="$thumbnail_filename"
    fi

    echo "Using thumbnail basename: $thumbnail_basename" | tee -a "$COMPLETED_LOG"

    # Convert video using file.key as output filename base
    convert_video_file "$video_file" "$is_portrait" "$file_key" "$thumbnail_basename"
done < <(tail -n +2 "$VIDEO_SOURCES_CSV") # Skip header line
