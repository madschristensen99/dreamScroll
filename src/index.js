// Main application entry point
const fs = require('fs');
const path = require('path');
const grokService = require('./services/grok');
const movieGenerator = require('./services/movieGenerator');
const youtubePublisher = require('./services/youtubePublisher');

/**
 * Handle movie creation with a given prompt
 * @param {string} prompt - Initial prompt for movie generation
 * @returns {Promise<string>} - Playback URL for the generated movie
 */
async function handleCreateMovie(prompt) {
  console.log(`New movie created: Prompt: ${prompt}`);

  // Generate story data using Grok API
  const storyData = await grokService.generateStoryPrompt(prompt);
  
  // Generate movie scene using the story data
  const playbackUrl = await movieGenerator.generateMovieScene(storyData);
  
  return playbackUrl;
}

/**
 * Main function to start the movie generation service
 */
async function main() {
  try {
    console.log('Starting the movie generation service...');
    
    // Parse command line arguments
    const args = process.argv.slice(2);
    let prompt = 'entertain';
    let caption = null;
    let publishToYouTube = false;
    let generateOnly = false;
    let publishOnly = false;
    
    // Process command line arguments
    for (let i = 0; i < args.length; i++) {
      if (args[i] === '--prompt' && i + 1 < args.length) {
        prompt = args[i + 1];
        i++;
      } else if (args[i] === '--caption' && i + 1 < args.length) {
        caption = args[i + 1];
        i++;
      } else if (args[i] === '--publish') {
        publishToYouTube = true;
      } else if (args[i] === '--generate-only') {
        generateOnly = true;
      } else if (args[i] === '--publish-only') {
        publishOnly = true;
      } else if (!prompt || prompt === 'entertain') {
        // If no specific argument is provided, use it as the prompt
        prompt = args[i];
      }
    }
    
    // If no caption is provided, use the prompt as the caption
    caption = caption || prompt;
    
    if (publishOnly) {
      // Only publish the most recently generated video
      console.log('Publishing the most recently generated video to YouTube Shorts...');
      
      // Find the most recent video file
      const localFiles = fs.readdirSync(process.cwd());
      const videoFile = localFiles
        .filter(file => file.startsWith('final_movie_') && file.endsWith('.mp4'))
        .sort()
        .reverse()[0]; // Get the most recent one
      
      if (!videoFile) {
        throw new Error('No video file found. Please generate a video first.');
      }
      
      const videoPath = path.join(process.cwd(), videoFile);
      console.log(`Using local video file: ${videoPath}`);
      
      // Generate poll options from latest prompt data
      let pollOptions;
      try {
        const latestPromptData = JSON.parse(fs.readFileSync('./poll_results/latest_prompt.json', 'utf8'));
        pollOptions = {
          question: latestPromptData.question,
          options: latestPromptData.choices
        };
      } catch (error) {
        console.warn('Could not read poll options from latest_prompt.json, using defaults');
        pollOptions = {
          question: 'What happens next?',
          options: ['Yes', 'Maybe']
        };
      }
      
      // Publish to YouTube Shorts
      const shortsUrl = await publishMovieToYouTubeShorts(videoPath, caption, pollOptions);
      console.log('Video published successfully to YouTube Shorts!');
      console.log('YouTube Shorts URL:', shortsUrl);
      
    } else if (generateOnly) {
      // Only generate the video
      console.log(`Creating movie with prompt: "${prompt}"`);
      const playbackUrl = await handleCreateMovie(prompt);
      console.log('Movie generated successfully!');
      console.log('Playback URL:', playbackUrl);
      
    } else if (publishToYouTube) {
      // Generate and publish in one step
      console.log(`Creating and publishing movie with prompt: "${prompt}" and caption: "${caption}"`);
      const result = await createAndPublishMovie(prompt, caption);
      console.log('Movie generated and published successfully!');
      console.log('Playback URL:', result.playbackUrl);
      console.log('YouTube Shorts URL:', result.shortsUrl);
      
    } else {
      // Default: just generate the video
      console.log(`Creating movie with prompt: "${prompt}"`);
      const playbackUrl = await handleCreateMovie(prompt);
      console.log('Movie generated successfully!');
      console.log('Playback URL:', playbackUrl);
    }
  } catch (error) {
    console.error('Error processing movie:', error);
  }
}

// Run the main function if this file is executed directly
if (require.main === module) {
  main();
}

/**
 * Publish a movie to YouTube Shorts with a poll
 * @param {string} videoPath - Path to the video file
 * @param {string} caption - Caption for the YouTube Short
 * @param {object} pollOptions - Poll options for the Short
 * @returns {Promise<string>} - URL of the uploaded Short
 */
async function publishMovieToYouTubeShorts(videoPath, caption, pollOptions) {
  console.log(`Publishing movie to YouTube Shorts: ${videoPath}`);
  
  try {
    // Upload video to YouTube Shorts with poll
    const shortUrl = await youtubePublisher.publishToYouTubeShorts(videoPath, caption, pollOptions);
    
    console.log(`Movie published successfully to YouTube Shorts: ${shortUrl}`);
    return shortUrl;
  } catch (error) {
    console.error('Error publishing movie to YouTube Shorts:', error);
    throw error;
  }
}

/**
 * Create and publish a movie to YouTube Shorts with a poll
 * @param {string} prompt - Initial prompt for movie generation
 * @param {string} caption - Caption for the YouTube Short
 * @returns {Promise<object>} - Object containing playback URL and YouTube Shorts URL
 */
async function createAndPublishMovie(prompt, caption) {
  try {
    console.log(`Creating and publishing movie: Prompt: ${prompt}, Caption: ${caption}`);
    
    // Generate story data using Grok API
    const storyData = await grokService.generateStoryPrompt(prompt);
    
    // Generate movie scene using the story data
    const playbackUrl = await movieGenerator.generateMovieScene(storyData);
    
    // Get the local video file path - the playbackUrl is a LivePeer URL but we need the local file
    // The local file is named final_movie_[timestamp].mp4 and is in the current directory
    const localFiles = fs.readdirSync(process.cwd());
    const videoFile = localFiles.find(file => file.startsWith('final_movie_') && file.endsWith('.mp4'));
    
    if (!videoFile) {
      throw new Error('Local video file not found. The video generation may have failed.');
    }
    
    const videoPath = path.join(process.cwd(), videoFile);
    console.log(`Using local video file: ${videoPath}`);
    
    // Generate poll options from story data
    const pollOptions = youtubePublisher.generatePollOptionsFromStory(storyData);
    
    // Publish to YouTube Shorts
    const shortsUrl = await publishMovieToYouTubeShorts(videoPath, caption || prompt, pollOptions);
    
    return {
      playbackUrl,
      shortsUrl
    };
  } catch (error) {
    console.error('Error creating and publishing movie:', error);
    throw error;
  }
}

module.exports = {
  handleCreateMovie,
  publishMovieToYouTubeShorts,
  createAndPublishMovie
};
