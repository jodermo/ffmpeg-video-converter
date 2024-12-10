#!/bin/bash

# CSV file with video metadata
VIDEO_NAMES_CSV="./existing_video_names/video_sources.csv"

# Input/Output directories
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
LANDSCAPE_WIDTH="1920"
LANDSCAPE_HEIGHT="1080"
QUALITY="30"        # CRF value (lower = higher quality, larger file size)
PRESET="slow"        # FFmpeg preset (slower = better compression)
AUDIO_BITRATE="128k" # Audio bitrate

# Thumbnail parameters
THUMBNAIL_TIME="00:00:04"
THUMBNAIL_QUALITY="2"  # Lower value = higher quality

# Create output and thumbnail directories if they don't exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$THUMBNAIL_DIR"

# Loop through all video files in the input directory
for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mov,avi,mkv,wmv}; do
    # Check if the file exists (necessary when using globbing)
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    # Extract the filename with extension from the local input file
    BASENAME=$(basename "$INPUT_FILE")

    # Remove spaces from the file name for matching
    BASENAME_NO_SPACES=$(echo "$BASENAME" | tr -d ' ')

    # Try matching with the CSV using both original and space-removed names
    MATCHING_LINE=$(grep -F "$BASENAME" "$VIDEO_NAMES_CSV" | head -n 1)
    if [[ -z "$MATCHING_LINE" ]]; then
        MATCHING_LINE=$(grep -F "$BASENAME_NO_SPACES" "$VIDEO_NAMES_CSV" | head -n 1)
    fi

    if [[ -n "$MATCHING_LINE" ]]; then
        echo "Processing $BASENAME..."

        # Extract "originalname" from the CSV
        ORIGINALNAME=$(echo "$MATCHING_LINE" | cut -d',' -f5 | tr -d '"')

        # Check if the current file name matches the "originalname" from the CSV
        if [[ "$BASENAME" != "$ORIGINALNAME" && "$BASENAME_NO_SPACES" != "$ORIGINALNAME" ]]; then
            echo "Skipping $BASENAME: does not match originalname ($ORIGINALNAME) in CSV."
            continue
        fi

        # Extract "portrait" field from the CSV (assuming it's a boolean-like value)
        IS_PORTRAIT=$(echo "$MATCHING_LINE" | cut -d',' -f20 | tr -d '"')

        # Extract the "key" field for naming output files
        KEY=$(echo "$MATCHING_LINE" | cut -d',' -f14 | tr -d '"')

        # Determine the scale parameters based on the portrait status
        if [[ "$IS_PORTRAIT" == "True" || "$IS_PORTRAIT" == "true" ]]; then
            WIDTH=$LANDSCAPE_HEIGHT
            HEIGHT=$LANDSCAPE_WIDTH
        else
            WIDTH=$LANDSCAPE_WIDTH
            HEIGHT=$LANDSCAPE_HEIGHT
        fi

        # Define output files using the key
        OUTPUT_FILE="$OUTPUT_DIR/${KEY}.mp4"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${KEY}.jpg"

        # Convert the video to the desired resolution with specified parameters
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE"

        # Extract a thumbnail at the specified time with defined quality
        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE"

        echo "Completed: $BASENAME"
        echo "Output video: $OUTPUT_FILE"
        echo "Thumbnail: $THUMBNAIL_FILE"
    else
        echo "Skipping $BASENAME as it is not found in the CSV."
    fi
done

echo "Batch conversion and thumbnail extraction completed for all matching videos."
echo "Optimized videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
