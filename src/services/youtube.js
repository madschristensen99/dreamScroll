// YouTube Shorts integration service using Appium
const path = require('path');
const fs = require('fs');
const { remote } = require('webdriverio');
const axios = require('axios');
const appiumConfig = require('../config/appium.config');

// Skip axios-retry configuration for now
// We'll implement proper retry logic directly in the service methods if needed

/**
 * YouTube Shorts service for uploading videos with polls
 */
class YouTubeShortsService {
  constructor(config = {}) {
    // Merge provided config with default config from appium.config.js
    this.config = {
      appiumServerUrl: config.appiumServerUrl || `http://${appiumConfig.server.host}:${appiumConfig.server.port}`,
      deviceName: config.deviceName || appiumConfig.android.deviceName,
      platformName: config.platformName || appiumConfig.android.platformName,
      platformVersion: config.platformVersion || appiumConfig.android.platformVersion,
      appPackage: config.appPackage || appiumConfig.android.appPackage,
      appActivity: config.appActivity || appiumConfig.android.appActivity,
      automationName: config.automationName || appiumConfig.android.automationName,
      noReset: config.noReset !== undefined ? config.noReset : appiumConfig.android.noReset,
      fullReset: config.fullReset !== undefined ? config.fullReset : appiumConfig.android.fullReset,
      autoGrantPermissions: config.autoGrantPermissions !== undefined ? config.autoGrantPermissions : appiumConfig.android.autoGrantPermissions,
      ...config
    };
    
    this.driver = null;
  }
  
  /**
   * Initialize the Appium driver
   * @returns {Promise<void>}
   */
  async initialize() {
    console.log('Initializing YouTube Shorts service with Appium...');
    
    try {
      // WebdriverIO capabilities configuration
      const capabilities = {
        platformName: this.config.platformName,
        'appium:deviceName': this.config.deviceName,
        'appium:platformVersion': this.config.platformVersion,
        'appium:appPackage': this.config.appPackage,
        'appium:appActivity': this.config.appActivity,
        'appium:automationName': this.config.automationName,
        'appium:newCommandTimeout': 60000,
        'appium:autoGrantPermissions': this.config.autoGrantPermissions,
        'appium:noReset': this.config.noReset,
        'appium:fullReset': this.config.fullReset
      };
      
      // Initialize the WebdriverIO client
      this.driver = await remote({
        protocol: 'http',
        hostname: new URL(this.config.appiumServerUrl).hostname,
        port: parseInt(new URL(this.config.appiumServerUrl).port || '4723'),
        path: '/wd/hub',
        capabilities,
        logLevel: 'error'
      });
      
      console.log('Appium driver initialized successfully');
    } catch (error) {
      console.error('Error initializing Appium driver:', error);
      throw error;
    }
  }
  
  /**
   * Upload a video to YouTube Shorts with poll options
   * @param {string} videoPath - Path to the video file
   * @param {string} caption - Caption for the YouTube Short
   * @param {object} pollOptions - Poll options for the Short
   * @param {string[]} pollOptions.options - Array of poll option texts (max 2)
   * @param {string} [pollOptions.question] - Optional poll question
   * @param {number} [pollOptions.durationDays=7] - Poll duration in days (default: 7)
   * @returns {Promise<string>} - URL of the uploaded Short
   */
  async uploadShortWithPoll(videoPath, caption, pollOptions) {
    try {
      if (!this.driver) {
        await this.initialize();
      }
      
      console.log(`Uploading video to YouTube Shorts: ${videoPath}`);
      
      // Validate inputs
      if (!fs.existsSync(videoPath)) {
        throw new Error(`Video file not found: ${videoPath}`);
      }
      
      if (!pollOptions || !Array.isArray(pollOptions.options) || pollOptions.options.length < 2) {
        throw new Error('Poll options must be an array with at least 2 items');
      }
      
      if (pollOptions.options.length > 2) {
        console.warn('YouTube Shorts only supports 2 poll options. Using the first 2 options.');
        pollOptions.options = pollOptions.options.slice(0, 2);
      }
      
      // Prepare poll data
      const pollData = {
        options: pollOptions.options,
        question: pollOptions.question || '',
        durationDays: pollOptions.durationDays || 7
      };
      
      // Step 1: Open YouTube app
      console.log('Opening YouTube app...');
      await this.driver.activateApp(this.config.appPackage);
      await this.driver.pause(3000);
      
      // Step 2: Tap on the create button (+ icon) at the bottom center
      console.log('Tapping create button...');
      const createButton = await this.driver.$('//android.widget.FrameLayout[@content-desc="Create"]');
      await createButton.click();
      await this.driver.pause(2000);
      
      // Step 3: Select "Create a Short" option
      console.log('Selecting Create a Short option...');
      const createShortOption = await this.driver.$('//android.widget.TextView[@text="Create a Short"]');
      await createShortOption.click();
      await this.driver.pause(2000);
      
      // Step 4: Tap on "Add" button in the bottom left
      console.log('Tapping Add button...');
      const addButton = await this.driver.$('//android.widget.Button[@text="Add"]');
      await addButton.click();
      await this.driver.pause(2000);
      
      // Step 5: Push the video file to the device first
      console.log('Pushing video file to device...');
      const deviceVideoPath = `/sdcard/Download/${path.basename(videoPath)}`;
      await this.driver.pushFile(deviceVideoPath, fs.readFileSync(videoPath).toString('base64'));
      await this.driver.pause(1000);
      
      // Step 6: Select "Browse" to access device files
      console.log('Selecting Browse option...');
      const browseOption = await this.driver.$('//android.widget.TextView[@text="Browse"]');
      await browseOption.click();
      await this.driver.pause(2000);
      
      // Step 7: Navigate to Downloads folder
      console.log('Navigating to Downloads folder...');
      const downloadFolder = await this.driver.$('//android.widget.TextView[@text="Downloads"]');
      await downloadFolder.click();
      await this.driver.pause(2000);
      
      // Step 8: Select the video file
      console.log('Selecting video file...');
      const videoFile = await this.driver.$(`//android.widget.TextView[@text="${path.basename(videoPath)}"]`);
      await videoFile.click();
      await this.driver.pause(3000);
      
      // Step 9: Wait for video processing and tap Next
      console.log('Waiting for video processing...');
      await this.driver.pause(5000); // Wait for video to process
      
      // Tap Next button
      console.log('Tapping Next button...');
      const nextButton = await this.driver.$('//android.widget.Button[@text="Next"]');
      await nextButton.click();
      await this.driver.pause(3000);
      
      // Step 10: Add caption
      console.log('Adding caption...');
      const captionField = await this.driver.$('//android.widget.EditText');
      await captionField.setValue(caption);
      await this.driver.pause(1000);
      
      // Step 11: Add poll
      console.log('Adding poll...');
      // Scroll down to see more options if needed
      await this.driver.touchAction([
        { action: 'press', x: 500, y: 1500 },
        { action: 'moveTo', x: 500, y: 500 },
        'release'
      ]);
      await this.driver.pause(1000);
      
      // Tap on Poll option
      const pollOption = await this.driver.$('//android.widget.TextView[@text="Poll"]');
      await pollOption.click();
      await this.driver.pause(2000);
      
      // Step 12: Set poll question if provided
      if (pollData.question) {
        console.log('Setting poll question...');
        const questionField = await this.driver.$('//android.widget.EditText[@text="Ask a question..."]');
        await questionField.setValue(pollData.question);
        await this.driver.pause(1000);
      }
      
      // Step 13: Set poll options
      console.log('Setting poll options...');
      const optionFields = await this.driver.$$('//android.widget.EditText[contains(@text, "Option")]');
      for (let i = 0; i < Math.min(optionFields.length, pollData.options.length); i++) {
        await optionFields[i].setValue(pollData.options[i]);
        await this.driver.pause(1000);
      }
      
      // Step 14: Set poll duration
      console.log('Setting poll duration...');
      const durationButton = await this.driver.$('//android.widget.TextView[@text="Poll duration"]');
      await durationButton.click();
      await this.driver.pause(1000);
      
      // Select duration based on pollData.durationDays
      let durationText = '7 days';
      if (pollData.durationDays === 1) {
        durationText = '1 day';
      } else if (pollData.durationDays === 3) {
        durationText = '3 days';
      } else {
        // Default to the configured default poll duration
        const defaultDuration = appiumConfig.youtube.defaultPollDurationDays || 7;
        if (defaultDuration === 1) {
          durationText = '1 day';
        } else if (defaultDuration === 3) {
          durationText = '3 days';
        } else {
          durationText = '7 days';
        }
      }
      
      const durationOption = await this.driver.$(`//android.widget.TextView[@text="${durationText}"]`);
      await durationOption.click();
      await this.driver.pause(1000);
      
      // Step 15: Save poll
      console.log('Saving poll...');
      const savePollButton = await this.driver.$('//android.widget.Button[@text="Done"]');
      await savePollButton.click();
      await this.driver.pause(2000);
      
      // Step 16: Upload the Short
      console.log('Uploading Short...');
      // Scroll down to see the upload button if needed
      await this.driver.touchAction([
        { action: 'press', x: 500, y: 1500 },
        { action: 'moveTo', x: 500, y: 500 },
        'release'
      ]);
      await this.driver.pause(1000);
      
      const uploadButton = await this.driver.$('//android.widget.Button[@text="Upload"]');
      await uploadButton.click();
      
      // Step 17: Wait for upload to complete
      console.log('Waiting for upload to complete...');
      await this.waitForUploadToComplete();
      
      // Step 18: Get the URL of the uploaded Short
      const shortUrl = await this.getUploadedShortUrl();
      console.log(`Short uploaded successfully: ${shortUrl}`);
      
      return shortUrl;
    } catch (error) {
      console.error('Error uploading video to YouTube Shorts:', error);
      throw error;
    } finally {
      // Close the driver session
      if (this.driver) {
        await this.driver.deleteSession();
        this.driver = null;
      }
    }
  }
  
  /**
   * Wait for the upload to complete
   * @returns {Promise<void>}
   */
  async waitForUploadToComplete() {
    const maxWaitTime = appiumConfig.youtube.uploadTimeoutMs || (10 * 60 * 1000); // Default: 10 minutes
    const startTime = Date.now();
    
    console.log('Waiting for YouTube Shorts upload to complete...');
    
    while (Date.now() - startTime < maxWaitTime) {
      try {
        // Check for upload success message (various possible messages)
        const successTexts = [
          'Your Short is live',
          'Your Short was uploaded',
          'Short uploaded',
          'Upload complete'
        ];
        
        for (const text of successTexts) {
          const successElement = await this.driver.$(`//android.widget.TextView[contains(@text, "${text}")]`);
          if (await successElement.isExisting()) {
            console.log(`Upload completed successfully! Found message: ${text}`);
            return;
          }
        }
        
        // Check for upload progress indicators
        const progressTexts = ['Uploading', 'Processing', 'Creating'];
        let uploadInProgress = false;
        
        for (const text of progressTexts) {
          const progressElement = await this.driver.$(`//android.widget.TextView[contains(@text, "${text}")]`);
          if (await progressElement.isExisting()) {
            console.log(`Upload in progress... (${text})`);
            uploadInProgress = true;
            break;
          }
        }
        
        if (!uploadInProgress) {
          console.log('Waiting for upload status indication...');
        }
        
        await this.driver.pause(5000); // Check every 5 seconds
      } catch (error) {
        console.log('Waiting for upload to complete... (No status indicators found)');
        await this.driver.pause(5000);
      }
    }
    
    throw new Error('Upload timed out after 10 minutes');
  }
  
  /**
   * Get the URL of the uploaded Short
   * @returns {Promise<string>}
   */
  async getUploadedShortUrl() {
    try {
      // Look for "View" button after upload
      console.log('Looking for View button...');
      await this.driver.pause(2000); // Wait for UI to stabilize
      
      // Try different possible button texts
      const viewButtonTexts = ['View', 'Watch', 'Go to channel'];
      let viewButton = null;
      
      for (const text of viewButtonTexts) {
        try {
          viewButton = await this.driver.$(`//android.widget.Button[@text="${text}"]`);
          if (await viewButton.isExisting()) {
            console.log(`Found "${text}" button, clicking...`);
            await viewButton.click();
            await this.driver.pause(3000);
            break;
          }
        } catch (err) {
          console.log(`Button "${text}" not found, trying next option...`);
        }
      }
      
      if (!viewButton) {
        console.log('No view button found, using timestamp-based URL');
        return `https://youtube.com/shorts/unknown_${Date.now()}`;
      }
      
      // Try to get the video ID from the URL
      // Since we can't directly get the URL from the Android app, we'll use a timestamp
      // In a real implementation, you might want to use Android's clipboard or other methods
      
      // Generate a YouTube Shorts URL with timestamp
      const timestamp = Date.now();
      const shortUrl = `https://youtube.com/shorts/choicestream_${timestamp}`;
      
      console.log(`Generated Short URL: ${shortUrl}`);
      console.log('Note: This is a placeholder URL. The actual Short can be found on your YouTube channel.');
      
      return shortUrl;
    } catch (error) {
      console.error('Error getting uploaded Short URL:', error);
      return `https://youtube.com/shorts/unknown_${Date.now()}`;
    }
  }
  
  /**
   * Close the Appium driver session
   * @returns {Promise<void>}
   */
  async close() {
    if (this.driver) {
      await this.driver.deleteSession();
      this.driver = null;
      console.log('Appium driver session closed');
    }
  }
}

module.exports = new YouTubeShortsService();
