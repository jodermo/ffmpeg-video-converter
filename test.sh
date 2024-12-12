#!/bin/bash

VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
LOG_FILE="./debug_log.txt"

# Prüfen, ob die CSV-Datei existiert
if [[ ! -f "$VIDEO_IDS_CSV" ]]; then
    echo "[ERROR] CSV file not found at $VIDEO_IDS_CSV"
    exit 1
fi

# Leere die Log-Datei, falls sie existiert
> "$LOG_FILE"

# Durchlaufe alle Dateien im Ordner input_videos
for file in input_videos/*; do
    # Überspringe die readme.md-Datei
    if [[ "$file" == *"readme.md"* ]]; then
        continue
    fi

    # Ursprünglichen Dateinamen protokollieren
    echo "[INFO] Processing file: $file" >> "$LOG_FILE"

    # Normalisiere den Dateinamen (ersetze Sonderzeichen, Leerzeichen, etc.)
    normalized_name=$(basename "$file" | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]')
    
    # Protokolliere den normalisierten Namen
    echo "[DEBUG] Normalized name: $normalized_name" >> "$LOG_FILE"

    # Überprüfen, ob der normalisierte Name in der CSV-Datei existiert
    match=$(grep -i "$normalized_name" "$VIDEO_IDS_CSV" | tr -d '"' | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]')
    
    if [[ -n "$match" ]]; then
        echo "[INFO] Match found for: $file" >> "$LOG_FILE"
        echo "[DEBUG] Matching CSV row: $match" >> "$LOG_FILE"
    else
        echo "[WARNING] No match for: $file" >> "$LOG_FILE"
    fi
done

echo "[INFO] Processing complete. Check $LOG_FILE for details."
