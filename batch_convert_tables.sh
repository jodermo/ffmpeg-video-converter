#!/bin/bash

# File Paths
FILES_CSV="./csv_data/files.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"
INPUT_DIR="./input_videos"
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

# Initialize directories and logs
setup_environment() {
    mkdir -p "$LOG_DIR" "$OUTPUT_DIR" "$THUMBNAIL_DIR"
    touch "$SKIPPED_LOG" "$SYSTEM_LOG"
    [[ ! -s "$CSV_LOG" ]] && echo "Timestamp,Video ID,Source,Status" > "$CSV_LOG"
    [[ ! -s "$PROCESSED_LOG" ]] && echo "id,src,thumbnail" > "$PROCESSED_LOG"
    echo "Environment initialized: Directories and logs are set up." | tee -a "$SYSTEM_LOG"
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


# Preload video_sources.csv into an associative array
preload_video_sources() {
    declare -gA VIDEO_MAP
    while IFS=',' read -r id src name; do
        csv_basename=$(normalize_filename "$(basename "$src")")
        VIDEO_MAP["$csv_basename"]="$id,$src,$name"
    done < <(tail -n +2 "$VIDEO_SOURCES_CSV")
    echo "Loaded $((${#VIDEO_MAP[@]})) entries from video_sources.csv." | tee -a "$SYSTEM_LOG"
}

# Process videos
process_videos() {
    local total=0 processed=0 skipped=0

    for input_file in "$INPUT_DIR"/*.mp4; do
        ((total++))
        local filename=$(basename "$input_file")
        local normalized=$(normalize_filename "$filename")
        local video_data=${VIDEO_MAP["$normalized"]}
        local url_friendly_name=$(create_url_friendly_name "$normalized")

        if [[ -z "$video_data" ]]; then
            echo "Skipping: No match found in CSV for $filename" | tee -a "$SYSTEM_LOG"
            echo "$filename" >> "$SKIPPED_LOG"
            ((skipped++))
            continue
        fi

        IFS=',' read -r video_id video_src video_name <<< "$video_data"
        local output_file="$OUTPUT_DIR/${url_friendly_name}.mp4"
        local thumbnail_file="$THUMBNAIL_DIR/${url_friendly_name}.jpg"

        echo "Processing: $video_src | ID: $video_id | Name: $video_name" | tee -a "$SYSTEM_LOG"

        # Convert video
        echo "Converting video: $filename" | tee -a "$SYSTEM_LOG"
        total_duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
            -of default=noprint_wrappers=1:nokey=1 "$input_file" | awk '{printf "%.0f\n", $1}')

        ffmpeg -y -i "$input_file" \
            -vf "scale=${WIDTH}:${HEIGHT}:force_original_aspect_ratio=decrease,pad=${WIDTH}:${HEIGHT}:(ow-iw)/2:(oh-ih)/2" \
            -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
            -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
            -progress pipe:1 2>&1 | while IFS="=" read -r key value; do
                if [[ "$key" == "out_time_us" ]]; then
                    local current_time=$((value / 1000000))
                    local progress=$((current_time * 100 / total_duration))
                    printf "\rProcessing ID: %s, Video: %s [%d%%]" "$video_id" "$(basename "$input_file")" "$progress"
                fi
            done

        echo "" # Print a newline after progress

        if [[ $? -eq 0 ]]; then
            echo "Conversion succeeded: $output_file" | tee -a "$SYSTEM_LOG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$video_src,Success" >> "$CSV_LOG"
            echo "$video_id,$output_file,$thumbnail_file" >> "$PROCESSED_LOG"
            ((processed++))
        else
            echo "Conversion failed: $filename" | tee -a "$SYSTEM_LOG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$video_src,Failed" >> "$CSV_LOG"
            continue
        fi

        # Generate thumbnail
        echo "Generating thumbnail for: $filename" | tee -a "$SYSTEM_LOG"
        ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "Thumbnail generated: $thumbnail_file" | tee -a "$SYSTEM_LOG"
        else
            echo "Thumbnail generation failed for: $filename" | tee -a "$SYSTEM_LOG"
        fi

        echo ""
    done

    # Summary
    echo "Processing Summary:" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
    echo "Total videos found: $total" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
    echo "Processed successfully: $processed" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
    echo "Skipped: $skipped" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
}


# Main script
setup_environment
preload_video_sources
process_videos
