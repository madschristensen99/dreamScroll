// Main application entry point
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
      } else if (!prompt || prompt === 'entertain') {
        // If no specific argument is provided, use it as the prompt
        prompt = args[i];
      }
    }
    
    // If no caption is provided, use the prompt as the caption
    caption = caption || prompt;
    
    if (publishToYouTube) {
      console.log(`Creating and publishing movie with prompt: "${prompt}" and caption: "${caption}"`);
      const result = await createAndPublishMovie(prompt, caption);
      console.log('Movie generated and published successfully!');
      console.log('Playback URL:', result.playbackUrl);
      console.log('YouTube Shorts URL:', result.shortsUrl);
    } else {
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
    
    // Extract the local video file path from the playback URL
    // This assumes the playbackUrl points to a local file or contains the path information
    const videoPathMatch = playbackUrl.match(/file:\/\/(.+)/) || [];
    const videoPath = videoPathMatch[1] || playbackUrl;
    
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
