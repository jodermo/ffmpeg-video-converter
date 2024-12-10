#!/bin/bash

VIDEO_NAMES_CSV="./existing_video_names/data-1733845421332.csv"

# Input/Output directories
INPUT_DIR="./input_videos_landscape"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
SCALE="1920:1080"
QUALITY="23"           # CRF value (lower = higher quality, larger file size)
PRESET="slow"          # FFmpeg preset (slower = better compression)
AUDIO_BITRATE="128k"   # Audio bitrate

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"  # Lower value = higher quality

# Create output and thumbnail directories if they don't exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$THUMBNAIL_DIR"

# Loop through all video files in the input directory
for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mov,avi,mkv,wmv}; do
    # Check if the file exists
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    # Extract the filename with extension from the local file
    BASENAME=$(basename "$INPUT_FILE")

    # Check if the CSV file contains the filename anywhere in its lines
    if MATCHING_LINE=$(grep -F "$BASENAME" "$VIDEO_NAMES_CSV"); then
        echo "Found $BASENAME in CSV. Processing..."

        # Extract the original filename from the URL in the CSV line
        ORIGINAL_FILENAME=$(basename "$MATCHING_LINE")   # e.g., "1714982806445_video_3408.mp4"
        ORIGINAL_BASENAME="${ORIGINAL_FILENAME%.*}"      # e.g., "1714982806445_video_3408"
        
        # Use the ORIGINAL_BASENAME for the output files
        OUTPUT_FILE="$OUTPUT_DIR/${ORIGINAL_BASENAME}_optimized.mp4"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${ORIGINAL_BASENAME}_thumbnail.jpg"

        # Convert the video to web-optimized portrait resolution with defined parameters
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$SCALE:force_original_aspect_ratio=decrease,pad=$SCALE:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE"

        # Extract a thumbnail at the specified time with defined quality
        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE"

        echo "Completed: $BASENAME (Original name: $ORIGINAL_FILENAME)"
    else
        echo "Skipping $BASENAME as it is not found in the CSV."
    fi
done

echo "Batch conversion and thumbnail extraction completed for all matching videos."
echo "Optimized portrait videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
