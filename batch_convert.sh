#!/bin/bash

# CSV file with video metadata
FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

# Input/Output directories
INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"
SKIPPED_LOG="./logs/skipped_files.log"
COMPLETED_LOG="./logs/completed_files.log"
THUMBNAIL_LOG="./logs/generated_thumbnails.log"

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
mkdir -p "$OUTPUT_DIR" "$THUMBNAIL_DIR" "$(dirname "$SKIPPED_LOG")"

# Check if CSV exists
if [[ ! -f "$FILE_NAMES_CSV" ]] || [[ ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: Required CSV files not found."
    exit 1
fi

# Clear logs
> "$SKIPPED_LOG"
> "$COMPLETED_LOG"
> "$THUMBNAIL_LOG"

# Normalize filenames (remove spaces)
normalize_filename() {
    echo "$1" | tr -d '[:space:]'
}

# Process each row in VIDEO_SOURCES_CSV
while IFS=',' read -r id src thumbnail fileId; do
    echo "Processing Video ID: $id"
    echo "Source: $src"
    echo "Thumbnail: $thumbnail"
    echo "File ID: $fileId"
    
    match_found=false

    # Find matching file in FILE_NAMES_CSV
    while IFS=',' read -r fid userId name filename originalname mimetype destination path size created filethumbnail location bucket key type progressStatus views topixId portrait; do
        if [[ "$fileId" == "$fid" ]]; then
            echo "Match found for File ID: $fileId"
            echo "Original Name: $originalname"
            echo "--------------------------"

            match_found=true

            # Process the video file here if needed
            # Add further processing code for each match
            
            break
        fi
    done < "$FILE_NAMES_CSV"

    if [[ "$match_found" == false ]]; then
        echo "No match found for File ID: $fileId" >> "$SKIPPED_LOG"
    fi

done < "$VIDEO_SOURCES_CSV"

echo "Processing complete. Check logs for details."
