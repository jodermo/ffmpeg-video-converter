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

# Ensure directories exist
mkdir -p "$OUTPUT_DIR" "$THUMBNAIL_DIR" "$(dirname "$SKIPPED_LOG")"

# Check if required files exist
if [[ ! -f "$FILE_NAMES_CSV" ]] || [[ ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: Required CSV files not found."
    echo "FILE_NAMES_CSV: $FILE_NAMES_CSV"
    echo "VIDEO_SOURCES_CSV: $VIDEO_SOURCES_CSV"
    exit 1
fi

# Clear logs
> "$SKIPPED_LOG"
> "$COMPLETED_LOG"
> "$THUMBNAIL_LOG"

# Function to log command errors
log_error() {
    echo "Error executing: $1" | tee -a "$SKIPPED_LOG"
}

# Normalize filenames (remove spaces)
normalize_filename() {
    echo "$1" | tr -d '[:space:]'
}

# Process video sources
while IFS=',' read -r ID SRC THUMBNAIL FILEID; do
    if [[ "$ID" == "id" ]]; then continue; fi

    echo "Processing video source: ID=$ID, SRC=$SRC, FILEID=$FILEID" | tee -a "$SKIPPED_LOG"

    MATCHING_LINE=""
    if [[ "$FILEID" != "0" ]]; then
        MATCHING_LINE=$(grep -F ",$FILEID," "$FILE_NAMES_CSV" | head -n 1 2>>"$SKIPPED_LOG") || log_error "grep for FILEID=$FILEID in $FILE_NAMES_CSV"
    fi

    if [[ -z "$MATCHING_LINE" ]]; then
        echo "No direct match for FILEID=$FILEID. Searching for 'key' in 'src'..." | tee -a "$SKIPPED_LOG"
        while IFS=',' read -r FILE_ID USER_ID NAME FILENAME ORIGINALNAME MIMETYPE DESTINATION PATH SIZE CREATED THUMBNAIL LOCATION BUCKET KEY TYPE PROGRESSSTATUS VIEWS TOPIXID PORTRAIT; do
            if [[ "$SRC" == *"$KEY"* ]]; then
                MATCHING_LINE=$(echo "$FILE_ID,$USER_ID,$NAME,$FILENAME,$ORIGINALNAME,$MIMETYPE,$DESTINATION,$PATH,$SIZE,$CREATED,$THUMBNAIL,$LOCATION,$BUCKET,$KEY,$TYPE,$PROGRESSSTATUS,$VIEWS,$TOPIXID,$PORTRAIT")
                echo "Matched key '$KEY' in SRC='$SRC'." | tee -a "$SKIPPED_LOG"
                break
            fi
        done < <(tail -n +2 "$FILE_NAMES_CSV" 2>>"$SKIPPED_LOG") || log_error "tail on $FILE_NAMES_CSV"
    fi

    if [[ -z "$MATCHING_LINE" ]]; then
        echo "Skipping: No match for FILEID=$FILEID and no 'key' in 'src' for SRC=$SRC" | tee -a "$SKIPPED_LOG"
        continue
    fi

    ORIGINALNAME=$(echo "$MATCHING_LINE" | cut -d',' -f5 | tr -d '"' | xargs)
    KEY=$(echo "$MATCHING_LINE" | cut -d',' -f14 | tr -d '"' | xargs)

    INPUT_FILE="$INPUT_DIR/$ORIGINALNAME"
    if [[ ! -f "$INPUT_FILE" ]]; then
        echo "Skipping: Input file $ORIGINALNAME not found in $INPUT_DIR" | tee -a "$SKIPPED_LOG"
        continue
    fi

    THUMBNAIL_NAME=$(basename "$THUMBNAIL")
    if [[ -z "$THUMBNAIL_NAME" || "$THUMBNAIL_NAME" == "NULL" ]]; then
        THUMBNAIL_NAME="${KEY}.0000000.jpg"
    fi
    THUMBNAIL_FILE="$THUMBNAIL_DIR/$THUMBNAIL_NAME"

    OUTPUT_FILE="$OUTPUT_DIR/${KEY}.mp4"

    echo "Converting video: $INPUT_FILE to $OUTPUT_FILE" | tee -a "$COMPLETED_LOG"
    ffmpeg -y -i "$INPUT_FILE" \
        -vf "scale=1920:1080:force_original_aspect_ratio=decrease,pad=1920:1080:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset slow -crf 30 -c:a aac -b:a 128k -movflags +faststart "$OUTPUT_FILE" || {
        log_error "ffmpeg conversion for $INPUT_FILE"
        continue
    }

    echo "Generating thumbnail for $INPUT_FILE" | tee -a "$THUMBNAIL_LOG"
    ffmpeg -y -i "$INPUT_FILE" -ss 00:00:04 -vframes 1 -q:v 2 "$THUMBNAIL_FILE" || log_error "Thumbnail generation for $INPUT_FILE"

    echo "Completed: $ORIGINALNAME" | tee -a "$COMPLETED_LOG"
    echo "Output video: $OUTPUT_FILE" >> "$COMPLETED_LOG"
    echo "Thumbnail: $THUMBNAIL_FILE" >> "$COMPLETED_LOG"

done < "$VIDEO_SOURCES_CSV"
