# FFmpeg Converter

This scripts are designed to process all video files in a specified input directory, optimize them for web playback, and extract a thumbnail for each video.

### File structure

- converter/
    - [input_videos/](./input_videos) : *All videos to convert*
    - [output_videos/](./output_videos) : *Converted files*
    - [thumbnails/](./thumbnails): *Extracted thumbnails*
    - [logs/](./logs): *Output logs*
    - [batch_convert.sh](./batch_convert.sh): *Bash file for linux and Mac*

1. Check the Script's Permissions
Make sure the script has executable permissions. Run:
    - `chmod +x batch_convert.sh`

2. Drop your video data
    - Drop `File.csv` to [csv_data/](./csv_data)
    - Drop `video_sources.csv` to [csv_data/](./csv_data)
    - Drop your video files to [input_videos/](./input_videos)

3. Run Script (without video source CSV)
    - Run: `bash batch_convert.sh`

4. Watch result
    - Converted videos in [output_videos/](./output_videos)
    - Generated thumbnails in [thumbnails/](./thumbnails)
    - Output logs in [logs/](./logs)

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
