#!/bin/bash

FILE_NAMES_CSV="./csv_data/File.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

if [[ ! -f "$FILE_NAMES_CSV" || ! -f "$VIDEO_SOURCES_CSV" ]]; then
    echo "Error: CSV files are missing."
    exit 1
fi

while IFS=',' read -r video_id src thumbnail file_id; do
    if [[ "$video_id" == "id" ]]; then
        continue
    fi

    match_found=false
    # Trim whitespace and remove quotes
    file_id=$(echo "$file_id" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
    echo "Processing Video ID: $video_id, File ID: $file_id"

    while IFS=',' read -r file_id_row userId name filename originalname mimetype destination path size created file_thumbnail location bucket key type progressStatus views topixId portrait; do
        if [[ "$file_id_row" == "id" ]]; then
            continue
        fi

        # Trim whitespace and remove quotes
        file_id_row=$(echo "$file_id_row" | sed 's/^"//;s/"$//;s/^[[:space:]]*//;s/[[:space:]]*$//')
        echo "Comparing File ID: '$file_id' with ID: '$file_id_row'"

        if [[ "$file_id" == "$file_id_row" ]]; then
            echo "Match Found for Video ID: $video_id, File ID: $file_id"
            echo "Original Name: $originalname"
            match_found=true
            break
        fi
    done < <(cat "$FILE_NAMES_CSV") # Ensure clean environment for IFS

    if [[ "$match_found" == false ]]; then
        echo "No match found for File ID: $file_id (Video ID: $video_id)"
    fi
done < <(cat "$VIDEO_SOURCES_CSV") # Ensure clean environment for IFS
