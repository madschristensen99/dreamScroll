/**
 * Generate Video Prompt with Context
 * 
 * This script reads the latest poll results and generates a new video prompt
 * using the Grok API service with context management.
 */

const fs = require('fs');
const path = require('path');
const grokService = require('./src/services/grok');

// Configuration
const POLL_RESULTS_DIR = path.join(process.cwd(), 'poll_results');
const LATEST_RESULTS_FILE = path.join(POLL_RESULTS_DIR, 'latest_results.json');
const PROMPT_OUTPUT_FILE = path.join(POLL_RESULTS_DIR, 'latest_prompt.json');

/**
 * Get the latest poll results
 * @returns {Object} The latest poll results or null if not found
 */
function getLatestResults() {
  try {
    if (fs.existsSync(LATEST_RESULTS_FILE)) {
      const data = fs.readFileSync(LATEST_RESULTS_FILE, 'utf8');
      
      try {
        // Try to parse the JSON
        const results = JSON.parse(data);
        
        // Validate required fields and provide defaults if missing
        const validatedResults = {
          question: results.question || 'What happens next?',
          options: Array.isArray(results.options) && results.options.length >= 2 ? 
                  results.options : ['Yes', 'Maybe'],
          results: Array.isArray(results.results) && results.results.length >= 2 ? 
                  results.results : [50, 50],
          winningOption: results.winningOption || 'Yes',
          winningIndex: typeof results.winningIndex === 'number' ? results.winningIndex : 0,
          totalVotes: typeof results.totalVotes === 'number' ? results.totalVotes : 0,
          timestamp: results.timestamp || new Date().toISOString()
        };
        
        // Ensure the results array has valid numbers
        validatedResults.results = validatedResults.results.map(num => {
          const parsed = parseInt(num);
          return isNaN(parsed) ? 50 : parsed;
        });
        
        return validatedResults;
      } catch (parseError) {
        console.error('Error parsing JSON from poll results file:', parseError);
        
        // Create a default response if parsing fails
        console.log('Using default poll results due to parsing error');
        return {
          question: 'What happens next?',
          options: ['Yes', 'Maybe'],
          results: [50, 50],
          winningOption: 'Yes',
          winningIndex: 0,
          totalVotes: 0,
          timestamp: new Date().toISOString()
        };
      }
    }
    return null;
  } catch (error) {
    console.error('Error reading latest poll results file:', error);
    return null;
  }
}

/**
 * Save the generated prompt to a file
 * @param {Object} promptData - The prompt data to save
 */
function savePrompt(promptData) {
  try {
    // Ensure directory exists
    if (!fs.existsSync(POLL_RESULTS_DIR)) {
      fs.mkdirSync(POLL_RESULTS_DIR, { recursive: true });
    }
    
    fs.writeFileSync(PROMPT_OUTPUT_FILE, JSON.stringify(promptData, null, 2));
    console.log(`Prompt saved to ${PROMPT_OUTPUT_FILE}`);
  } catch (error) {
    console.error('Error saving prompt:', error);
  }
}

/**
 * Generate a new prompt based on poll results with context
 */
async function generatePromptWithContext() {
  try {
    // Get the latest poll results
    const pollResults = getLatestResults();
    if (!pollResults) {
      console.error('No poll results found. Please run extract-poll-results.sh first.');
      process.exit(1);
    }
    
    console.log('Found poll results:');
    console.log(`Question: ${pollResults.question}`);
    console.log(`Options: ${pollResults.options.join(' vs ')}`);
    console.log(`Results: ${pollResults.results.join('% vs ')}%`);
    console.log(`Winning Option: ${pollResults.winningOption}`);
    
    // Build the prompt based on the winning option
    const promptText = `Create a new short-form video script based on the winning poll option: "${pollResults.winningOption}".`;
    
    // Context data to pass to the Grok API
    const contextData = {
      pollQuestion: pollResults.question,
      pollOptions: pollResults.options,
      pollResults: pollResults.results,
      winningOption: pollResults.winningOption,
      timestamp: pollResults.timestamp
    };
    
    console.log('\nGenerating prompt with context...');
    
    // Call the Grok API with context
    const generatedPrompt = await grokService.generateStoryPrompt(promptText, contextData);
    
    // Save the generated prompt
    savePrompt(generatedPrompt);
    
    console.log('\nGenerated prompt with context:');
    if (generatedPrompt.context) {
      console.log(`Context: ${generatedPrompt.context}`);
    }
    console.log('Storyboard concept:', generatedPrompt.scenes ? generatedPrompt.scenes[0].prompt.substring(0, 100) + '...' : 'No scenes found');
    console.log(`Next poll question: ${generatedPrompt.question}`);
    console.log(`Next poll options: ${generatedPrompt.choices.join(' vs ')}`);
    
    return generatedPrompt;
  } catch (error) {
    console.error('Error generating prompt with context:', error);
    process.exit(1);
  }
}

// Run the script if called directly
if (require.main === module) {
  generatePromptWithContext();
}

module.exports = { generatePromptWithContext };
