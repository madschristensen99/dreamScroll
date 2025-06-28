#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Generating and posting video using latest prompt...${NC}"

# We'll start the emulator only after generating the video

# Check if latest prompt exists
if [ ! -f "./poll_results/latest_prompt.json" ]; then
  echo -e "${RED}Error: No prompt found. Please run generate-with-context.sh first.${NC}"
  exit 1
fi

# Extract context from the prompt file to use as the prompt
CONTEXT=$(jq -r '.context' ./poll_results/latest_prompt.json)
POLL_QUESTION=$(jq -r '.question' ./poll_results/latest_prompt.json)
POLL_OPTION1=$(jq -r '.choices[0]' ./poll_results/latest_prompt.json)
POLL_OPTION2=$(jq -r '.choices[1]' ./poll_results/latest_prompt.json)

# Display information
echo -e "Context: ${YELLOW}${CONTEXT}${NC}"
echo -e "Poll Question: ${GREEN}${POLL_QUESTION}${NC}"
echo -e "Poll Options: ${GREEN}${POLL_OPTION1}${NC} vs ${GREEN}${POLL_OPTION2}${NC}"

# Export poll question and options as environment variables for the emulator script
export POLL_QUESTION="${POLL_QUESTION}"
export POLL_OPTION1="${POLL_OPTION1}"
export POLL_OPTION2="${POLL_OPTION2}"

# Run the video generation process first
echo -e "\n${YELLOW}Starting video generation process...${NC}"
node src/index.js --prompt "${CONTEXT}" --generate-only

# Check if video generation was successful
if [ $? -ne 0 ]; then
  echo -e "\n${RED}Error: Video generation failed.${NC}"
  exit 1
fi

# Start the emulator and prepare for publishing
echo -e "\n${YELLOW}Starting Android emulator and preparing for publishing...${NC}"
./post_to_youtube.sh

# Script completed successfully
echo -e "\n${GREEN}Video generation and publishing completed successfully!${NC}"
echo "The video has been generated and uploaded to YouTube Shorts with the following poll:"
echo "Question: ${POLL_QUESTION}"
echo "Options: ${POLL_OPTION1} vs ${POLL_OPTION2}"

# Exit with success
exit 0
