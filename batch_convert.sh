#!/bin/bash

# CSV files with video metadata
FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

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
if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: Required CSV file(s) not found."
    exit 1
fi

# Clear logs
> "$SKIPPED_LOG"
> "$COMPLETED_LOG"

# Function to normalize filenames (remove spaces, dashes, etc.)
normalize_filename() {
    echo "$1" | tr -d '[:space:]'
}

# Function to find thumbnail based on key
find_thumbnail() {
    local key="$1"
    awk -F',' -v key="$key" '{
        if ($1 ~ key) {
            gsub(/"/, "", $2); # Remove quotes
            print $2;
            exit;
        }
    }' "$VIDEO_SOURCES_CSV"
}

# Process videos
for INPUT_FILE in "$INPUT_DIR"/*.{mp4,mov,avi,mkv,wmv}; do
    # Check if the file exists (necessary for globbing)
    if [[ ! -f "$INPUT_FILE" ]]; then
        continue
    fi

    BASENAME=$(basename "$INPUT_FILE")
    NORMALIZED_BASENAME=$(normalize_filename "$BASENAME")

    echo "Processing file: $BASENAME"
    echo "Normalized BASENAME: $NORMALIZED_BASENAME"

    # Search for matching line in FILE_NAMES_CSV
    MATCHING_LINE=$(awk -F',' -v basename="$BASENAME" '
    {
        originalname = $5;
        gsub(/[[:space:]]*-+[[:space:]]*/, "-", originalname);
        gsub(/[[:space:]]*/, "", originalname);
        originalname = tolower(originalname);
        if (originalname == tolower(basename)) {
            print $0;
            exit;
        }
    }' "$FILE_NAMES_CSV")

    if [[ -n "$MATCHING_LINE" ]]; then
        ORIGINALNAME=$(echo "$MATCHING_LINE" | cut -d',' -f5 | tr -d '"' | xargs)
        NORMALIZED_ORIGINALNAME=$(normalize_filename "$ORIGINALNAME")

        echo "Original Name from CSV: $ORIGINALNAME"
        echo "Normalized ORIGINALNAME: $NORMALIZED_ORIGINALNAME"

        if [[ "$NORMALIZED_BASENAME" != "$NORMALIZED_ORIGINALNAME" ]]; then
            echo "Skipping $BASENAME: does not match originalname ($ORIGINALNAME) in CSV after normalization." | tee -a "$SKIPPED_LOG"
            continue
        fi

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

        # Find thumbnail path based on KEY
        THUMBNAIL_PATH=$(find_thumbnail "$KEY")
        THUMBNAIL_FILE="$THUMBNAIL_DIR/${KEY}.jpg"

        if [[ -n "$THUMBNAIL_PATH" ]]; then
            # Download thumbnail from source
            curl -s "$THUMBNAIL_PATH" --output "$THUMBNAIL_FILE" || {
                echo "Error downloading thumbnail for $BASENAME" | tee -a "$SKIPPED_LOG"
                continue
            }
            echo "Thumbnail downloaded for key $KEY from $THUMBNAIL_PATH" | tee -a "$COMPLETED_LOG"
        else
            # Create thumbnail from video
            ffmpeg -y -i "$INPUT_FILE" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$THUMBNAIL_FILE" || {
                echo "Error creating thumbnail for $BASENAME" | tee -a "$SKIPPED_LOG"
                continue
            }
            echo "Thumbnail created from video for $BASENAME at $THUMBNAIL_FILE" | tee -a "$COMPLETED_LOG"
        fi

        # Convert video
        ffmpeg -y -i "$INPUT_FILE" \
            -vf "scale=$WIDTH:$HEIGHT:force_original_aspect_ratio=decrease,pad=$WIDTH:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$OUTPUT_FILE" || {
            echo "Error processing video $BASENAME" | tee -a "$SKIPPED_LOG"
            continue
        }

        echo "Completed: $BASENAME" | tee -a "$COMPLETED_LOG"
        echo "Output video: $OUTPUT_FILE" >> "$COMPLETED_LOG"
    else
        echo "Skipping $BASENAME: not found in FILE_NAMES_CSV." | tee -a "$SKIPPED_LOG"
    fi
done

echo "Batch processing completed."
echo "Skipped files logged in '$SKIPPED_LOG'."
echo "Completed files logged in '$COMPLETED_LOG'."
