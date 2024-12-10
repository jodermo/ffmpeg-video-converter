#!/bin/bash

# Function to sanitize and format file names
sanitize_filename() {
    local fileName="$1"
    # Get extension
    local extension="${fileName##*.}"
    # Get file name without extension
    fileName="${fileName%.*}"
    # Remove spaces and special characters
    fileName=$(echo "$fileName" | sed 's/[^a-zA-Z0-9_-]//g')
    # Return sanitized file name with extension
    echo "${fileName}.${extension}"
}

# Paths
VIDEO_NAMES_CSV="./existing_video_names/video_sources.csv"
INPUT_DIR="./input_videos_portrait"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
SCALE="1080:1920"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"

# Create directories if they do not exist
mkdir -p "$OUTPUT_DIR"
mkdir -p "$THUMBNAIL_DIR"

# Process each video in the input directory
for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mov,avi,mkv,wmv}; do
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    # Get the sanitized base name of the input file
    BASENAME=$(basename "$INPUT_FILE")
    SANITIZED_BASENAME=$(sanitize_filename "$BASENAME")

    # Search for the sanitized base name in the CSV
    MATCHING_LINE=$(grep -F "$SANITIZED_BASENAME" "$VIDEO_NAMES_CSV" | head -n 1)

    if [[ -n "$MATCHING_LINE" ]]; then
        echo "Found $SANITIZED_BASENAME in CSV. Processing..."

        # Extract the exact original filename from the CSV (from the first column)
        ORIGINAL_FILENAME=$(basename "$(echo "$MATCHING_LINE" | cut -d',' -f1 | tr -d '"')")

        # Prepare output file paths
        OUTPUT_FILE="$OUTPUT_DIR/$ORIGINAL_FILENAME"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${ORIGINAL_FILENAME%.*}.jpg"

        # Convert video to desired format and resolution
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$SCALE:force_original_aspect_ratio=decrease,pad=$SCALE:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE"

        # Extract thumbnail
        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE"

        echo "Completed: $SANITIZED_BASENAME"
        echo "Output Video: $OUTPUT_FILE"
        echo "Thumbnail: $THUMBNAIL_FILE"
    else
        echo "No match found for $SANITIZED_BASENAME in CSV. File not converted."
    fi
done

echo "Batch conversion and thumbnail extraction completed."
echo "Optimized videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
