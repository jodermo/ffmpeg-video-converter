#!/bin/bash

VIDEO_NAMES_CSV="./existing_video_names/video_sources.csv"

# Input/Output directories
INPUT_DIR="./input_videos_portrait"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
SCALE="1080:1920"
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

    # Define output files
    OUTPUT_FILE="$OUTPUT_DIR/${ORIGINAL_BASENAME}.mp4"
    THUMBNAIL_FILE="$THUMBNAIL_DIR/${ORIGINAL_BASENAME}_thumbnail.jpg"

    # Convert the video to web-optimized resolution with defined parameters
    ffmpeg -y -i "$INPUT_FILE" \
        -vf "scale=$SCALE:force_original_aspect_ratio=decrease,pad=$SCALE:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE"

    # Extract a thumbnail at the specified time with defined quality
    ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE"

    echo "Completed: $BASENAME"
    echo "Output Video: $OUTPUT_FILE"
    echo "Thumbnail: $THUMBNAIL_FILE"

done

echo "Batch conversion and thumbnail extraction completed for all videos."
echo "Optimized videos are in the '$OUTPUT_DIR' directory."
echo "Thumbnails are in the '$THUMBNAIL_DIR' directory."
