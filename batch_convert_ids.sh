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
