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

# Normalize filenames (remove spaces)
normalize_filename() {
    echo "$1" | tr -d '[:space:]'
}

# Process video sources
while IFS=',' read -r ID SRC THUMBNAIL FILEID; do
    # Skip header
    if [[ "$ID" == "id" ]]; then continue; fi

    MATCHING_LINE=""
    if [[ "$FILEID" != "0" ]]; then
        # Match file entry using fileId
        MATCHING_LINE=$(grep -F ",$FILEID," "$FILE_NAMES_CSV" | head -n 1)
    fi

    if [[ -z "$MATCHING_LINE" ]]; then
        # If no match by fileId, check if "key" from FILE_NAMES_CSV is included in "src"
        while IFS=',' read -r FILE_ID USER_ID NAME FILENAME ORIGINALNAME MIMETYPE DESTINATION PATH SIZE CREATED THUMBNAIL LOCATION BUCKET KEY TYPE PROGRESSSTATUS VIEWS TOPIXID PORTRAIT; do
            if [[ "$SRC" == *"$KEY"* ]]; then
                MATCHING_LINE=$(echo "$FILE_ID,$USER_ID,$NAME,$FILENAME,$ORIGINALNAME,$MIMETYPE,$DESTINATION,$PATH,$SIZE,$CREATED,$THUMBNAIL,$LOCATION,$BUCKET,$KEY,$TYPE,$PROGRESSSTATUS,$VIEWS,$TOPIXID,$PORTRAIT")
                break
            fi
        done < <(tail -n +2 "$FILE_NAMES_CSV")
    fi

    if [[ -z "$MATCHING_LINE" ]]; then
        echo "Skipping: No matching entry for fileId $FILEID or 'key' in 'src'" | tee -a "$SKIPPED_LOG"
        continue
    fi

    ORIGINALNAME=$(echo "$MATCHING_LINE" | cut -d',' -f5 | tr -d '"' | xargs)
    NORMALIZED_ORIGINALNAME=$(normalize_filename "$ORIGINALNAME")
    KEY=$(echo "$MATCHING_LINE" | cut -d',' -f14 | tr -d '"' | xargs)

    INPUT_FILE="$INPUT_DIR/$ORIGINALNAME"
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Skipping: Input file $ORIGINALNAME not found in $INPUT_DIR" | tee -a "$SKIPPED_LOG"
        continue
    fi

    # Determine thumbnail name
    THUMBNAIL_NAME=$(basename "$THUMBNAIL")
    if [[ -z "$THUMBNAIL_NAME" || "$THUMBNAIL_NAME" == "NULL" ]]; then
        THUMBNAIL_NAME="${KEY}.0000000.jpg"
    fi
    THUMBNAIL_FILE="$THUMBNAIL_DIR/$THUMBNAIL_NAME"

    # Set resolution based on orientation
    IS_PORTRAIT=$(echo "$MATCHING_LINE" | cut -d',' -f20 | tr -d '"' | xargs)
    if [[ "$IS_PORTRAIT" == "True" || "$IS_PORTRAIT" == "true" ]]; then
        WIDTH=$LANDSCAPE_HEIGHT
        HEIGHT=$LANDSCAPE_WIDTH
    else
        WIDTH=$LANDSCAPE_WIDTH
        HEIGHT=$LANDSCAPE_HEIGHT
    fi

    OUTPUT_FILE="$OUTPUT_DIR/${KEY}.mp4"

    # Convert video
    ffmpeg -y -i "$INPUT_FILE" \
        -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE" || {
        echo "Error processing video $ORIGINALNAME" | tee -a "$SKIPPED_LOG"
        continue
    }

    # Extract thumbnail
    ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE" 2>&1 | tee -a "$THUMBNAIL_LOG"
    if [[ $? -ne 0 ]]; then
        echo "Error: Failed to create thumbnail for $ORIGINALNAME." | tee -a "$SKIPPED_LOG" "$THUMBNAIL_LOG"
        continue
    fi

    # Log success
    echo "Completed: $ORIGINALNAME" | tee -a "$COMPLETED_LOG"
    echo "Output video: $OUTPUT_FILE" >> "$COMPLETED_LOG"
    echo "Thumbnail: $THUMBNAIL_FILE" >> "$COMPLETED_LOG"

done < "$VIDEO_SOURCES_CSV"
