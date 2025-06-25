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
  # Start the emulator
  echo -e "${YELLOW}Starting emulator '$EMULATOR_NAME'...${NC}"
  $ANDROID_HOME/emulator/emulator -avd "$EMULATOR_NAME" -no-snapshot-load -no-boot-anim &
  
  # Wait for emulator to boot
  echo -e "${YELLOW}Waiting for emulator to boot (timeout: ${WAIT_TIMEOUT}s)...${NC}"
  
  boot_completed=false
  for i in $(seq 1 $WAIT_TIMEOUT); do
    if $ANDROID_HOME/platform-tools/adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; then
      boot_completed=true
      break
    fi
    echo -n "."
    sleep 1
  done
  echo ""
  
  if [ "$boot_completed" = true ]; then
    echo -e "${GREEN}Emulator booted successfully!${NC}"
  else
    echo -e "${RED}Emulator boot timed out. It might still be starting up.${NC}"
    echo "You can check its status with: adb devices"
  fi
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
  $ANDROID_HOME/platform-tools/adb push ./assets/princess.mp4 /sdcard/Download/
  echo -e "${GREEN}Test video pushed to emulator at /sdcard/Download/princess.mp4${NC}"
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
echo "Waiting for YouTube to load (15 seconds)..."
sleep 15

# Click the '+' create button at the bottom center
echo "Clicking the '+' create button..."
# Get screen dimensions
SCREEN_SIZE=$($ANDROID_HOME/platform-tools/adb shell wm size | grep -o '[0-9]*x[0-9]*')
WIDTH=$(echo $SCREEN_SIZE | cut -d'x' -f1)
HEIGHT=$(echo $SCREEN_SIZE | cut -d'x' -f2)

# Calculate center-bottom position (for the '+' button)
X_POS=$(($WIDTH / 2))
Y_POS=$(($HEIGHT - 100))  # Adjust this value based on your emulator

# Tap the position
$ANDROID_HOME/platform-tools/adb shell input tap $X_POS $Y_POS

echo -e "\nSetup complete!"
echo "YouTube app opened and '+' create button clicked"
echo "You can continue with the manual steps or run the full automation script:"
echo "node test-youtube-publish.js --video ./assets/princess.mp4 --caption \"ChoiceStream Test: What happens next?\""
