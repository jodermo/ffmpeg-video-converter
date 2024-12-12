#!/bin/bash

VIDEO_IDS_CSV="./csv_data/convert_ids.csv"
LOG_FILE="./debug_log.txt"

# Prüfen, ob die CSV-Datei existiert
if [[ ! -f "$VIDEO_IDS_CSV" ]]; then
    echo "[ERROR] CSV file not found at $VIDEO_IDS_CSV" | tee -a "$LOG_FILE"
    exit 1
fi

# Leere die Log-Datei
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
    normalized_name=$(basename "$file" | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g; s/[()]/_/g' | tr '[:upper:]' '[:lower:]')
    
    # Protokolliere den normalisierten Namen
    echo "[DEBUG] Normalized name: $normalized_name" >> "$LOG_FILE"

    # Überprüfen, ob der normalisierte Name in der CSV-Datei existiert
    matches=$(grep -i "$normalized_name" "$VIDEO_IDS_CSV" | tr -d '"' | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g; s/[()]/_/g' | tr '[:upper:]' '[:lower:]')

    if [[ -n "$matches" ]]; then
        echo "[INFO] Match found for: $file" >> "$LOG_FILE"
        echo "[DEBUG] Matching CSV rows:" >> "$LOG_FILE"
        echo "$matches" >> "$LOG_FILE"
    else
        echo "[WARNING] No match for: $file" >> "$LOG_FILE"
        echo "[DEBUG] CSV contents near match:" >> "$LOG_FILE"
        grep -i "$(basename "$file" | cut -d'.' -f1)" "$VIDEO_IDS_CSV" >> "$LOG_FILE" || echo "[DEBUG] No similar entries found in CSV" >> "$LOG_FILE"
    fi
done

echo "[INFO] Processing complete. Check $LOG_FILE for details."
