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
mkdir -p "$OUTPUT_DIR" "$THUMBNAIL_DIR"

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


# Read and separate values for each row
while IFS=',' read -r id src thumbnail fileId; do
  echo "ID: $id"
  echo "Source: $src"
  echo "Thumbnail: $thumbnail"
  echo "File ID: $fileId"
  echo "--------------------------"
done < "$VIDEO_SOURCES_CSV"