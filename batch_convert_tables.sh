#!/bin/bash

# Debug mode (set to 1 to enable debug logs, 0 to disable)
DEBUG=1

# File Paths
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
COMPLETED_LOG="$LOG_DIR/completed_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
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

# Log functions
log_debug() { [[ "$DEBUG" -eq 1 ]] && echo "[DEBUG] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$SYSTEM_LOG"; }
log_info() { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$SYSTEM_LOG"; }
log_error() { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $1" | tee -a "$SYSTEM_LOG"; }


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

# Preload CSV data into an associative array for faster lookups
preload_csv_data() {
    declare -gA VIDEO_MAP
    while IFS=',' read -r video_id src thumbnail file_id; do
        csv_basename=$(normalize_filename "$(basename "$src")")
        VIDEO_MAP["$csv_basename"]="$video_id,$src,$thumbnail"
    done < <(tail -n +2 "$VIDEO_SOURCES_CSV")

    log_debug "Preloaded ${#VIDEO_MAP[@]} video entries from CSV."
}

# Check if a video is portrait
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
convert_video() {
    local video_id="$1" input_file="$2" output_file="$3" thumbnail_file="$4"
    local duration current_time progress

    # Check if output file already exists
    if [[ -f "$output_file" ]]; then
        log_info "Video already converted: $output_file"
        echo "$video_id,$output_file,$thumbnail_file" >> "$COMPLETED_LOG"
        return 0
    fi

    # Determine video duration
    duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file" | awk '{printf "%.0f\n", $1}')
    if [[ -z "$duration" || "$duration" -le 0 ]]; then
        log_error "Invalid duration for file: $input_file. Skipping."
        return 1
    fi

    log_info "Converting video: $input_file (Duration: ${duration}s)"

    # Convert video using FFmpeg with progress tracking
    ffmpeg -y -i "$input_file" \
        -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:1 2>&1 | while IFS="=" read -r key value; do
            if [[ "$key" == "out_time_us" ]]; then
                current_time=$((value / 1000000))
                progress=$((current_time * 100 / duration))
                printf "\r[CONVERTING] %s [%d%%]" "$(basename "$input_file")" "$progress"
            fi
        done
    echo ""

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" >> "$SYSTEM_LOG" 2>&1
    log_info "Thumbnail generated: $thumbnail_file"
}

# Process all videos in the input directory
process_videos() {
    local total_files processed_count=0 skipped_count=0 failed_count=0
    total_files=$(find "$INPUT_DIR" -type f -name "*.mp4" | wc -l)

    for input_file in "$INPUT_DIR"/*.mp4; do
        [[ -f "$input_file" ]] || continue

        local file_name normalized_file_name url_friendly_name video_data output_file thumbnail_file
        file_name=$(basename "$input_file")
        normalized_file_name=$(normalize_filename "$file_name")
        url_friendly_name=$(create_url_friendly_name "$normalized_file_name")

        log_debug "Processing file: $file_name (Normalized: $url_friendly_name)"

        video_data=${VIDEO_MAP["$normalized_file_name"]}
        if [[ -z "$video_data" ]]; then
            log_error "No CSV match for file: $file_name"
            echo "Skipped: $file_name" >> "$SKIPPED_LOG"
            ((skipped_count++))
            continue
        fi

        IFS=',' read -r video_id src thumbnail <<< "$video_data"
        output_file="$OUTPUT_DIR/${url_friendly_name}.mp4"
        thumbnail_file="$THUMBNAIL_DIR/${url_friendly_name}.jpg"

        if convert_video "$video_id" "$input_file" "$output_file" "$thumbnail_file"; then
            ((processed_count++))
        else
            ((failed_count++))
        fi
    done

    # Generate summary
    echo "Processing Summary:" > "$SUMMARY_LOG"
    echo "Total Videos Found: $total_files" >> "$SUMMARY_LOG"
    echo "Processed: $processed_count" >> "$SUMMARY_LOG"
    echo "Skipped: $skipped_count" >> "$SUMMARY_LOG"
    echo "Failed: $failed_count" >> "$SUMMARY_LOG"
    cat "$SUMMARY_LOG"
}

# Main Execution
log_info "Starting batch video processing..."
preload_csv_data
process_videos
log_info "Batch processing completed."
