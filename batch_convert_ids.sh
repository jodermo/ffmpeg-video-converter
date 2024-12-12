convert_video_file() {
    local video_id="$1"
    local input_file="$2"
    local is_portrait="$3"
    local output_file="$4"
    local thumbnail_file="$5"

    local scale=""
    if [[ "$is_portrait" == "true" ]]; then
        scale="${HEIGHT}:${WIDTH}"
    else
        scale="${WIDTH}:${HEIGHT}"
    fi

    # Get video duration
    local duration=$(ffprobe -v error -select_streams v:0 -show_entries format=duration \
        -of default=noprint_wrappers=1:nokey=1 "$input_file")
    duration=${duration%.*} # Convert to integer seconds

    # Run ffmpeg with progress tracking
    echo "Converting video: $input_file (ID: $video_id)"
    ffmpeg -y -i "$input_file" \
        -vf "scale=$scale:force_original_aspect_ratio=decrease,pad=$scale:(ow-iw)/2:(oh-ih)/2" \
        -c:v libx264 -preset "$PRESET" -crf "$QUALITY" \
        -c:a aac -b:a "$AUDIO_BITRATE" -movflags +faststart "$output_file" \
        -progress pipe:1 2>&1 | while IFS="=" read -r key value; do
            if [[ "$key" == "out_time_us" ]]; then
                local current_time=$(($value / 1000000)) # Convert microseconds to seconds
                local progress=$((current_time * 100 / duration))
                printf "\rProcessing ID: %s, Video: %s [%d%%]" "$video_id" "$(basename "$input_file")" "$progress"
            fi
        done

    echo "" # New line after progress bar

    # Check ffmpeg exit status
    if [[ $? -eq 0 ]]; then
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Success" >> "$CSV_LOG"
        echo "$(basename "$input_file")" >> "$COMPLETED_LOG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Failed" >> "$CSV_LOG"
        echo "Failed to convert video: $input_file" | tee -a "$SKIPPED_LOG"
        return 1
    fi

    # Generate thumbnail
    ffmpeg -y -i "$input_file" -ss "$THUMBNAIL_TIME" -vframes 1 -q:v "$THUMBNAIL_QUALITY" "$thumbnail_file" 2>>"$SYSTEM_LOG"

    if [[ $? -eq 0 ]]; then
        echo "[DEBUG] Thumbnail generated for video ID $video_id at $thumbnail_file" | tee -a "$SYSTEM_LOG"
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S"),$video_id,$input_file,$thumbnail_file,Thumbnail Failed" >> "$CSV_LOG"
        echo "Failed to generate thumbnail: $input_file" | tee -a "$SKIPPED_LOG"
    fi
}
