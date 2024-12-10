#!/bin/bash

# CSV file with video metadata
FILE_NAMES_CSV="./csv_data/File.csv"

# Input/Output directories
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
SKIPPED_LOG="./skipped_files.log"
COMPLETED_LOG="./completed_files.log"

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

# Clear logs
> "$SKIPPED_LOG"
> "$COMPLETED_LOG"

# Function to normalize filenames (remove spaces, dashes, underscores, etc.)
normalize_filename() {
    echo "$1" | tr -d ' ' | tr -d '-' | tr -d '_'
}

# Process videos
for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mov,avi,mkv,wmv}; do
    # Check if the file exists (necessary for globbing)
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    BASENAME=$(basename "$INPUT_FILE")
    NORMALIZED_BASENAME=$(normalize_filename "$BASENAME")

    MATCHING_LINE=""

    # Iterate through the CSV to perform fuzzy matching
    while IFS=',' read -r id userId name filename originalname mimetype destination path size created thumbnail location bucket key type progressStatus views topixId portrait; do
        # Normalize the `originalname` column
        NORMALIZED_ORIGINALNAME=$(normalize_filename "$originalname")
        if [[ "$NORMALIZED_BASENAME" == "$NORMALIZED_ORIGINALNAME" ]]; then
            MATCHING_LINE="$id,$userId,$name,$filename,$originalname,$mimetype,$destination,$path,$size,$created,$thumbnail,$location,$bucket,$key,$type,$progressStatus,$views,$topixId,$portrait"
            break
        fi
    done < <(tail -n +2 "$FILE_NAMES_CSV") # Skip the header row

    if [[ -n "$MATCHING_LINE" ]]; then
        # Extract relevant fields from the matching line
        IS_PORTRAIT=$(echo "$MATCHING_LINE" | cut -d',' -f20 | tr -d '"' | xargs)
        KEY=$(echo "$MATCHING_LINE" | cut -d',' -f14 | tr -d '"' | xargs)

        # Set resolution based on orientation
        if [[ "$IS_PORTRAIT" == "True" || "$IS_PORTRAIT" == "true" ]]; then
            WIDTH=$LANDSCAPE_HEIGHT
            HEIGHT=$LANDSCAPE_WIDTH
        else
            WIDTH=$LANDSCAPE_WIDTH
            HEIGHT=$LANDSCAPE_HEIGHT
        fi

        OUTPUT_FILE="$OUTPUT_DIR/${KEY}.mp4"
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${KEY}.jpg"

        # Convert video
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE" || {
            echo "Error processing video $BASENAME" | tee -a "$SKIPPED_LOG"
            continue
        }

        # Extract thumbnail
        ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE" || {
            echo "Error creating thumbnail for $BASENAME" | tee -a "$SKIPPED_LOG"
            continue
        }

        echo "Completed: $BASENAME" | tee -a "$COMPLETED_LOG"
        echo "Output video: $OUTPUT_FILE" >> "$COMPLETED_LOG"
        echo "Thumbnail: $THUMBNAIL_FILE" >> "$COMPLETED_LOG"
    else
        echo "Skipping $BASENAME: not found in CSV after normalization." | tee -a "$SKIPPED_LOG"
    fi
done

echo "Batch processing completed."
echo "Skipped files logged in '$SKIPPED_LOG'."
echo "Completed files logged in '$COMPLETED_LOG'."
