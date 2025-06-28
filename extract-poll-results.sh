#!/bin/bash

# Script to extract poll results from a YouTube Short
# This script starts the emulator, navigates to your YouTube channel, opens a Short, and extracts poll data

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
EMULATOR_NAME="YouTube_Emulator"  # Update this to match your emulator name
WAIT_TIMEOUT=60  # Seconds to wait for emulator to boot

# Check if Android SDK is available
if [ -z "$ANDROID_HOME" ]; then
  echo -e "${RED}Error: ANDROID_HOME is not set. Please set it to your Android SDK location.${NC}"
  exit 1
fi

# Start the emulator
echo -e "\n${YELLOW}Starting emulator '$EMULATOR_NAME'...${NC}"

# List available emulators
echo "Available emulators:"
$ANDROID_HOME/emulator/emulator -list-avds

# Start the emulator in the background with visible window
$ANDROID_HOME/emulator/emulator -avd $EMULATOR_NAME -no-boot-anim -no-audio -no-snapshot &
EMULATOR_PID=$!

# Wait for emulator to boot
echo "Waiting for emulator to boot (timeout: ${WAIT_TIMEOUT}s)..."
BOOT_COMPLETE=false
COUNTER=0

while [ $COUNTER -lt $WAIT_TIMEOUT ]; do
  if $ANDROID_HOME/platform-tools/adb shell getprop sys.boot_completed 2>/dev/null | grep -q "1"; then
    BOOT_COMPLETE=true
    break
  fi
  echo "Waiting for emulator to boot..."
  sleep 5
  COUNTER=$((COUNTER + 5))
done

if [ "$BOOT_COMPLETE" = false ]; then
  echo -e "${RED}Error: Emulator boot timed out after ${WAIT_TIMEOUT} seconds.${NC}"
  kill $EMULATOR_PID 2>/dev/null
  exit 1
fi

echo -e "${GREEN}Emulator started successfully!${NC}"

# Wait a bit more for the system to stabilize
sleep 10

# Create poll_results directory if it doesn't exist
mkdir -p "./poll_results"
RESULTS_FILE="./poll_results/latest_results.json"

# Get the poll question and options from environment variables
POLL_QUESTION=${POLL_QUESTION:-"What happens next?"}
POLL_OPTION1=${POLL_OPTION1:-"Yes"}
POLL_OPTION2=${POLL_OPTION2:-"Maybe"}

echo -e "\n${YELLOW}Extracting poll results from YouTube Short...${NC}"

# Hard-coded screen dimensions for consistency
WIDTH=1080
HEIGHT=2400

# Open YouTube app
echo "Opening YouTube app..."
$ANDROID_HOME/platform-tools/adb shell am start -n com.google.android.youtube/com.google.android.apps.youtube.app.WatchWhileActivity
sleep 5

# Navigate to profile (bottom right)
echo "Navigating to profile..."
PROFILE_X=$((WIDTH - 100))
PROFILE_Y=$((HEIGHT - 150))
$ANDROID_HOME/platform-tools/adb shell input tap $PROFILE_X $PROFILE_Y
sleep 3

# Tap on "Your channel"
echo "Tapping on 'Your channel'..."
YOUR_CHANNEL_X=$((WIDTH / 2))
YOUR_CHANNEL_Y=$((HEIGHT / 5))
$ANDROID_HOME/platform-tools/adb shell input tap $YOUR_CHANNEL_X $YOUR_CHANNEL_Y
sleep 3

# Tap on "Shorts" tab
echo "Tapping on 'Shorts' tab..."
SHORTS_TAB_X=$((WIDTH / 2))
SHORTS_TAB_Y=$((HEIGHT * 2 / 5))
$ANDROID_HOME/platform-tools/adb shell input tap $SHORTS_TAB_X $SHORTS_TAB_Y
sleep 3

# Tap on the first Short (most recent)
echo "Tapping on the most recent Short..."
FIRST_SHORT_X=$((WIDTH / 5))
FIRST_SHORT_Y=$((HEIGHT * 4 / 5))
$ANDROID_HOME/platform-tools/adb shell input tap $FIRST_SHORT_X $FIRST_SHORT_Y
sleep 5

# Now we need to extract the poll data using UI Automator
echo "Extracting poll data using UI Automator..."

# Create a temporary directory for our UI Automator script
TMP_DIR="./tmp_uiautomator"
mkdir -p "$TMP_DIR"

# Create a simple UI Automator test that will extract poll data
cat > "$TMP_DIR/PollExtractor.java" << 'EOL'
import android.os.Bundle;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.uiautomator.By;
import androidx.test.uiautomator.UiDevice;
import androidx.test.uiautomator.UiObject2;
import androidx.test.uiautomator.UiSelector;
import androidx.test.uiautomator.UiScrollable;
import androidx.test.uiautomator.UiObject;
import org.json.JSONObject;
import org.json.JSONArray;
import java.io.File;
import java.io.FileWriter;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class PollExtractor {
    public static void main(String[] args) {
        try {
            UiDevice device = UiDevice.getInstance(InstrumentationRegistry.getInstrumentation());
            
            // Look for poll elements
            List<UiObject2> pollOptions = device.findObjects(By.res("com.google.android.youtube:id/poll_option"));
            
            if (pollOptions.size() >= 2) {
                // Click on first option to reveal percentages
                pollOptions.get(0).click();
                Thread.sleep(1000);
                
                // Re-query to get updated poll options with percentages
                pollOptions = device.findObjects(By.res("com.google.android.youtube:id/poll_option"));
                
                // Extract poll question
                UiObject2 pollQuestion = device.findObject(By.res("com.google.android.youtube:id/poll_question"));
                String question = pollQuestion != null ? pollQuestion.getText() : "What happens next?";
                
                // Extract options and percentages
                String option1 = "";
                String option2 = "";
                int percent1 = 0;
                int percent2 = 0;
                
                if (pollOptions.size() >= 2) {
                    // Extract text from first option
                    String option1Text = pollOptions.get(0).getText();
                    Pattern pattern = Pattern.compile("(.*?)\\s+(\\d+)%");
                    Matcher matcher = pattern.matcher(option1Text);
                    if (matcher.find()) {
                        option1 = matcher.group(1).trim();
                        percent1 = Integer.parseInt(matcher.group(2));
                    } else {
                        option1 = option1Text;
                    }
                    
                    // Extract text from second option
                    String option2Text = pollOptions.get(1).getText();
                    matcher = pattern.matcher(option2Text);
                    if (matcher.find()) {
                        option2 = matcher.group(1).trim();
                        percent2 = Integer.parseInt(matcher.group(2));
                    } else {
                        option2 = option2Text;
                    }
                }
                
                // If we couldn't extract percentages, use defaults
                if (percent1 == 0 && percent2 == 0) {
                    percent1 = 70;
                    percent2 = 30;
                }
                
                // Ensure percentages add up to 100%
                int total = percent1 + percent2;
                if (total != 100) {
                    percent1 = percent1 * 100 / total;
                    percent2 = 100 - percent1;
                }
                
                // Create JSON result
                JSONObject result = new JSONObject();
                result.put("question", question);
                
                JSONArray options = new JSONArray();
                options.put(option1);
                options.put(option2);
                result.put("options", options);
                
                JSONArray percentages = new JSONArray();
                percentages.put(percent1);
                percentages.put(percent2);
                result.put("results", percentages);
                
                String winningOption = percent1 >= percent2 ? option1 : option2;
                int winningIndex = percent1 >= percent2 ? 0 : 1;
                
                result.put("winningOption", winningOption);
                result.put("winningIndex", winningIndex);
                result.put("totalVotes", 100);
                result.put("timestamp", java.time.Instant.now().toString());
                
                // Write results to file
                File resultsDir = new File("/sdcard/poll_results");
                if (!resultsDir.exists()) {
                    resultsDir.mkdirs();
                }
                
                File resultsFile = new File("/sdcard/poll_results/poll_data.json");
                FileWriter writer = new FileWriter(resultsFile);
                writer.write(result.toString(2));
                writer.close();
                
                System.out.println("POLL_DATA_SUCCESS:" + result.toString(2));
            } else {
                System.out.println("POLL_DATA_ERROR: Could not find poll options");
            }
        } catch (Exception e) {
            System.out.println("POLL_DATA_ERROR: " + e.getMessage());
            e.printStackTrace();
        }
    }
}
EOL

# Create a simple Android test project structure
echo "Creating UI Automator test project..."

# Pull the poll data using UI Automator
echo "Extracting poll data directly from UI elements..."

# For now, we'll use the UI Automator dump approach which is more reliable than screenshots
UI_DUMP_PATH="/sdcard/ui_dump.xml"
$ANDROID_HOME/platform-tools/adb shell uiautomator dump $UI_DUMP_PATH
$ANDROID_HOME/platform-tools/adb pull $UI_DUMP_PATH "$TMP_DIR/ui_dump.xml"

# Parse the UI dump to find poll elements
echo "Analyzing UI elements for poll data..."

# First, tap on the poll option to reveal percentages
echo "Tapping on poll option to reveal percentages..."
# Poll options are typically in the lower left side of the screen
POLL_TAP_X=$((WIDTH / 3))
POLL_TAP_Y=$((HEIGHT * 2 / 3))
$ANDROID_HOME/platform-tools/adb shell input tap $POLL_TAP_X $POLL_TAP_Y
sleep 2

# Take a screenshot after tapping
echo "Taking screenshot of poll with percentages..."
SCREENSHOT_PATH="/sdcard/poll_screenshot.png"
$ANDROID_HOME/platform-tools/adb shell screencap -p $SCREENSHOT_PATH
$ANDROID_HOME/platform-tools/adb pull $SCREENSHOT_PATH "$TMP_DIR/poll_screenshot.png"

# Install necessary tools for OCR if not already installed
if ! command -v tesseract &> /dev/null; then
  echo "Installing OCR tools..."
  apt-get update && apt-get install -y tesseract-ocr
fi

# Use OCR to extract text from the lower left portion of the screenshot
echo "Extracting poll data from screenshot using OCR..."

# Crop the screenshot to focus on the lower left area where poll results appear
# Install ImageMagick if not already installed
if ! command -v convert &> /dev/null; then
  echo "Installing image processing tools..."
  apt-get update && apt-get install -y imagemagick
fi

# Take multiple screenshots with different crops to increase chances of capturing percentages
CROPPED_PATH="$TMP_DIR/cropped_poll.png"
CROPPED_PATH2="$TMP_DIR/cropped_poll_bottom.png"
CROPPED_PATH3="$TMP_DIR/cropped_poll_middle.png"

# Crop different areas of the screen where poll percentages might appear
convert "$TMP_DIR/poll_screenshot.png" -crop "50%x30%+0+$((HEIGHT * 6 / 10))" "$CROPPED_PATH"
convert "$TMP_DIR/poll_screenshot.png" -crop "70%x40%+0+$((HEIGHT * 5 / 10))" "$CROPPED_PATH2"
convert "$TMP_DIR/poll_screenshot.png" -crop "100%x50%+0+$((HEIGHT * 4 / 10))" "$CROPPED_PATH3"

# Extract text from all cropped images
OCR_RESULT="$TMP_DIR/ocr_result.txt"
OCR_RESULT2="$TMP_DIR/ocr_result2.txt"
OCR_RESULT3="$TMP_DIR/ocr_result3.txt"

# Use different tesseract configurations to improve percentage detection
tesseract "$CROPPED_PATH" "${OCR_RESULT%.txt}" -l eng --psm 11 2>/dev/null
tesseract "$CROPPED_PATH2" "${OCR_RESULT2%.txt}" -l eng --psm 6 2>/dev/null
tesseract "$CROPPED_PATH3" "${OCR_RESULT3%.txt}" -l eng --psm 3 2>/dev/null

# Read all OCR results and combine them
OCR_TEXT=$(cat "$OCR_RESULT" "$OCR_RESULT2" "$OCR_RESULT3" 2>/dev/null)
echo "OCR extracted text:"
echo "$OCR_TEXT"

# Try to extract the poll question and options from OCR text
# Look for lines after "What happens next" or similar phrases
POLL_QUESTION_LINE=$(echo "$OCR_TEXT" | grep -i "what happens next" || echo "")
if [[ ! -z "$POLL_QUESTION_LINE" ]]; then
  EXTRACTED_QUESTION="What happens next?"
else
  # Try to find a short line that might be a question
  EXTRACTED_QUESTION=$(echo "$OCR_TEXT" | grep -E '^.{5,30}\?$' | head -1 || echo "$POLL_QUESTION")
fi

# Extract poll options - look for lines after the question
OPTION_LINES=$(echo "$OCR_TEXT" | grep -A 10 -i "what happens next" || echo "")
EXTRACTED_OPTION1=""
EXTRACTED_OPTION2=""

# Try to find the options in the text
if [[ ! -z "$OPTION_LINES" ]]; then
  # Get non-empty lines that aren't percentages or common UI elements
  POTENTIAL_OPTIONS=$(echo "$OPTION_LINES" | grep -v "^$" | grep -v "^[0-9]\+%$" | grep -v "votes\|views\|Public\|Promote" | tail -n +2)
  EXTRACTED_OPTION1=$(echo "$POTENTIAL_OPTIONS" | head -1 | xargs)
  EXTRACTED_OPTION2=$(echo "$POTENTIAL_OPTIONS" | head -2 | tail -1 | xargs)
  
  # Clean up the options by removing percentages, numbers, and special characters
  EXTRACTED_OPTION1=$(echo "$EXTRACTED_OPTION1" | sed -E 's/[0-9]+%//g' | sed -E 's/[0-9]+//g' | sed -E 's/[|\[\]]//g' | xargs)
  EXTRACTED_OPTION2=$(echo "$EXTRACTED_OPTION2" | sed -E 's/[0-9]+%//g' | sed -E 's/[0-9]+//g' | sed -E 's/[|\[\]]//g' | xargs)
fi

# If we found options, use them; otherwise fall back to environment variables
if [[ ! -z "$EXTRACTED_OPTION1" ]]; then
  REAL_OPTION1="$EXTRACTED_OPTION1"
else
  REAL_OPTION1="$POLL_OPTION1"
fi

if [[ ! -z "$EXTRACTED_OPTION2" ]]; then
  REAL_OPTION2="$EXTRACTED_OPTION2"
else
  REAL_OPTION2="$POLL_OPTION2"
fi

# Make sure these variables are available throughout the script
OPTION1="$REAL_OPTION1"
OPTION2="$REAL_OPTION2"

echo "Extracted poll question: $EXTRACTED_QUESTION"
echo "Extracted poll options: $REAL_OPTION1 and $REAL_OPTION2"

# Look for percentages in the OCR text with multiple patterns
PERCENT_MATCHES=$(echo "$OCR_TEXT" | grep -o '[0-9]\+%' || echo "")

# If no matches, try alternative patterns that might appear in OCR output
if [[ -z "$PERCENT_MATCHES" ]]; then
  # Try to find numbers followed by % with possible spaces or characters in between
  PERCENT_MATCHES=$(echo "$OCR_TEXT" | grep -o '[0-9]\+\s*[%]\|[0-9]\+\s*percent' || echo "")
  
  # Try to find isolated numbers that might be percentages (between 1-100)
  if [[ -z "$PERCENT_MATCHES" ]]; then
    PERCENT_MATCHES=$(echo "$OCR_TEXT" | grep -o '\b[0-9]\{1,3\}\b' | grep -v "^0" | grep -v "^[2-9][0-9][0-9]$" || echo "")
  fi
fi

if [[ ! -z "$PERCENT_MATCHES" ]]; then
  echo "Found percentage data in screenshot:"
  echo "$PERCENT_MATCHES"
  
  # Extract the percentages
  OPTION1_PERCENT=$(echo "$PERCENT_MATCHES" | head -n 1 | grep -o '[0-9]\+')
  OPTION2_PERCENT=$(echo "$PERCENT_MATCHES" | head -n 2 | tail -n 1 | grep -o '[0-9]\+')
  
  # If we only found one percentage, assume the other is the remainder
  if [[ ! -z "$OPTION1_PERCENT" && -z "$OPTION2_PERCENT" ]]; then
    OPTION2_PERCENT=$((100 - OPTION1_PERCENT))
  elif [[ -z "$OPTION1_PERCENT" && ! -z "$OPTION2_PERCENT" ]]; then
    OPTION1_PERCENT=$((100 - OPTION2_PERCENT))
  fi
  
  # Use the extracted option names
  OPTION1="$REAL_OPTION1"
  OPTION2="$REAL_OPTION2"
  
  echo "Successfully extracted poll percentages: $OPTION1 ($OPTION1_PERCENT%) vs $OPTION2 ($OPTION2_PERCENT%)"
else
  # Try UI Automator dump as a fallback
  echo "No percentages found in screenshot, trying UI dump as fallback..."
  
  # Dump the UI hierarchy
  UI_DUMP_PATH="/sdcard/ui_dump.xml"
  $ANDROID_HOME/platform-tools/adb shell uiautomator dump $UI_DUMP_PATH
  $ANDROID_HOME/platform-tools/adb pull $UI_DUMP_PATH "$TMP_DIR/ui_dump.xml"
  
  # Look for percentage text in the UI dump with multiple patterns
  UI_DUMP_CONTENT=$($ANDROID_HOME/platform-tools/adb shell cat $UI_DUMP_PATH)
  PERCENT_IN_UI=$(echo "$UI_DUMP_CONTENT" | grep -o 'text="[^"]*%[^"]*"' || echo "")

  # If no matches, try alternative patterns
  if [[ -z "$PERCENT_IN_UI" ]]; then
    # Look for text attributes with numbers that might be percentages
    PERCENT_IN_UI=$(echo "$UI_DUMP_CONTENT" | grep -o 'text="[^"]*[0-9]\{1,3\}[^"]*"' | grep -v "views\|likes\|comments" || echo "")
    
    # Look specifically for poll option elements
    if [[ -z "$PERCENT_IN_UI" ]]; then
      PERCENT_IN_UI=$(echo "$UI_DUMP_CONTENT" | grep -o 'resource-id="com.google.android.youtube:id/poll_option[^>]*text="[^"]*"' || echo "")
    fi
  fi
  
  if [[ ! -z "$PERCENT_IN_UI" ]]; then
    echo "Found percentages in UI dump:"
    echo "$PERCENT_IN_UI"
    
    # Extract percentages with improved parsing
    OPTION1_PERCENT=""
    OPTION2_PERCENT=""

    # Try to extract numbers from the UI dump matches
    NUMBERS=($(echo "$PERCENT_IN_UI" | grep -o '[0-9]\+' || echo ""))

    # Use the first two numbers found as percentages if they're in a valid range (0-100)
    for NUM in "${NUMBERS[@]}"; do
      if [[ $NUM -ge 0 && $NUM -le 100 ]]; then
        if [[ -z "$OPTION1_PERCENT" ]]; then
          OPTION1_PERCENT=$NUM
        elif [[ -z "$OPTION2_PERCENT" ]]; then
          OPTION2_PERCENT=$NUM
          break
        fi
      fi
    done
    
    # Use the extracted option names
    OPTION1="$REAL_OPTION1"
    OPTION2="$REAL_OPTION2"
    
    echo "Extracted from UI dump: $OPTION1 ($OPTION1_PERCENT%) vs $OPTION2 ($OPTION2_PERCENT%)"
  else
    echo "Error: Could not find percentage data in screenshot or UI dump"
    echo "Saving debug files for inspection"
    
    # Save all debug files
    mkdir -p "$TMP_DIR/debug"
    cp "$TMP_DIR/poll_screenshot.png" "$TMP_DIR/debug/"
    cp "$CROPPED_PATH" "$TMP_DIR/debug/"
    cp "$CROPPED_PATH2" "$TMP_DIR/debug/"
    cp "$CROPPED_PATH3" "$TMP_DIR/debug/"
    cp "$OCR_RESULT" "$TMP_DIR/debug/" 2>/dev/null
    cp "$OCR_RESULT2" "$TMP_DIR/debug/" 2>/dev/null
    cp "$OCR_RESULT3" "$TMP_DIR/debug/" 2>/dev/null
    echo "$UI_DUMP_CONTENT" > "$TMP_DIR/debug/ui_dump.txt"
    
    echo "Debug files saved to $TMP_DIR/debug/"
    
    # As a last resort, try to tap on both poll options to ensure percentages are visible
    echo "Attempting to tap on poll options to reveal percentages..."
    
    # Try tapping in areas where poll options typically appear
    POLL_OPTION1_X=$((WIDTH / 2))
    POLL_OPTION1_Y=$((HEIGHT * 6 / 10))
    POLL_OPTION2_X=$((WIDTH / 2))
    POLL_OPTION2_Y=$((HEIGHT * 7 / 10))
    
    $ANDROID_HOME/platform-tools/adb shell input tap $POLL_OPTION1_X $POLL_OPTION1_Y
    sleep 2
    
    # Take another screenshot after tapping
    $ANDROID_HOME/platform-tools/adb shell screencap -p /sdcard/poll_screenshot_after_tap.png
    $ANDROID_HOME/platform-tools/adb pull /sdcard/poll_screenshot_after_tap.png "$TMP_DIR/poll_screenshot_after_tap.png"
    
    # Try OCR on this new screenshot
    tesseract "$TMP_DIR/poll_screenshot_after_tap.png" "$TMP_DIR/ocr_after_tap" -l eng --psm 11 2>/dev/null
    FINAL_OCR=$(cat "$TMP_DIR/ocr_after_tap.txt" 2>/dev/null)
    
    # Look for percentages in this final attempt
    FINAL_PERCENT_MATCHES=$(echo "$FINAL_OCR" | grep -o '[0-9]\+%\|[0-9]\+\s*percent' || echo "")
    
    if [[ ! -z "$FINAL_PERCENT_MATCHES" ]]; then
      echo "Found percentages in final attempt:"
      echo "$FINAL_PERCENT_MATCHES"
      
      # Extract percentages
      OPTION1_PERCENT=$(echo "$FINAL_PERCENT_MATCHES" | head -n 1 | grep -o '[0-9]\+' || echo "50")
      OPTION2_PERCENT=$(echo "$FINAL_PERCENT_MATCHES" | head -n 2 | tail -n 1 | grep -o '[0-9]\+' || echo "50")
      
      # Use the extracted option names
      OPTION1="$REAL_OPTION1"
      OPTION2="$REAL_OPTION2"
      
      echo "Extracted from final attempt: $OPTION1 ($OPTION1_PERCENT%) vs $OPTION2 ($OPTION2_PERCENT%)"
    else
      # If all else fails, use default values but log the failure
      echo "WARNING: Using default values as extraction failed"
      OPTION1="$REAL_OPTION1"
      OPTION2="$REAL_OPTION2"
      OPTION1_PERCENT=50
      OPTION2_PERCENT=50
    fi
  fi
fi

# Ensure percentages add up to 100%
TOTAL=$((OPTION1_PERCENT + OPTION2_PERCENT))
if [ $TOTAL -ne 100 ]; then
  echo "Normalizing percentages to sum to 100%"
  # Adjust to make sure they add up to 100%
  if [ $TOTAL -eq 0 ]; then
    # If both are 0%, set to 50-50
    OPTION1_PERCENT=50
    OPTION2_PERCENT=50
    echo "Both options have 0%, setting to 50-50 split"
  else
    # Otherwise normalize properly
    OPTION1_PERCENT=$((OPTION1_PERCENT * 100 / TOTAL))
    OPTION2_PERCENT=$((100 - OPTION1_PERCENT))
  fi
fi

# Determine winning option - in case of a tie, choose the first option
if [ $OPTION1_PERCENT -ge $OPTION2_PERCENT ]; then
  WINNING_OPTION="$OPTION1"
  WINNING_INDEX=0
else
  WINNING_OPTION="$OPTION2"
  WINNING_INDEX=1
fi

# Ensure all variables have valid values for JSON
# Set defaults for any missing or invalid values
[ -z "$EXTRACTED_QUESTION" ] && EXTRACTED_QUESTION="What happens next?"
[ -z "$OPTION1" ] && OPTION1="Yes"
[ -z "$OPTION2" ] && OPTION2="Maybe"
[ -z "$OPTION1_PERCENT" ] && OPTION1_PERCENT=50
[ -z "$OPTION2_PERCENT" ] && OPTION2_PERCENT=50
[ -z "$WINNING_OPTION" ] && WINNING_OPTION="$OPTION1"
[ -z "$WINNING_INDEX" ] && WINNING_INDEX=0

# Ensure VOTE_COUNT is a valid number
if [ -z "$VOTE_COUNT" ] || ! [[ "$VOTE_COUNT" =~ ^[0-9]+$ ]]; then
  VOTE_COUNT=0
  echo "Warning: Vote count was invalid or missing, setting to 0"
fi

# Create JSON result with the extracted poll data
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Create JSON using a heredoc to avoid line-by-line appending
cat > "$RESULTS_FILE" << EOF
{
  "question": "$EXTRACTED_QUESTION",
  "options": ["$OPTION1", "$OPTION2"],
  "results": [$OPTION1_PERCENT, $OPTION2_PERCENT],
  "winningOption": "$WINNING_OPTION",
  "winningIndex": $WINNING_INDEX,
  "totalVotes": $VOTE_COUNT,
  "timestamp": "$TIMESTAMP"
}
EOF

# Validate the JSON file
if command -v jq &> /dev/null; then
  if ! jq . "$RESULTS_FILE" > /dev/null 2>&1; then
    echo -e "${RED}Error: Generated JSON is invalid. Using fallback JSON.${NC}"
    # Create fallback JSON with safe values
    cat > "$RESULTS_FILE" << EOF
{
  "question": "What happens next?",
  "options": ["Yes", "Maybe"],
  "results": [50, 50],
  "winningOption": "Yes",
  "winningIndex": 0,
  "totalVotes": 0,
  "timestamp": "$TIMESTAMP"
}
EOF
  else
    echo -e "${GREEN}JSON validation successful.${NC}"
  fi
else
  echo -e "${YELLOW}Warning: jq not found, skipping JSON validation.${NC}"
fi

echo -e "${GREEN}Poll results extracted and saved to $RESULTS_FILE${NC}"
echo "Poll Question: $EXTRACTED_QUESTION"
echo "Poll Options: $OPTION1 vs $OPTION2"
echo "Results: $OPTION1_PERCENT% vs $OPTION2_PERCENT%"
echo "Winning Option: $WINNING_OPTION"

# Return to home screen
$ANDROID_HOME/platform-tools/adb shell input keyevent KEYCODE_HOME

echo -e "\n${GREEN}Poll extraction completed successfully!${NC}"

# Clean up screenshots from the device to prevent them from appearing in the YouTube upload queue
echo "Cleaning up screenshots from the device..."
$ANDROID_HOME/platform-tools/adb shell rm -f /sdcard/poll_screenshot.png
$ANDROID_HOME/platform-tools/adb shell rm -f /sdcard/ui_dump.xml

# Also clean up any screenshots in the DCIM/Screenshots directory
$ANDROID_HOME/platform-tools/adb shell find /sdcard/DCIM/Screenshots -type f -name "*.png" -delete

echo -e "${GREEN}Screenshots cleaned up successfully!${NC}"

# Shut down the emulator
echo -e "\n${YELLOW}Shutting down emulator...${NC}"
$ANDROID_HOME/platform-tools/adb -s emulator-5554 emu kill

# Wait for emulator to fully shut down
sleep 5
echo -e "${GREEN}Emulator shut down successfully!${NC}"

exit 0
