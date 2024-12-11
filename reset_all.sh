#!/bin/bash

# Load configuration from config.env
if [[ -f "config.env" ]]; then
    # Remove Windows-style line endings before sourcing
    sed -i 's/\r$//' config.env
    source "config.env"
else
    echo "Error: config.env file not found."
    exit 1
fi

# Function to clear a directory but ignore README files
clear_directory() {
    local dir_path="$1"
    if [[ -d "$dir_path" ]]; then
        find "$dir_path" -type f ! -name "README*" -exec rm -f {} +
        echo "Cleared directory (excluding README files): $dir_path"
    else
        echo "Directory not found: $dir_path. Skipping."
    fi
}

# Clear logs
echo "Clearing logs..."
clear_directory "$LOG_DIR"

# Clear output videos
echo "Clearing output videos..."
clear_directory "$OUTPUT_DIR"

# Clear thumbnails
echo "Clearing thumbnails..."
clear_directory "$THUMBNAIL_DIR"

# Clear mapping file
if [[ -f "$MAPPING_FILE" ]]; then
    rm -f "$MAPPING_FILE"
    echo "Cleared mapping file: $MAPPING_FILE"
else
    echo "Mapping file not found: $MAPPING_FILE. Skipping."
fi

# Clear CSV log
if [[ -f "$CSV_LOG" ]]; then
    rm -f "$CSV_LOG"
    echo "Cleared CSV log: $CSV_LOG"
else
    echo "CSV log not found: $CSV_LOG. Skipping."
fi

echo "All logs and generated files have been cleared."
