#!/bin/bash

# Input/Output directories
INPUT_DIR="./input_videos_portrait"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
SCALE="1080:1920"
# CRF value (lower = higher quality, larger file size)
QUALITY="30"
# FFmpeg preset (slower = better compression)
PRESET="slow"          
# Audio bitrate
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"  # Lower value = higher quality

# Create output and thumbnail directories if they don't exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$THUMBNAIL_DIR"

# Loop through all video files in the input directory
for INPUT_FILE in "$INPUT_DIR"/*; do
    # Extract the base filename without extension
    FILENAME=$(basename "$INPUT_FILE" | sed 's/\.[^.]*$//')

    # Set the output file paths
    OUTPUT_FILE="$OUTPUT_DIR/${FILENAME}_optimized.mp4"
    THUMBNAIL_FILE="$THUMBNAIL_DIR/${FILENAME}_thumbnail.jpg"

    # Display current processing status
    echo "Processing: $FILENAME"

    # Convert the video to web-optimized portrait resolution with defined parameters
    ffmpeg -y -i "$INPUT_FILE" -vf "scale=$SCALE:force_original_aspect_ratio=decrease,pad=$SCALE:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -preset "$PRESET" -crf "$QUALITY" -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE"

    # Extract a thumbnail at the specified time with defined quality
    ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE"

    # Log completion
    echo "Completed: $FILENAME"
done

echo "Batch conversion and thumbnail extraction completed."
echo "Optimized portrait videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
