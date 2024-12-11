#!/bin/bash

# CSV files
FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

# Ensure both files exist
if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: One or both CSV files are missing."
    exit 1
fi

# Iterate over video_sources.csv
while IFS=',' read -r video_id src thumbnail file_id; do
    # Skip header row
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    match_found=false

    # Iterate over File.csv to find matching file_id
    while IFS=',' read -r file_id_row userId name filename originalname mimetype destination path size created file_thumbnail location bucket key type progressStatus views topixId portrait; do
        # Skip header row
        if [[ "$file_id_row" == "id" ]]; then
            continue
        fi

        if [[ "$file_id" == "$file_id_row" ]]; then
            echo "Match Found:"
            echo "Video ID: $video_id"
            echo "Source: $src"
            echo "File ID: $file_id"
            echo "Original Name: $originalname"
            echo "Path: $path"
            echo "--------------------------"
            match_found=true
            break
        fi
    done < "$FILE_NAMES_CSV"

    if [[ "$match_found" == false ]]; then
        echo "No match found for File ID: $file_id (Video ID: $video_id)"
    fi
done < "$VIDEO_SOURCES_CSV"
