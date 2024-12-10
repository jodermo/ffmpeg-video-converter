#!/bin/bash

# Function to sanitize and format file names
sanitize_filename() {
    local fileName="$1"
    # Get extension
    local extension="${fileName##*.}"
    # Get file name without extension
    fileName="${fileName%.*}"
    # Remove spaces
    fileName="${fileName// /_}"
    # Remove special characters except hyphens and underscores
    fileName=$(echo "$fileName" | sed 's/[^a-zA-Z0-9_-]//g')
    # Return sanitized file name with extension
    echo "${fileName}.${extension}"
}

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

    # Sanitize the filename
    SANITIZED_BASENAME=$(sanitize_filename "$BASENAME")

    # Find the matching CSV line that contains the video filename
    MATCHING_LINE=$(grep -F "$SANITIZED_BASENAME" "$VIDEO_NAMES_CSV" | head -n 1)

    if [[ -n "$MATCHING_LINE" ]]; then
        echo "Found $SANITIZED_BASENAME in CSV. Processing..."

        # Extract the thumbnail filename from the CSV (second field)
        THUMBNAIL_URL=$(echo "$MATCHING_LINE" | cut -d',' -f2 | tr -d '"')
        THUMBNAIL_FILENAME=$(basename "$THUMBNAIL_URL")

        # Define the base name for output files
        OUTPUT_BASENAME="${THUMBNAIL_FILENAME%.*}"

        # Define output files
        OUTPUT_FILE="$OUTPUT_DIR/${OUTPUT_BASENAME}.mp4"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${OUTPUT_BASENAME}.jpg"

        # Convert the video to web-optimized resolution with defined parameters
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$SCALE:force_original_aspect_ratio=decrease,pad=$SCALE:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE" || echo "FFmpeg video conversion failed for $INPUT_FILE"

        # Extract a thumbnail at the specified time with defined quality
        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE" || echo "FFmpeg thumbnail extraction failed for $INPUT_FILE"

        echo "Completed: $SANITIZED_BASENAME"
        echo "Output Video: $OUTPUT_FILE"
        echo "Thumbnail: $THUMBNAIL_FILE"

    else
        echo "No match found for $SANITIZED_BASENAME in CSV. File not converted."
    fi
done

echo "Batch conversion and thumbnail extraction completed for all videos."
echo "Optimized videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
