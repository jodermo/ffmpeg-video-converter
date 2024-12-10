#!/bin/bash

VIDEO_NAMES_CSV="./existing_video_names/video_sources.csv"

# Input/Output directories
INPUT_DIR="./input_videos_landscape"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
SCALE="1920:1080"
QUALITY="30"        # CRF value (lower = higher quality, larger file size)
PRESET="slow"        # FFmpeg preset (slower = better compression)
AUDIO_BITRATE="128k" # Audio bitrate

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
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

    # Find the matching CSV line that contains the local video filename
    MATCHING_LINE=$(grep -F "$BASENAME" "$VIDEO_NAMES_CSV" | head -n 1)

    # If not found, try URL-encoding the basename and search again
    if [[ -z "$MATCHING_LINE" ]]; then
        ENCODED_BASENAME=$(python3 -c "import urllib.parse; print(urllib.parse.quote('''$BASENAME'''))")
        MATCHING_LINE=$(grep -F "$ENCODED_BASENAME" "$VIDEO_NAMES_CSV" | head -n 1)
    fi

    # Determine the output filename
    if [[ -n "$MATCHING_LINE" ]]; then
        echo "Found $BASENAME in CSV. Processing..."

        # Extract the original filename from the src URL or fallback to input filename
        ORIGINAL_FILENAME=$(basename "$(echo "$MATCHING_LINE" | cut -d',' -f1 | tr -d '"')")
        ORIGINAL_BASENAME="${ORIGINAL_FILENAME%.*}"

        
    else
        echo "No match found for $BASENAME in CSV. Using input filename as fallback."
        ORIGINAL_BASENAME="${BASENAME%.*}"
    fi

   

done

echo "Batch conversion and thumbnail extraction completed for all videos."
echo "Optimized videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
