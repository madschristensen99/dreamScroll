#!/usr/bin/env node

// Test script for YouTube Shorts publishing functionality
const path = require('path');
const { createAndPublishMovie } = require('./src/index');
const appiumUtils = require('./src/utils/appium');

// Parse command line arguments
const args = process.argv.slice(2);
let prompt = 'space adventure';
let caption = null;
let videoPath = null;

// Process command line arguments
for (let i = 0; i < args.length; i++) {
  if (args[i] === '--prompt' && i + 1 < args.length) {
    prompt = args[i + 1];
    i++;
  } else if (args[i] === '--caption' && i + 1 < args.length) {
    caption = args[i + 1];
    i++;
  } else if (args[i] === '--video' && i + 1 < args.length) {
    videoPath = args[i + 1];
    i++;
  }
}

// If no caption is provided, use the prompt as the caption
caption = caption || `Check out this AI-generated "${prompt}" video!`;

/**
 * Main test function
 */
async function runTest() {
  try {
    console.log('='.repeat(50));
    console.log('YouTube Shorts Publishing Test');
    console.log('='.repeat(50));
    
    if (videoPath) {
      // If a video path is provided, use the direct publishing method
      console.log(`Using existing video: ${videoPath}`);
      
      // Import the required modules
      const youtubePublisher = require('./src/services/youtubePublisher');
      
      // Generate mock story data with choices for testing
      const mockStoryData = {
        choices: [
          'The astronaut discovers an alien civilization',
          'The astronaut finds an abandoned space station'
        ]
      };
      
      // Generate poll options from mock story data
      const pollOptions = youtubePublisher.generatePollOptionsFromStory(mockStoryData);
      
      // Start Appium server
      console.log('Starting Appium server...');
      await appiumUtils.startAppiumServer({ showLogs: true });
      
      // Publish to YouTube Shorts
      console.log(`Publishing video to YouTube Shorts with caption: "${caption}"`);
      const shortsUrl = await youtubePublisher.publishToYouTubeShorts(videoPath, caption, pollOptions);
      
      console.log('\nResults:');
      console.log('-'.repeat(50));
      console.log('Video successfully published to YouTube Shorts!');
      console.log('YouTube Shorts URL:', shortsUrl);
    } else {
      // If no video path is provided, generate a new video and publish it
      console.log(`Generating and publishing a new video with prompt: "${prompt}"`);
      console.log(`Caption: "${caption}"`);
      
      // Create and publish movie
      const result = await createAndPublishMovie(prompt, caption);
      
      console.log('\nResults:');
      console.log('-'.repeat(50));
      console.log('Video successfully generated and published!');
      console.log('Playback URL:', result.playbackUrl);
      console.log('YouTube Shorts URL:', result.shortsUrl);
    }
    
    console.log('='.repeat(50));
    console.log('Test completed successfully!');
  } catch (error) {
    console.error('Error during test:', error);
  } finally {
    // Stop Appium server
    console.log('Stopping Appium server...');
    await appiumUtils.stopAppiumServer();
  }
}

// Run the test
runTest().catch(error => {
  console.error('Unhandled error during test:', error);
  process.exit(1);
});
