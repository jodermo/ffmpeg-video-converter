#!/bin/bash

# Debug mode (set to 1 to enable debug logs, 0 to disable)
DEBUG=1

# Debug log function
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "[DEBUG] $1" | tee -a "$SYSTEM_LOG"
    fi
}

# File Paths
FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
COMPLETED_LOG="$LOG_DIR/completed_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/conversion_log.csv"
MAPPING_FILE="$LOG_DIR/conversion_mapping.log"

# Ensure directories exist
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"

log_debug "Directories ensured: LOG_DIR=$LOG_DIR, OUTPUT_DIR=$OUTPUT_DIR, THUMBNAIL_DIR=$THUMBNAIL_DIR"

# Video parameters
WIDTH="1280"
HEIGHT="720"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"

# Initialize CSV log
echo "Timestamp,Video ID,Original Name,AWS Key,Output File,Thumbnail File,Status" > "$CSV_LOG"

# Ensure CSV files exist
if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: CSV files are missing." | tee -a "$SKIPPED_LOG"
    log_debug "Missing CSV files: FILE_NAMES_CSV=$FILE_NAMES_CSV, VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"
    exit 1
fi

log_debug "CSV files validated: FILE_NAMES_CSV=$FILE_NAMES_CSV, VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"

# Function to check if a file has already been processed
is_already_processed() {
    local input_file="$1"

    # Check if input_file exists in the completed log
    if grep -qF "$input_file" "$COMPLETED_LOG"; then
        return 0 # File is processed
    fi

    return 1 # File is not processed
}



# Debug log file
DEBUG_LOG="./debug.log"

# Debug log function
log_debug() {
    echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1" >> "$DEBUG_LOG"
}

# Normalize file names (e.g., trim spaces, convert to lowercase)
normalize_name() {
    local filename="$1"
    log_debug "Original filename: $filename"

    # Decode URI-encoded characters (if any)
    filename=$(echo -e "$(echo "$filename" | sed 's/%/\\x/g')")
    log_debug "Decoded filename: $filename"

    # Normalize Unicode to NFC (combine decomposed characters into single codepoints)
    filename=$(printf "%s" "$filename" | iconv -f utf-8 -t utf-8 -c | python3 -c "import unicodedata, sys; print(unicodedata.normalize('NFC', sys.stdin.read()))")
    log_debug "Unicode normalized filename: $filename"

    # Remove all non-alphabetic and non-numeric characters
    filename=$(echo "$filename" | sed 's/[^a-zA-Z0-9]//g')
    log_debug "Alphanumeric-only filename: $filename"

    echo "$filename"
}

# Function to find a file in INPUT_DIR based on the normalized original name
find_file_by_originalname() {
    local originalname="$1"
    local normalized_original=$(normalize_name "$originalname")
    log_debug "Normalized original name: $normalized_original"

    # Loop through all files in INPUT_DIR
    find "$INPUT_DIR" -type f | while read -r file; do
        [[ "$(basename "$file")" == "README.md" ]] && continue

        # Normalize the current file's name
        local normalized_file=$(normalize_name "$(basename "$file")")
        log_debug "Normalized filename: $normalized_file (Original: $(basename "$file"))"

        # Compare normalized names
        if [[ "$normalized_original" == "$normalized_file" ]]; then
            log_debug "Match found: $file"
            echo "$file"
            return
        fi
    done

    log_debug "No match found for: $originalname"
    echo ""
}



# Function to convert video and generate thumbnail
convert_video_file() {
    local current_timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    local video_id="$1"
    local input_file="$2"
    local is_portrait="$3"
    local output_filename="$4"
    local thumbnail_filename="$5"
    local original_name="$6"
    local aws_key="$7"
    local output_file="$OUTPUT_DIR/${output_filename}.mp4"
    local thumbnail_file="$THUMBNAIL_DIR/${thumbnail_filename}.jpg"

    # Check mapping file for existing conversion
    local existing_output=$(grep -F "$input_file," "$MAPPING_FILE" | cut -d',' -f2)
    if [[ -n "$existing_output" && -f "$existing_output" ]]; then
        cp "$existing_output" "$output_file"
        echo "[$current_timestamp] Reused converted file: $output_file from $existing_output" | tee -a "$COMPLETED_LOG"
        echo "$current_timestamp,$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Reused" >> "$CSV_LOG"
        return 0
    fi

    # Determine scale based on orientation
    local scale=""
    if [[ "$is_portrait" == "true" ]]; then
        scale="${HEIGHT}:${WIDTH}"
    else
        scale="${WIDTH}:${HEIGHT}"
    fi

    # Get video duration for progress calculation
    local duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
    duration=${duration%.*} # Round to the nearest second

    # Convert video with progress
    echo "[$current_timestamp] Starting conversion for Video ID: $video_id, Input: $input_file, Output: $output_file"
    ffmpeg -y -i "$input_file" \
        -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:2 2>&1 | while read -r line; do
            if [[ "$line" == "out_time_ms="* ]]; then
                local current_time_ms=${line#out_time_ms=}
                local current_time=$((current_time_ms / 1000000))
                local progress=$((current_time * 100 / duration))
                printf "\r[%s] Compressing Video ID: %s, Output: %s [%3d%%]" \
                    "$current_timestamp" "$video_id" "$output_file" "$progress"
            fi
        done
    echo "" # New line after progress bar

    if [[ $? -eq 0 ]]; then
        echo "[$current_timestamp] Video converted successfully: $output_file, Video ID: $video_id" | tee -a "$COMPLETED_LOG"
        echo "$input_file,$output_file" >> "$MAPPING_FILE" # Save mapping
    else
        echo "[$current_timestamp] Failed to convert video: $input_file, Video ID: $video_id" | tee -a "$SKIPPED_LOG"
        echo "$current_timestamp,$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Failed Conversion" >> "$CSV_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" 2>>"$SYSTEM_LOG"

    if [[ $? -eq 0 ]]; then
        echo "[$current_timestamp] Thumbnail generated: $thumbnail_file, Video ID: $video_id" | tee -a "$COMPLETED_LOG"
        echo "$current_timestamp,$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Success" >> "$CSV_LOG"
    else
        echo "[$current_timestamp] Failed to generate thumbnail: $input_file, Video ID: $video_id" | tee -a "$SKIPPED_LOG"
        echo "$current_timestamp,$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Failed Thumbnail" >> "$CSV_LOG"
    fi
}

# Main loop to process video sources
while IFS=',' read -r video_id src thumbnail file_id; do
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Extract file names from src and thumbnail
    src_filename=$(basename "$src" | sed 's/^"//;s/"$//')
    thumbnail_filename=$(basename "$thumbnail" | sed 's/^"//;s/"$//')

    # Find the original name and AWS key in File.csv using file_id
    originalname=$(awk -F',' -v id="$file_id" 'BEGIN {OFS=","} $1 == id {print $5}' "$FILE_NAMES_CSV" | sed 's/^"//;s/"$//')
    aws_key=$(awk -F',' -v id="$file_id" 'BEGIN {OFS=","} $1 == id {print $14}' "$FILE_NAMES_CSV" | sed 's/^"//;s/"$//')

    if [[ -z "$originalname" ]]; then
        originalname=$(basename "$src")  # Extract the last component of the URL
        originalname="${originalname%.*}"  # Remove file extension
        [[ "$originalname" != *.mp4 ]] && originalname="${originalname}.mp4"
        echo "[$timestamp] Original name not found for File ID: $file_id, Video ID: $video_id, Name: $originalname" | tee -a "$SKIPPED_LOG"
        log_debug "[$timestamp] Original name not found for File ID: $file_id, Video ID: $video_id, Name: $originalname"
    fi

    # Search for the video file in INPUT_DIR
    video_file=$(find_file_by_originalname "$originalname")
    if [[ -z "$video_file" ]]; then
        echo "[$timestamp] Video file not found for Original Name: $originalname, Video ID: $video_id" | tee -a "$SKIPPED_LOG"
        continue
    fi

    # Check if the file is already processed
    if is_already_processed "$video_file"; then
        echo "[$timestamp] Skipping already processed file: $video_file" | tee -a "$SYSTEM_LOG"
        continue
    fi

    # Determine video orientation
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file" 2>>"$SYSTEM_LOG")
    if [[ -z "$resolution" ]]; then
        echo "[$timestamp] Unable to get resolution for file: $video_file, Video ID: $video_id" | tee -a "$SKIPPED_LOG"
        continue
    fi

    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)

    is_portrait="false"
    if (( height > width )); then
        is_portrait="true"
    fi

    # Convert video and generate thumbnail using extracted names
    convert_video_file "$video_id" "$video_file" "$is_portrait" "${src_filename%.*}" "${thumbnail_filename%.*}" "$originalname" "$aws_key"

done < "$VIDEO_SOURCES_CSV"
