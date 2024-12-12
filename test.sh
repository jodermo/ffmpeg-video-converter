#!/bin/bash

for file in input_videos/*; do
    if [[ "$file" == *"readme.md"* ]]; then
        continue
    fi
    ...
done
