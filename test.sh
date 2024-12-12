#!/bin/bash

VIDEO_IDS_CSV="./csv_data/convert_ids.csv"

# Prüfen, ob die CSV-Datei existiert
if [[ ! -f "$VIDEO_IDS_CSV" ]]; then
    echo "[ERROR] CSV file not found at $VIDEO_IDS_CSV"
    exit 1
fi

# Durchlaufe alle Dateien im Ordner input_videos
for file in input_videos/*; do
    # Überspringe die readme.md-Datei
    if [[ "$file" == *"readme.md"* ]]; then
        continue
    fi

    # Normalisiere den Dateinamen (ersetze Sonderzeichen, Leerzeichen, etc.)
    normalized_name=$(basename "$file" | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]')

    # Überprüfen, ob der normalisierte Name in der CSV-Datei existiert
    if ! grep -qi "$normalized_name" <(cut -d',' -f2 "$VIDEO_IDS_CSV" | tr -d '"' | sed 's/ /_/g; s/ä/ae/g; s/ü/ue/g; s/ö/oe/g; s/ß/ss/g' | tr '[:upper:]' '[:lower:]'); then
        echo "No match for: $file"
    fi
done
