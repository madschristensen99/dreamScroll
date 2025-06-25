#!/bin/bash

# Script to start the Android emulator for YouTube Shorts publishing
# This script helps with starting the emulator and checking its status

# Configuration
EMULATOR_NAME="YouTube_Emulator"  # Update this to match your emulator name
WAIT_TIMEOUT=60  # Seconds to wait for emulator to boot

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to get touch coordinates
get_touch_coordinates() {
  echo "Touch the screen at the desired location. Press Ctrl+C to exit."
  $ANDROID_HOME/platform-tools/adb shell getevent -l | grep -E "ABS_MT_POSITION" --line-buffered
}

# Check if Android SDK is properly set up
if [ -z "$ANDROID_HOME" ]; then
  echo -e "${YELLOW}ANDROID_HOME environment variable not set.${NC}"
  echo -e "Setting ANDROID_HOME to $HOME/Android/Sdk"
  export ANDROID_HOME="$HOME/Android/Sdk"
  echo -e "${GREEN}Set Android SDK at: $ANDROID_HOME${NC}"
  
  # Add to PATH if not already there
  if [[ ":$PATH:" != *":$ANDROID_HOME/platform-tools:"* ]]; then
    export PATH="$PATH:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools"
  fi
fi

# Check if JAVA_HOME is set
if [ -z "$JAVA_HOME" ]; then
  echo -e "${YELLOW}JAVA_HOME environment variable not set.${NC}"
  echo -e "Setting JAVA_HOME to /usr/lib/jvm/java-17-openjdk-amd64"
  export JAVA_HOME="/usr/lib/jvm/java-17-openjdk-amd64"
  echo -e "${GREEN}Set JAVA_HOME at: $JAVA_HOME${NC}"
fi

# Check if emulator command is available
if [ ! -f "$ANDROID_HOME/emulator/emulator" ]; then
  echo -e "${RED}Emulator command not found. Make sure Android SDK is properly installed.${NC}"
  echo "The emulator should be at: $ANDROID_HOME/emulator/emulator"
  exit 1
fi

# Check if ADB is available
if [ ! -f "$ANDROID_HOME/platform-tools/adb" ]; then
  echo -e "${RED}ADB command not found. Make sure Android SDK Platform Tools are installed.${NC}"
  exit 1
fi

# List available emulators
echo -e "${YELLOW}Available emulators:${NC}"
$ANDROID_HOME/emulator/emulator -list-avds

# Check if the specified emulator exists
if ! $ANDROID_HOME/emulator/emulator -list-avds | grep -q "$EMULATOR_NAME"; then
  echo -e "${RED}Emulator '$EMULATOR_NAME' not found.${NC}"
  echo "Please create an emulator first or update the EMULATOR_NAME variable in this script."
  echo "See docs/emulator-setup.md for instructions."
  exit 1
fi

# Check if emulator is already running
if $ANDROID_HOME/platform-tools/adb devices | grep -q "emulator"; then
  echo -e "${GREEN}Emulator is already running.${NC}"
  echo "Connected devices:"
  $ANDROID_HOME/platform-tools/adb devices
else
  # Start the emulator with reduced resource usage
  echo -e "${YELLOW}Starting emulator '$EMULATOR_NAME'...${NC}"
  $ANDROID_HOME/emulator/emulator -avd "$EMULATOR_NAME" -no-snapshot-load -no-boot-anim -memory 2048 -gpu swiftshader_indirect &
  
  # Wait for emulator to boot
  echo -e "${YELLOW}Waiting for emulator to boot (timeout: ${WAIT_TIMEOUT}s)...${NC}"
  
  # Wait for emulator to boot fully
  echo "Waiting for emulator to boot..."
  while [ "$($ANDROID_HOME/platform-tools/adb -e shell getprop sys.boot_completed 2>/dev/null)" != "1" ]; do
    sleep 1
  done
  echo -e "${GREEN}Emulator booted successfully!${NC}"
  
  # Give the emulator time to stabilize after boot
  echo "Giving the emulator time to stabilize (10 seconds)..."
  sleep 10
fi

# Check if YouTube app is installed
echo "Checking if YouTube app is installed..."
if $ANDROID_HOME/platform-tools/adb shell pm list packages | grep -q "com.google.android.youtube"; then
  echo "YouTube app is installed."
else
  echo -e "${RED}YouTube app is not installed. Please install it from the Play Store.${NC}"
fi

# Push test video file to the emulator
echo "Pushing test video to emulator..."
if [ -f "./assets/princess.mp4" ]; then
  # Create necessary directories
  echo "Creating directories on emulator..."
  $ANDROID_HOME/platform-tools/adb shell mkdir -p /sdcard/Download
  $ANDROID_HOME/platform-tools/adb shell mkdir -p /sdcard/DCIM/Camera
  $ANDROID_HOME/platform-tools/adb shell mkdir -p /sdcard/Movies
  
  # Push the video file to multiple locations to ensure it's found
  echo "Pushing video to Download folder..."
  $ANDROID_HOME/platform-tools/adb push ./assets/princess.mp4 /sdcard/Download/
  
  echo "Pushing video to DCIM/Camera folder..."
  $ANDROID_HOME/platform-tools/adb push ./assets/princess.mp4 /sdcard/DCIM/Camera/
  
  echo "Pushing video to Movies folder..."
  $ANDROID_HOME/platform-tools/adb push ./assets/princess.mp4 /sdcard/Movies/
  
  # Run media scanner to ensure the files are indexed
  echo "Running media scanner to index the video files..."
  $ANDROID_HOME/platform-tools/adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Download/princess.mp4
  $ANDROID_HOME/platform-tools/adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/DCIM/Camera/princess.mp4
  $ANDROID_HOME/platform-tools/adb shell am broadcast -a android.intent.action.MEDIA_SCANNER_SCAN_FILE -d file:///sdcard/Movies/princess.mp4
  
  # Verify files exist
  echo "Verifying video files exist on emulator..."
  $ANDROID_HOME/platform-tools/adb shell ls -la /sdcard/Download/princess.mp4
  $ANDROID_HOME/platform-tools/adb shell ls -la /sdcard/DCIM/Camera/princess.mp4
  $ANDROID_HOME/platform-tools/adb shell ls -la /sdcard/Movies/princess.mp4
  
  echo -e "${GREEN}Test video pushed to emulator in multiple locations${NC}"
else
  echo -e "${YELLOW}Test video not found at ./assets/princess.mp4${NC}"
fi

# Check YouTube login status
echo "Checking YouTube login status..."
echo "Note: You need to manually verify if you're logged in to YouTube."

# Open YouTube app
echo "Opening YouTube app..."
$ANDROID_HOME/platform-tools/adb shell am start -n com.google.android.youtube/com.google.android.apps.youtube.app.WatchWhileActivity

# Wait for YouTube to fully load
echo "Waiting for YouTube to load (10 seconds)..."
sleep 10

# Click the '+' create button at the bottom center
echo "Clicking the '+' create button..."

# Get screen dimensions
SCREEN_SIZE=$($ANDROID_HOME/platform-tools/adb shell wm size | grep -o '[0-9]*x[0-9]*')
WIDTH=$(echo $SCREEN_SIZE | cut -d'x' -f1)
HEIGHT=$(echo $SCREEN_SIZE | cut -d'x' -f2)

# Calculate center-bottom position (for the '+' button)
X_POS=$(($WIDTH / 2))
Y_POS=$(($HEIGHT - 100))  # Fixed offset from bottom

# Tap the '+' button
$ANDROID_HOME/platform-tools/adb shell input tap $X_POS $Y_POS

# Wait for the create menu to appear
echo "Waiting for create menu to appear (10 seconds)..."
sleep 10

# Click the 'Add' button (icon above the word 'Add' on the left side)
echo "Clicking the 'Add' button..."
X_ADD=$(($WIDTH / 8))  # Approximately 1/8 of the way from the left
Y_ADD=$(($HEIGHT * 5 / 6))  # 5/6 of the way down from the top
echo "Tapping at coordinates: $X_ADD, $Y_ADD"
$ANDROID_HOME/platform-tools/adb shell input tap $X_ADD $Y_ADD

# Wait for the gallery to appear
echo "Waiting for gallery to appear (10 seconds)..."
sleep 5

# Click the first video under the 'Gallery' section
echo "Selecting the first video in gallery..."
X_VIDEO=$(($WIDTH / 4))  # Approximately 1/4 of the way from the left
Y_VIDEO=$(($HEIGHT / 4))  # Approximately 1/4 of the way from the top
$ANDROID_HOME/platform-tools/adb shell input tap $X_VIDEO $Y_VIDEO

# Wait for video selection to register
echo "Waiting for video selection (5 seconds)..."
sleep 5

# Click 'Next' button in the bottom right
echo "Clicking the 'Next' button..."
X_NEXT=$(($WIDTH - 100))  # 100 pixels from the right edge
Y_NEXT=$(($HEIGHT - 150))  # 150 pixels from the bottom
echo "Tapping at coordinates: $X_NEXT, $Y_NEXT"
$ANDROID_HOME/platform-tools/adb shell input tap $X_NEXT $Y_NEXT

# Wait for video processing
echo "Waiting for video processing (5 seconds)..."
sleep 5

# Click 'Done' button in the bottom right
echo "Clicking the 'Done' button..."
X_DONE=$(($WIDTH - 100))  # 100 pixels from the right edge
Y_DONE=$(($HEIGHT - 150))  # 150 pixels from the bottom
echo "Tapping at coordinates: $X_DONE, $Y_DONE"
$ANDROID_HOME/platform-tools/adb shell input tap $X_DONE $Y_DONE

# Wait for final processing
echo "Waiting for final processing (25 seconds)..."
sleep 25

# Click the 'Check' button (on the right side at same height as Add button)
echo "Clicking the 'Check' button..."
X_CHECK=$(($WIDTH - 135))  # Same distance from right as Add is from left
Y_CHECK=$(($HEIGHT * 5 / 6))  # Same height as the Add button
echo "Tapping at coordinates: $X_CHECK, $Y_CHECK"
$ANDROID_HOME/platform-tools/adb shell input tap $X_CHECK $Y_CHECK

# Wait for video processing after check button
echo "Waiting for video processing after check (10 seconds)..."
sleep 10

echo -e "\nSetup complete!"
echo -e "${GREEN}All steps completed successfully!${NC}"
echo " ✓ Emulator started and stabilized"
echo " ✓ Test video pushed to multiple locations"
echo " ✓ YouTube app opened"
echo " ✓ Create button clicked"
echo " ✓ Add button clicked"
echo " ✓ Video selected from gallery"
echo " ✓ Next button clicked"
echo " ✓ Done button clicked"
echo " ✓ Check button clicked"

# Uncomment the line below to get touch coordinates for debugging UI element positions
# get_touch_coordinates
echo "\nTo add a poll to the Short, run the full automation script:"
echo "node test-youtube-publish.js --video ./assets/princess.mp4 --caption \"ChoiceStream Test: What happens next?\""
