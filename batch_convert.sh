#!/bin/bash

FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

INPUT_DIR="./input_videos"
OUTPUT_DIR="./output_videos"
THUMBNAIL_DIR="./thumbnails"

# Video parameters
SCALE="1920:1080"
QUALITY="30"        # CRF value (lower = higher quality, larger file size)
PRESET="slow"        # FFmpeg preset (slower = better compression)
AUDIO_BITRATE="128k" # Audio bitrate

# Thumbnail parameters
THUMBNAIL_TIME="00:00:02"
THUMBNAIL_QUALITY="2"  # Lower value = higher quality


if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: CSV files are missing."
    exit 1
fi

# Function to find video file details
get_video_file() {
    local file_id="$1"
    local src="$2"
    local match_found=false

    # Check for an exact match
    while IFS=',' read -r file_id_row userId name filename originalname mimetype destination path size created file_thumbnail location bucket key type progressStatus views topixId portrait; do
        if [[ "$file_id_row" == "id" ]]; then
            continue
        fi

        # Trim whitespace and remove quotes
        file_id_row=$(echo "$file_id_row" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
        # echo "Comparing File ID: '$file_id' with ID: '$file_id_row'"

        if [[ "$file_id" == "$file_id_row" ]]; then
            echo "Match Found for File ID: $file_id"
            echo "Source: $src"
            echo "Original Name: $originalname"
            match_found=true
            break
        fi
    done < <(cat "$FILE_NAMES_CSV") # Ensure clean environment for IFS

    # If no exact match is found, check if key is included in src
    if [[ "$match_found" == false ]]; then
        echo "No exact match found for File ID: $file_id. Searching for partial matches..."
        while IFS=',' read -r file_id_row userId name filename originalname mimetype destination path size created file_thumbnail location bucket key type progressStatus views topixId portrait; do
            if [[ "$key" == "key" ]]; then
                continue
            fi

            # Trim whitespace and remove quotes
            key=$(echo "$key" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')

            if [[ "$src" == *"$key"* ]]; then

                echo "Partial Match Found!"
                echo "File Key: $key is included in Source: $src"
                echo "Original Name: $originalname"
                echo "Original Name: $originalname"
                match_found=true


                # Check if the file with the key exists in the INPUT_DIR
                if ls "$INPUT_DIR"/*"$key"* 1> /dev/null 2>&1; then
                    echo "File with Key: $key found in INPUT_DIR."
                    echo "Proceeding with processing..."
                    # Example logic: List matching files
                    ls "$INPUT_DIR"/*"$key"*
                else
                    echo "No file with Key: $key found in INPUT_DIR."
                fi

                break
            fi
        done < <(cat "$FILE_NAMES_CSV")
    fi

    if [[ "$match_found" == false ]]; then
        echo "No match found for File ID: $file_id in Source: $src"
    fi
}


# Main loop to process video sources
while IFS=',' read -r video_id src thumbnail file_id; do
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    # Trim whitespace and remove quotes
    file_id=$(echo "$file_id" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Processing Video ID: $video_id, File ID: $file_id"

    # Call the function with arguments
    get_video_file "$file_id" "$src"

done < <(cat "$VIDEO_SOURCES_CSV") # Ensure clean environment for IFS
