#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Generating video prompt with context...${NC}"

# Run the Node.js script
node generate-with-context.js

# Check if the script executed successfully
if [ $? -eq 0 ]; then
  echo -e "${GREEN}Successfully generated prompt with context!${NC}"
  echo "The prompt has been saved to poll_results/latest_prompt.json"
  echo "You can now use this prompt to generate your next video."
else
  echo -e "${RED}Failed to generate prompt with context.${NC}"
  echo "Please check the error messages above and try again."
  exit 1
fi
