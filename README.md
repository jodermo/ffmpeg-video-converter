# FFmpeg Converter

This scripts are designed to process all video files in a specified input directory, optimize them for web playback, and extract a thumbnail for each video.


### File structure

- converter/
    - [input_videos/](./input_videos) : *All videos to convert*
    - [output_videos/](./output_videos) : *Converted files*
    - [thumbnails/](./thumbnails): *Extracted thumbnails*
    - [logs/](./logs): *Output logs*
    - [batch_convert.sh](./batch_convert.sh): *Convert all files inside input_videos to output_videos*
    - [batch_convert_ids.sh](./batch_convert_ids.sh): *Convert based on CSV with video IDs: [id: number, src: string]*
    - [batch_convert_tables.sh](./batch_convert_tables.sh): *Convert based on CSV for complex database tables*
    - [batch_convert_thumbnails.sh](./batch_convert_thumbnails.sh): *Convert based on CSV for complex database tables, but thumbnails only*
    - [check.sh](./check.sh): *Compare input_videos and output_videos and write log file*
    - [reset_all.sh](./reset_all.sh): *Clear all logs and empty output_videos*

1. Check the Script's Permissions
Make sure the script has executable permissions. Run:
    - `chmod +x batch_convert.sh`
    - `chmod +x batch_convert_ids.sh`
    - `chmod +x batch_convert_tables.sh`
    - `chmod +x batch_convert_thumbnails.sh`
    - `chmod +x check.sh`
    - `chmod +x reset_all.sh`

2. A: Run Script (Convert all files inside input_videos to output_videos)
    - Drop your video files to [input_videos/](./input_videos)
    - Run: `bash batch_convert.sh`

3. B: Run Script  (Convert based on CSV with video IDs: [id: number, src: string])
    - Drop `convert_ids.csv` to [csv_data/](./csv_data)
    - Drop your video files to [input_videos/](./input_videos)
    - Run: `bash batch_convert_ids.sh`

4. C: Run Script  (Convert based on CSV for complex database tables)
    - Drop `files.csv` to  [csv_data/](./csv_data)
    - Drop `video_sources.csv` to [csv_data/](./csv_data)
    - Drop your video files to [input_videos/](./input_videos)
    - Run: `bash batch_convert_tables.sh` for videos and thumbnails
    - Run: `bash batch_convert_thumbnails.sh` for thumbnails only

5. Watch result
    - Converted videos in [output_videos/](./output_videos)
    - Generated thumbnails in [thumbnails/](./thumbnails)
    - Output logs in [logs/](./logs)

6. Check and create logs for converted files
    - Run: `bash check.sh`  
    - Output logs in [logs/](./logs)
        - `found_log.csv`
        - `not_found_log.csv`

7. Reset all, delete logs and generated stuff
    - Run: `bash reset_all.sh`

## Install ffmpeg on linux

1.  Update the package list to ensure you have the latest available versions:
    ```bash
    sudo apt update
     ```
2.  Install FFmpeg using the package manager:
    ```bash
    sudo apt install ffmpeg
     ```
3.  Check if FFmpeg is installed correctly and verify the version:
    ```bash
    ffmpeg -version
     ```

## Install ffmpeg on windows

1. Download FFmpeg from [ffmpeg.org](https://ffmpeg.org).

2. Extract the FFmpeg archive and add the bin folder to your system's PATH.

3.  Check if FFmpeg is installed correctly and verify the version:
    ```bash
    ffmpeg -version
     ```

## Install ffmpeg on mac

1.  Install Homebrew
    - If Homebrew (a macOS package manager) is not already installed, install it first:
        ```bash
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        ```

    - After installation, ensure brew is available by running: 

        ```bash
        brew --version
        ```

2.  Install FFmpeg
    - If Homebrew (a macOS package manager) is not already installed, install it first:
        ```bash
        brew install ffmpeg
        ```

    - After installation, ensure brew is available by running: 

        ```bash
        ffmpeg -version
        ```
