#!/bin/bash

# Input CSV Paths
FILES_CSV="./csv_data/files.csv"
VIDEO_SOURCES_CSV="./csv_data/video_sources.csv"

# Output Combined CSV Path
COMBINED_CSV="./csv_data/combined.csv"

# Normalize filenames
normalize_filename() {
    echo "$1" | sed -E 's/[[:space:]]+/_/g; s/[äÄ]/ae/g; s/[üÜ]/ue/g; s/[öÖ]/oe/g; s/ß/ss/g' \
        | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]//g'
}

# Initialize the combined CSV file with headers
setup_combined_csv() {
    echo "video.id,video.src,video.fileId,file.id,file.originalname,file.key,file.path" > "$COMBINED_CSV"
    echo "Initialized combined CSV at $COMBINED_CSV"
}

# Merge files.csv and video_sources.csv into the combined CSV
merge_csv_files() {
    declare -A FILE_MAP

    echo "Preloading files.csv into memory..."
    while IFS=',' read -r file_id userId name filename originalname mimetype destination path size created thumbnail location bucket key type progressStatus views topixId portrait; do
        if [[ -n "$file_id" ]]; then
            normalized_originalname=$(normalize_filename "$originalname")
            FILE_MAP["$file_id"]="$file_id,$originalname,$key,$path"
        fi
    done < <(tail -n +2 "$FILES_CSV")

    echo "Merging video_sources.csv with files.csv..."
    while IFS=',' read -r id src thumbnail fileId; do
        normalized_src=$(normalize_filename "$(basename "$src")")
        file_data=${FILE_MAP["$fileId"]}

        if [[ -z "$file_data" ]]; then
            # No match in files.csv, add only video_sources.csv data
            echo "$id,$src,$fileId,,,," >> "$COMBINED_CSV"
        else
            # Match found, merge fields
            echo "$id,$src,$fileId,$file_data" >> "$COMBINED_CSV"
        fi
    done < <(tail -n +2 "$VIDEO_SOURCES_CSV")

    echo "Combined CSV generation completed at $COMBINED_CSV"
}

# Main Script
setup_combined_csv
merge_csv_files
