@echo off
SETLOCAL ENABLEDELAYEDEXPANSION

REM Input/Output directories
SET INPUT_DIR=.\input_videos_landscape
SET OUTPUT_DIR=.\output_videos
SET THUMBNAIL_DIR=.\thumbnails

REM Video parameters
SET SCALE=1920:1080
REM CRF value (lower = higher quality, larger file size)
SET QUALITY=23   
REM FFmpeg preset (slower = better compression)
SET PRESET=slow      
REM Audio bitrate   
SET AUDIO_BITRATE=128k   

REM Thumbnail parameters
SET THUMBNAIL_TIME=00:00:02
REM Lower value = higher quality
SET THUMBNAIL_QUALITY=2

REM Create output and thumbnail directories if they don't exist
IF NOT EXIST "%OUTPUT_DIR%" (
    mkdir "%OUTPUT_DIR%"
)
IF NOT EXIST "%THUMBNAIL_DIR%" (
    mkdir "%THUMBNAIL_DIR%"
)

REM Loop through all video files in the input directory
FOR %%F IN ("%INPUT_DIR%\*.*") DO (
    REM Extract the base filename without extension
    SET "FILENAME=%%~nF"
    
    REM Set the output file path
    SET "OUTPUT_FILE=%OUTPUT_DIR%\!FILENAME!.mp4"
    
    REM Set the thumbnail file path
    SET "THUMBNAIL_FILE=%THUMBNAIL_DIR%\!FILENAME!.jpg"
    
    REM Display current processing status
    echo Processing: %%~nF
    
    REM Convert the video to web-optimized portrait resolution with defined parameters
    ffmpeg -y -i "%%F" -vf "scale=!SCALE!:force_original_aspect_ratio=decrease,pad=!SCALE!:(ow-iw)/2:(oh-ih)/2" -c:v libx264 -preset !PRESET! -crf !QUALITY! -c:a aac -b:a !AUDIO_BITRATE! -movflags +faststart "!OUTPUT_FILE!"
    
    REM Extract a thumbnail at the specified time with defined quality
    ffmpeg -y -i "%%F" -ss !THUMBNAIL_TIME! -vframes 1 -q:v !THUMBNAIL_QUALITY! "!THUMBNAIL_FILE!"
)

ENDLOCAL
echo Batch conversion and thumbnail extraction completed.
echo Optimized portrait videos are in the "%OUTPUT_DIR%" directory.
echo Thumbnails are in the "%THUMBNAIL_DIR%" directory.
pause
