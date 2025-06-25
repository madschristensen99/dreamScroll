// YouTube publisher service for posting videos to YouTube Shorts with polls
const path = require('path');
const fs = require('fs');
const youtubeService = require('./youtube');
const appiumUtils = require('../utils/appium');
const appiumConfig = require('../config/appium.config');

/**
 * YouTube Publisher service for posting videos to YouTube Shorts with polls
 */
class YouTubePublisherService {
  constructor(config = {}) {
    this.config = {
      appiumPort: config.appiumPort || appiumConfig.server.port || 4723,
      appiumHost: config.appiumHost || appiumConfig.server.host || 'localhost',
      showAppiumLogs: config.showAppiumLogs || appiumConfig.server.showLogs || false,
      ...config
    };
  }
  
  /**
   * Publish a video to YouTube Shorts with a poll
   * @param {string} videoPath - Path to the video file
   * @param {string} caption - Caption for the YouTube Short
   * @param {object} pollOptions - Poll options for the Short
   * @param {string[]} pollOptions.options - Array of poll option texts (max 2)
   * @param {string} [pollOptions.question] - Optional poll question
   * @param {number} [pollOptions.durationDays=7] - Poll duration in days (default: 7)
   * @returns {Promise<string>} - URL of the uploaded Short
   */
  async publishToYouTubeShorts(videoPath, caption, pollOptions) {
    try {
      console.log('Preparing to publish video to YouTube Shorts...');
      
      // Validate inputs
      if (!fs.existsSync(videoPath)) {
        throw new Error(`Video file not found: ${videoPath}`);
      }
      
      if (!caption || typeof caption !== 'string') {
        throw new Error('Caption must be a non-empty string');
      }
      
      if (!pollOptions || !Array.isArray(pollOptions.options) || pollOptions.options.length < 2) {
        throw new Error('Poll options must be an array with at least 2 items');
      }
      
      // Start Appium server if not already running
      const isRunning = await appiumUtils.isAppiumServerRunning({
        port: this.config.appiumPort,
        host: this.config.appiumHost
      });
      
      if (!isRunning) {
        console.log('Starting Appium server...');
        await appiumUtils.startAppiumServer({
          port: this.config.appiumPort,
          host: this.config.appiumHost,
          showLogs: this.config.showAppiumLogs
        });
      } else {
        console.log('Appium server is already running');
      }
      
      // Upload video to YouTube Shorts with poll
      console.log('Uploading video to YouTube Shorts...');
      const shortUrl = await youtubeService.uploadShortWithPoll(videoPath, caption, pollOptions);
      
      console.log(`Video successfully published to YouTube Shorts: ${shortUrl}`);
      return shortUrl;
    } catch (error) {
      console.error('Error publishing video to YouTube Shorts:', error);
      throw error;
    } finally {
      // Stop Appium server if we started it
      if (!this.config.keepServerRunning) {
        await appiumUtils.stopAppiumServer();
      }
    }
  }
  
  /**
   * Generate poll options from story data
   * @param {object} storyData - Story data from the movie generator
   * @returns {object} - Poll options object
   */
  generatePollOptionsFromStory(storyData) {
    try {
      // Check if the story data has choices
      if (storyData.choices && Array.isArray(storyData.choices) && storyData.choices.length >= 2) {
        // Use the first two choices from the story data
        const options = [
          storyData.choices[0],
          storyData.choices[1]
        ];
        
        return {
          question: 'What happens next?',
          options: options,
          durationDays: 7
        };
      } else {
        console.warn('No choices found in story data, using default poll options');
        // Default options if no choices are available
        return {
          question: 'What happens next?',
          options: ['Option A', 'Option B'],
          durationDays: 7
        };
      }
    } catch (error) {
      console.error('Error generating poll options from story:', error);
      // Return default poll options
      return {
        question: 'What happens next?',
        options: ['Option A', 'Option B'],
        durationDays: 7
      };
    }
  }
}

module.exports = new YouTubePublisherService();
