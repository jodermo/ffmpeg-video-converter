#!/bin/bash

# Debug mode
DEBUG=1

# File Paths
VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
INPUT_DIR="./video_input"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/conversion_log.csv"
PROCESSED_LOG="$LOG_DIR/processed_videos.csv"
SUMMARY_LOG="$LOG_DIR/summary.log"

# Video parameters
WIDTH="1280"
HEIGHT="720"
QUALITY="30"
PRESET="slow"
AUDIO_BITRATE="128k"

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"

# Headers
CSV_HEADER="Timestamp,Video ID,Source,Thumbnail,Status"
PROCESSED_HEADER="id,src,thumbnail"

# Debug log function
log_debug() {
    [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] $1"
}

# Ensure directories and logs exist
setup_environment() {
    mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
    touch "$SKIPPED_LOG" "$SYSTEM_LOG"
    [[ ! -s "$CSV_LOG" ]] && echo "$CSV_HEADER" > "$CSV_LOG"
    [[ ! -s "$PROCESSED_LOG" ]] && echo "$PROCESSED_HEADER" > "$PROCESSED_LOG"
    log_debug "Environment setup complete: Directories and logs ensured."
}

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' \
        | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]//g'
}

# Create URL-friendly names
create_url_friendly_name() {
    local base_name="$1"
    echo "$base_name" | sed -E 's/[^a-zA-Z0-9]/_/g' | tr '[:upper:]' '[:lower:]'
}

# Check if video is already converted
is_video_already_converted() {
    [[ -f "$1" ]]
}

# Get video duration in seconds
get_video_duration() {
    ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$1" | awk '{printf "%.0f\n", $1}'
}

# Function to detect if a video is portrait
is_portrait_video() {
    local input_file="$1"
    local resolution width height

    resolution=$(ffprobe -v error -select_streams v:0 -show_entries stream=width,height -of csv=p=0:s=x "$input_file")
    width=$(echo "$resolution" | cut -d'x' -f1)
    height=$(echo "$resolution" | cut -d'x' -f2)

    if (( height > width )); then
        echo "true"
    else
        echo "false"
    fi
}

# Convert video and generate thumbnail
convert_video_file() {
    local video_id="$1" input_file="$2" output_file="$3" thumbnail_file="$4"

    # Check if the output video file already exists
    if is_video_already_converted "$output_file"; then
        log_debug "Video already converted: $output_file. Skipping conversion."
        echo "$video_id,$output_file,$thumbnail_file" >> "$PROCESSED_LOG"
        return 0
    fi

    local is_portrait
    is_portrait=$(is_portrait_video "$input_file")

    # Adjust width and height for portrait videos
    local scale_width="$WIDTH" scale_height="$HEIGHT"
    if [[ "$is_portrait" == "true" ]]; then
        scale_width="$HEIGHT"
        scale_height="$WIDTH"
        log_debug "Portrait video detected. Adjusted dimensions: ${scale_width}x${scale_height}"
    fi

    # Get video duration
    local duration
    duration=$(get_video_duration "$input_file")
    if [[ -z "$duration" || "$duration" -le 0 ]]; then
        log_debug "Invalid duration for $input_file. Skipping."
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Conversion Failed (Invalid duration)" >> "$CSV_LOG"
        return 1
    fi

    # Convert video with FFmpeg and display progress
    echo "Converting video: $input_file"
    ffmpeg -y -i "$input_file" \
        -vf "scale=${scale_width}:${scale_height}:force_original_aspect_ratio=decrease,pad=${scale_width}:${scale_height}:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:1 2>&1 | while IFS="=" read -r key value; do
            if [[ "$key" == "out_time_us" ]]; then
                local current_time=$((value / 1000000))
                local progress=$((current_time * 100 / duration))
                printf "\rProcessing ID: %s, Video: %s [%d%%]" "$video_id" "$(basename "$input_file")" "$progress"
            fi
        done

    echo "" # New line after progress bar

    # Check FFmpeg exit status
    if [[ $? -eq 0 ]]; then
        log_debug "Video conversion successful: $output_file"
        echo "$video_id,$output_file,$thumbnail_file" >> "$PROCESSED_LOG"
    else
        log_debug "Video conversion failed: $input_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Conversion Failed" >> "$CSV_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" >> "$SYSTEM_LOG" 2>&1
    if [[ $? -eq 0 ]]; then
        log_debug "Thumbnail generation successful: $thumbnail_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Success" >> "$CSV_LOG"
    else
        log_debug "Thumbnail generation failed: $input_file"
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,,Thumbnail Failed" >> "$CSV_LOG"
    fi
}

# Process each video
process_videos() {
    local total_files current_file=0
    total_files=$(find "$INPUT_DIR" -type f | wc -l)

    local processed_count=0
    local skipped_count=0
    local failed_count=0

    for file_path in "$INPUT_DIR"/*; do
        [[ -f "$file_path" ]] || continue
        ((current_file++))

        local file_name normalized_file_name url_friendly_name
        file_name=$(basename "$file_path")
        normalized_file_name=$(normalize_filename "$file_name")
        url_friendly_name=$(create_url_friendly_name "$normalized_file_name")

        log_debug "Processing $video_id, file: $file_name (Normalized: $normalized_file_name, URL-friendly: $url_friendly_name) [$current_file/$total_files]"

        local found_in_csv=false
        while IFS=',' read -r video_id src; do
            local csv_normalized_name
            csv_normalized_name=$(normalize_filename "$(basename "$src")")
            if [[ "$normalized_file_name" == "$csv_normalized_name" ]]; then
                found_in_csv=true
                log_debug "Match found in CSV: $csv_normalized_name for Video ID: $video_id"

                local output_file thumbnail_file
                output_file="$OUTPUT_DIR/${url_friendly_name}.mp4"
                thumbnail_file="$THUMBNAIL_DIR/${url_friendly_name}.jpg"

                echo "[INFO] Processing video $video_id $current_file/$total_files: $file_name"
                if convert_video_file "$video_id" "$file_path" "$output_file" "$thumbnail_file"; then
                    ((processed_count++))
                else
                    ((failed_count++))
                fi
                break
            fi
        done < <(tail -n +2 "$VIDEO_IDS_CSV")

        if [[ "$found_in_csv" == false ]]; then
            log_debug "No match found in CSV for file: $file_name [$current_file/$total_files]"
            echo "No match for $video_id $file_name" >> "$SKIPPED_LOG"
            ((skipped_count++))
        fi
    done

    # Generate summary
    echo "" > "$SUMMARY_LOG"
    echo "Processing Summary:" >> "$SUMMARY_LOG"
    echo "Total Videos Processed: $total_files" >> "$SUMMARY_LOG"
    echo "Successfully Converted: $processed_count" >> "$SUMMARY_LOG"
    echo "Skipped: $skipped_count" >> "$SUMMARY_LOG"
    echo "Failed: $failed_count" >> "$SUMMARY_LOG"

    echo "\nProcessing Summary:"
    cat "$SUMMARY_LOG"
}

# Main script
setup_environment
process_videos
