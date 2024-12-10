#!/bin/bash

# CSV file with video metadata
FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

# Input/Output directories
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
SKIPPED_LOG="./logs/skipped_files.log"
COMPLETED_LOG="./logs/completed_files.log"
THUMBNAIL_LOG="./logs/generated_thumbnails.log"

# Video parameters
LANDSCAPE_WIDTH="1920"
LANDSCAPE_HEIGHT="1080"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:04"
THUMBNAIL_QUALITY="2"

# Ensure directories exist
mkdir -p "$OUTPUT_DIR" "$THUMBNAIL_DIR"

# Check if CSV exists
if [[ ! -f "$FILE_NAMES_CSV" ]] || [[ ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: Required CSV files not found."
    exit 1
fi

# Clear logs
> "$SKIPPED_LOG"
> "$COMPLETED_LOG"
> "$THUMBNAIL_LOG"

# Function to normalize filenames (remove spaces, dashes, etc.)
normalize_filename() {
    echo "$1" | tr -d '[:space:]'
}

# Function to extract thumbnail URL based on key from VIDEO_SOURCES_CSV
get_thumbnail_url() {
    local key=$1
    grep -F "$key" "$VIDEO_SOURCES_CSV" | cut -d',' -f2 | tr -d '"' | xargs
}

# Process videos
for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mov,avi,mkv,wmv}; do
    # Check if the file exists (necessary for globbing)
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    BASENAME=$(basename "$INPUT_FILE")
    NORMALIZED_BASENAME=$(normalize_filename "$BASENAME")

    MATCHING_LINE=$(grep -i -F "$BASENAME" "$FILE_NAMES_CSV" | head -n 1)

    if [[ -z "$MATCHING_LINE" ]]; then
        MATCHING_LINE=$(grep -i -F "$NORMALIZED_BASENAME" "$FILE_NAMES_CSV" | head -n 1)
    fi

    if [[ -n "$MATCHING_LINE" ]]; then
        ORIGINALNAME=$(echo "$MATCHING_LINE" | cut -d',' -f5 | tr -d '"' | xargs)
        NORMALIZED_ORIGINALNAME=$(normalize_filename "$ORIGINALNAME")

        if [[ "$NORMALIZED_BASENAME" != "$NORMALIZED_ORIGINALNAME" ]]; then
            echo "Skipping $BASENAME: does not match originalname ($NORMALIZED_ORIGINALNAME) in CSV after normalization." | tee -a "$SKIPPED_LOG"
            continue
        fi

        IS_PORTRAIT=$(echo "$MATCHING_LINE" | cut -d',' -f20 | tr -d '"' | xargs)
        KEY=$(echo "$MATCHING_LINE" | cut -d',' -f14 | tr -d '"' | xargs)

        # Remove `.mp4` from the key for thumbnail naming
        KEY_NO_EXT="${KEY%.mp4}"

        # Match thumbnail URL from VIDEO_SOURCES_CSV using the key
        THUMBNAIL_URL=$(get_thumbnail_url "$KEY")
        THUMBNAIL_NAME=$(basename "$THUMBNAIL_URL")

        if [[ -z "$THUMBNAIL_NAME" || "$THUMBNAIL_NAME" == "NULL" ]]; then
            THUMBNAIL_NAME="${KEY_NO_EXT}_default_thumbnail.jpg"
            echo "Warning: No valid thumbnail URL found for $BASENAME. Using default name: $THUMBNAIL_NAME" | tee -a "$THUMBNAIL_LOG"
        fi

        # Set resolution based on orientation
        if [[ "$IS_PORTRAIT" == "True" || "$IS_PORTRAIT" == "true" ]]; then
            WIDTH=$LANDSCAPE_HEIGHT
            HEIGHT=$LANDSCAPE_WIDTH
        else
            WIDTH=$LANDSCAPE_WIDTH
            HEIGHT=$LANDSCAPE_HEIGHT
        fi

        OUTPUT_FILE="$OUTPUT_DIR/${KEY_NO_EXT}.mp4"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${THUMBNAIL_NAME}"

        # Convert video
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE" || {
            echo "Error processing video $BASENAME" | tee -a "$SKIPPED_LOG"
            continue
        }

        # Extract thumbnail
        echo "Generating thumbnail for $BASENAME..." | tee -a "$THUMBNAIL_LOG"
        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE" 2>&1 | tee -a "$THUMBNAIL_LOG"

        if [[ $? -ne 0 ]]; then
            echo "Error: Failed to create thumbnail for $BASENAME." | tee -a "$SKIPPED_LOG" "$THUMBNAIL_LOG"
            continue
        fi

        # Log success
        echo "Completed: $BASENAME" | tee -a "$COMPLETED_LOG"
        echo "Output video: $OUTPUT_FILE" >> "$COMPLETED_LOG"
        echo "Thumbnail: $THUMBNAIL_FILE" >> "$COMPLETED_LOG"
    else
        echo "Skipping $BASENAME: not found in CSV even after normalization." | tee -a "$SKIPPED_LOG"
    fi
done
