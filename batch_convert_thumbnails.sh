#!/bin/bash

# File Paths
COMBINED_CSV="./csv_data/combined.csv"
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
LOG_DIR="./logs"

SKIPPED_LOG="$LOG_DIR/skipped_files.log"
SYSTEM_LOG="$LOG_DIR/system.log"
CSV_LOG="$LOG_DIR/conversion_log.csv"
PROCESSED_LOG="$LOG_DIR/processed_videos.csv"
SUMMARY_LOG="$LOG_DIR/summary.log"

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

# Preload combined CSV into an associative array
preload_combined_csv() {
    declare -gA COMBINED_MAP

    while IFS=',' read -r video_id video_src video_fileId file_id file_originalname file_key file_path; do
        normalized_path=$(normalize_filename "$file_path")
        normalized_originalname=$(normalize_filename "$file_originalname")
        
        # Extract the last segment of video.src for fallback matching
        video_src_basename=$(normalize_filename "$(basename "$video_src")")

        # Log processed entries for debugging
        echo "DEBUG: Adding to COMBINED_MAP - Path: $file_path -> $normalized_path, Originalname: $file_originalname -> $normalized_originalname, VideoSrc: $video_src_basename" | tee -a "$SYSTEM_LOG"

        # Populate the map
        [[ -n "$normalized_path" ]] && COMBINED_MAP["$normalized_path"]="$video_id,$video_src,$file_id,$file_originalname,$file_key"
        [[ -n "$normalized_originalname" ]] && COMBINED_MAP["$normalized_originalname"]="$video_id,$video_src,$file_id,$file_originalname,$file_key"
        [[ -n "$video_src_basename" ]] && COMBINED_MAP["$video_src_basename"]="$video_id,$video_src,$file_id,$file_originalname,$file_key"
    done < <(tail -n +2 "$COMBINED_CSV")

    echo "Loaded ${#COMBINED_MAP[@]} entries from combined.csv." | tee -a "$SYSTEM_LOG"
}



# Process videos
process_videos() {
    # Initialize counters as integers
    local -i total=0
    local -i processed=0
    local -i skipped=0

    echo "DEBUG: Starting video processing..." | tee -a "$SYSTEM_LOG"

    find "$INPUT_DIR" -type f -name "*.mp4" -print0 | while IFS= read -r -d '' input_file; do
        ((total++)) # Increment total for each file found
        local filename=$(basename "$input_file")
        local normalized=$(normalize_filename "$filename")

        echo "DEBUG: Checking input file - Original: $filename, Normalized: $normalized" | tee -a "$SYSTEM_LOG"

        # Check for direct match in COMBINED_MAP
        local video_data=${COMBINED_MAP["$normalized"]}

        # If no match, fallback to match normalized `video.src` basename
        if [[ -z "$video_data" ]]; then
            echo "DEBUG: No direct match for $normalized. Attempting fallback to video.src..." | tee -a "$SYSTEM_LOG"
            for key in "${!COMBINED_MAP[@]}"; do
                if [[ "$key" == "$normalized" ]]; then
                    video_data=${COMBINED_MAP["$key"]}
                    echo "DEBUG: Match found via video.src fallback - Key: $key -> $video_data" | tee -a "$SYSTEM_LOG"
                    break
                fi
            done
        fi

        # Skip if no match is found
        if [[ -z "$video_data" ]]; then
            echo "Skipping: No match found for $filename (Normalized: $normalized)" | tee -a "$SYSTEM_LOG"
            echo "$filename" >> "$SKIPPED_LOG"
            ((skipped++))
            continue
        fi

        # Extract details and process the file
        IFS=',' read -r video_id video_src file_id file_originalname file_key <<< "$video_data"
        local thumbnail_file="$THUMBNAIL_DIR/${normalized}.jpg"

        echo "Generating thumbnail for: $filename" | tee -a "$SYSTEM_LOG"
        ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" > /dev/null 2>&1
        if [[ $? -eq 0 ]]; then
            echo "Thumbnail generated: $thumbnail_file" | tee -a "$SYSTEM_LOG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$video_src,Success" >> "$CSV_LOG"
            echo "$video_id,$thumbnail_file" >> "$PROCESSED_LOG"
            ((processed++))
        else
            echo "Thumbnail generation failed for: $filename" | tee -a "$SYSTEM_LOG"
            echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$video_src,Failed" >> "$CSV_LOG"
        fi
    done

    # Summary
    echo "Processing Summary:" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
    echo "Total videos found: $total" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
    echo "Processed successfully: $processed" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
    echo "Skipped: $skipped" | tee -a "$SYSTEM_LOG" "$SUMMARY_LOG"
}



# Main script
setup_environment
preload_combined_csv
process_videos
