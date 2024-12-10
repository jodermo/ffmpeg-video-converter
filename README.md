# FFmpeg Converter

This scripts are designed to process all video files in a specified input directory, optimize them for web playback, and extract a thumbnail for each video. It is tailored for landscape-oriented videos but can be adapted for other formats.

### File structure

- converter/
    - [existing_video_names](./existing_video_names) : *Drop CSV with existing video sources here*
    - [input_videos_landscape/](./input_videos_landscape) : *Landscape videos to convert*
    - [input_videos_portrait/](./input_videos_portrait) : *Portrait videos to convert*
    - [output_videos/](./output_videos) : *Converted files*
    - [thumbnails/](./thumbnails): *Extracted thumbnails*
    - [batch_convert_named_landscape.sh](./batch_convert_named_landscape.sh): *Only convert video if name exist in CSV, rename thumbnail to name from CSV*
    - [batch_convert_named_portrait.sh](./batch_convert_named_portrait.sh): *Only convert video if name exist in CSV, rename thumbnail to name from CSV*
    - [linux_batch_convert_landscape.sh](./linux_batch_convert_landscape.sh): *Bash file for linus and mac*
    - [linux_batch_convert_portrait.sh](./linux_batch_convert_portrait.sh): *Bash file for linus and mac*
    - [win_batch_convert_landscape.bat](./win_batch_convert_landscape.bat): *Batsh file for windows*
    - [win_batch_convert_portrait.bat](./win_batch_convert_portrait.bat): *Batsh file for windows*

1. Check the Script's Permissions
Make sure the script has executable permissions. Run:
    - `chmod +x batch_convert_named_landscape.sh`
    - `chmod +x batch_convert_named_portrait.sh`
    - `chmod +x linux_batch_convert_landscape.sh`
    - `chmod +x linux_batch_convert_portrait.sh`

2. Run Script (with video source CSV)
    - Drop `video_sources.csv` to [existing_video_names/](./existing_video_names)
    - Landscape: `bash batch_convert_named_landscape.sh`
    - Portrait `bash batch_convert_named_portrait.sh`

3. Run Script (without video source CSV)
    - Landscape: `bash linux_batch_convert_landscape.sh`
    - Portrait `bash linux_batch_convert_portrait.sh`




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
