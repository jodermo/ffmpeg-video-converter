#!/bin/bash

# Load configuration from config.env
if [[ -f "config.env" ]]; then
    source "config.env"
else
    echo "Error: config.env file not found."
    exit 1
fi

# Debug log function
log_debug() {
    if [[ "$DEBUG" -eq 1 ]]; then
        echo "$(date '+%Y-%m-%d %H:%M:%S') [DEBUG] $1" | tee -a "$SYSTEM_LOG"
    fi
}

# Error log function
log_error() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [ERROR] $1" | tee -a "$SYSTEM_LOG" "$SKIPPED_LOG"
}

# Retry function
retry_command() {
    local retries=$MAX_RETRIES
    local count=0
    until "$@"; do
        ((count++))
        if ((count == retries)); then
            log_error "Command failed after $retries attempts: $*"
            return 1
        fi
        log_debug "Retrying command: $*"
        sleep "$RETRY_DELAY"
    done
    return 0
}

# Ensure required directories exist
mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
log_debug "Directories ensured: LOG_DIR=$LOG_DIR, OUTPUT_DIR=$OUTPUT_DIR, THUMBNAIL_DIR=$THUMBNAIL_DIR"

# Ensure mapping file exists
touch "$MAPPING_FILE"

# Validate required commands
for cmd in ffmpeg ffprobe awk; do
    if ! command -v $cmd &> /dev/null; then
        log_error "$cmd is not installed. Exiting."
        exit 1
    fi
done
log_debug "Required commands are available."

# Initialize CSV log
echo "Timestamp,Video ID,Original Name,AWS Key,Output File,Thumbnail File,Status" > "$CSV_LOG"

# Ensure input CSV files exist
if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    log_error "CSV files are missing: FILE_NAMES_CSV=$FILE_NAMES_CSV, VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"
    exit 1
fi

# Function to find a file by name
find_file_by_originalname() {
    local originalname=$(echo "$1" | sed 's/^"//;s/"$//;s/\r//')

    # Debugging for a specific file
    if [[ "$originalname" == "HDI_EMPLOYEE_2021_Azubi_Christian_220413_1.mp4" ]]; then
        log_debug "Searching for sanitized file name: $originalname"
        log_debug "Files available in $INPUT_DIR:"
        find "$INPUT_DIR" -type f -print | tee -a "$SYSTEM_LOG"
    fi

    # Search for the file in the input directory
    local matched_file=$(find "$INPUT_DIR" -type f -iname "$originalname" -print -quit)

    # Log error if the file is not found
    if [[ -z "$matched_file" && "$originalname" == "HDI_EMPLOYEE_2021_Azubi_Christian_220413_1.mp4" ]]; then
        log_error "File not found for: $originalname"
    fi

    # Return the matched file path or empty string if not found
    echo "$matched_file"
}



# Function to convert video and generate thumbnail
convert_video_file() {
    local video_id="$1"
    local input_file="$2"
    local is_portrait="$3"
    local output_filename="$4"
    local thumbnail_filename="$5"
    local original_name="$6"
    local aws_key="$7"

    local output_file="$OUTPUT_DIR/${output_filename}.mp4"
    local thumbnail_file="$THUMBNAIL_DIR/${thumbnail_filename}.jpg"

    # Check if the file has already been converted
    local existing_output=$(grep -F "$input_file," "$MAPPING_FILE" | cut -d',' -f2)
    if [[ -n "$existing_output" && -f "$existing_output" ]]; then
        cp "$existing_output" "$output_file"
        log_debug "Reused converted file: $output_file from $existing_output"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Reused" >> "$CSV_LOG"
    else
        # Determine scale
        local scale=""
        if [[ "$is_portrait" == "true" ]]; then
            scale="${HEIGHT}:${WIDTH}"
        else
            scale="${WIDTH}:${HEIGHT}"
        fi

        # Get video duration
        local duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$input_file" 2>>"$SYSTEM_LOG")
        duration=${duration%.*} # Round to nearest second

        if [[ -z "$duration" || "$duration" -eq 0 ]]; then
            log_error "Invalid duration for video: $input_file"
            echo "$(date '+%Y-%m-%d %H:%M:%S'),$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Failed Duration" >> "$CSV_LOG"
            return 1
        fi

        # Convert the video and show progress
        ffmpeg -y -i "$input_file" \
            -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
            -progress pipe:2 2>&1 | while read -r line; do
                if [[ "$line" == "out_time_ms="* ]]; then
                    local current_time_ms=${line#out_time_ms=}
                    local current_time=$((current_time_ms / 1000000))
                    local progress=$((current_time * 100 / duration))
                    printf "\rCompressing: [%3d%%] Output: %s, Video ID: %s" "$progress" "$output_file" "$video_id"
                fi
            done
        echo "" # New line after progress bar

        if [[ $? -ne 0 ]]; then
            log_error "Failed to convert video: $input_file"
            echo "$(date '+%Y-%m-%d %H:%M:%S'),$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Failed Conversion" >> "$CSV_LOG"
            return 1
        fi

        # Save mapping
        echo "$input_file,$output_file" >> "$MAPPING_FILE"
        log_debug "Video converted successfully: $output_file"
    fi

    # Generate a new thumbnail
    retry_command ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" 2>>"$SYSTEM_LOG"

    if [[ $? -ne 0 ]]; then
        log_error "Failed to generate thumbnail: $input_file"
        echo "$(date '+%Y-%m-%d %H:%M:%S'),$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Failed Thumbnail" >> "$CSV_LOG"
        return 1
    fi

    log_debug "Thumbnail generated: $thumbnail_file"
    echo "$(date '+%Y-%m-%d %H:%M:%S'),$video_id,$original_name,$aws_key,$output_file,$thumbnail_file,Success" >> "$CSV_LOG"
}


# Main processing loop
while IFS=',' read -r video_id src thumbnail file_id; do
    [[ "$video_id" == "id" ]] && continue

    # Parse filenames
    src_filename=$(basename "$src" | sed 's/^"//;s/"$//')
    thumbnail_filename=$(basename "$thumbnail" | sed 's/^"//;s/"$//')

    # Lookup original name and AWS key
    originalname=$(awk -F',' -v id="$file_id" '$1 == id {print $5}' "$FILE_NAMES_CSV" | sed 's/^"//;s/"$//')
    aws_key=$(awk -F',' -v id="$file_id" '$1 == id {print $14}' "$FILE_NAMES_CSV" | sed 's/^"//;s/"$//')

    if [[ -z "$originalname" ]]; then
        log_error "Original name not found for File ID: $file_id"
        continue
    fi

    # Locate video file
    video_file=$(find_file_by_originalname "$originalname")
    if [[ -z "$video_file" ]]; then
        log_error "Video file not found: $originalname"
        continue
    fi

    # Check resolution and orientation
    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0 "$video_file" 2>>"$SYSTEM_LOG")
    [[ -z "$resolution" ]] && log_error "Failed to get resolution for: $video_file" && continue

    width=$(echo "$resolution" | cut -d',' -f1)
    height=$(echo "$resolution" | cut -d',' -f2)
    is_portrait="false"
    [[ $height -gt $width ]] && is_portrait="true"

    # Convert and generate thumbnail
    convert_video_file "$video_id" "$video_file" "$is_portrait" "${src_filename%.*}" "${thumbnail_filename%.*}" "$originalname" "$aws_key"
done < <(tail -n +2 "$VIDEO_SOURCES_CSV")

log_debug "Processing completed for VIDEO_SOURCES_CSV=$VIDEO_SOURCES_CSV"
