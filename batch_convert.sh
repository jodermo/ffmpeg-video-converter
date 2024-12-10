#!/bin/bash

# CSV file with video metadata
FILE_NAMES_CSV="./csv_data/File.csv"

# Input/Output directories
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
SKIPPED_LOG="./skipped_files.log"

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
if [[ ! -f "$FILE_NAMES_CSV" ]]; then
    echo "Error: CSV file '$FILE_NAMES_CSV' not found."
    exit 1
fi

# Clear skipped files log
echo "" > "$SKIPPED_LOG"

# Process videos
for INPUT_FILE in "$INPUT_DIR"/*; do
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    BASENAME=$(basename "$INPUT_FILE")
    TRIMMED_BASENAME=$(echo "$BASENAME" | xargs)

    MATCHING_LINE=$(grep -F "$TRIMMED_BASENAME" "$FILE_NAMES_CSV" | head -n 1)
    if [[ -n "$MATCHING_LINE" ]]; then
        ORIGINALNAME=$(echo "$MATCHING_LINE" | cut -d',' -f5 | tr -d '"' | xargs)
        if [[ "$TRIMMED_BASENAME" != "$ORIGINALNAME" ]]; then
            echo "Skipping $BASENAME: does not match originalname ($ORIGINALNAME) in CSV." | tee -a "$SKIPPED_LOG"
            continue
        fi

        IS_PORTRAIT=$(echo "$MATCHING_LINE" | cut -d',' -f20 | tr -d '"')
        KEY=$(echo "$MATCHING_LINE" | cut -d',' -f14 | tr -d '"')

        if [[ "$IS_PORTRAIT" == "True" || "$IS_PORTRAIT" == "true" ]]; then
            WIDTH=$LANDSCAPE_HEIGHT
            HEIGHT=$LANDSCAPE_WIDTH
        else
            WIDTH=$LANDSCAPE_WIDTH
            HEIGHT=$LANDSCAPE_HEIGHT
        fi

        OUTPUT_FILE="$OUTPUT_DIR/${KEY}.mp4"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${KEY}.jpg"

        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE" || {
            echo "Error processing video $BASENAME" | tee -a "$SKIPPED_LOG"
            continue
        }

        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE" || {
            echo "Error creating thumbnail for $BASENAME" | tee -a "$SKIPPED_LOG"
            continue
        }

        echo "Completed: $BASENAME"
        echo "Output video: $OUTPUT_FILE"
        echo "Thumbnail: $THUMBNAIL_FILE"
    else
        echo "Skipping $BASENAME: not found in CSV." | tee -a "$SKIPPED_LOG"
    fi
done

echo "Batch processing completed. Logs available in '$SKIPPED_LOG'."
