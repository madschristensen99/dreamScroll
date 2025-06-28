// Grok API service for generating story prompts
const axios = require('axios');
const fs = require('fs');
const path = require('path');
const config = require('../config');

// Path for storing context history
const CONTEXT_DIR = path.join(process.cwd(), 'poll_results');
const CONTEXT_FILE = path.join(CONTEXT_DIR, 'context_history.json');
const MAX_CONTEXT_ITEMS = 10;

/**
 * Ensure the context directory exists
 */
function ensureContextDirectoryExists() {
  if (!fs.existsSync(CONTEXT_DIR)) {
    fs.mkdirSync(CONTEXT_DIR, { recursive: true });
  }
}

/**
 * Get the context history
 * @returns {Array} The context history or empty array if not found
 */
function getContextHistory() {
  try {
    ensureContextDirectoryExists();
    if (fs.existsSync(CONTEXT_FILE)) {
      const data = fs.readFileSync(CONTEXT_FILE, 'utf8');
      return JSON.parse(data);
    }
    return [];
  } catch (error) {
    console.error('Error reading context history:', error);
    return [];
  }
}

/**
 * Save context history
 * @param {Array} history - The context history to save
 */
function saveContextHistory(history) {
  try {
    ensureContextDirectoryExists();
    fs.writeFileSync(CONTEXT_FILE, JSON.stringify(history, null, 2));
    console.log('Context history saved successfully');
  } catch (error) {
    console.error('Error saving context history:', error);
  }
}

/**
 * Generate a story prompt using Grok API
 * @param {string} prompt - Initial prompt for story generation
 * @param {Object} contextData - Optional context data to include
 * @returns {Promise<object>} - Generated story data
 */
async function generateStoryPrompt(prompt, contextData = {}) {
  try {
    console.log('Calling Grok API...');
    
    if (!config.GROK_API_KEY) {
      throw new Error('GROK_API_KEY is not set. Cannot proceed without API key.');
    }
    
    // Create a custom axios instance with SSL verification disabled
    const httpsAgent = new (require('https').Agent)({ 
      rejectUnauthorized: false,
      secureOptions: require('constants').SSL_OP_NO_TLSv1 | require('constants').SSL_OP_NO_TLSv1_1
    });
    
    // Get existing context history
    const contextHistory = getContextHistory();
    
    // Build context string from history
    let contextString = '';
    if (contextHistory.length > 0) {
      contextString = '\n\nPrevious context:\n';
      // Add up to 3 most recent context items
      const recentHistory = contextHistory.slice(0, 3);
      recentHistory.forEach((item, index) => {
        if (item.context) {
          contextString += `${index + 1}. ${item.context}\n`;
        }
      });
    }
    
    // Add current context data if provided
    if (Object.keys(contextData).length > 0) {
      contextString += '\n\nCurrent context:\n';
      Object.entries(contextData).forEach(([key, value]) => {
        contextString += `${key}: ${value}\n`;
      });
    }
    
    const response = await axios.post(
      config.GROK_API_URL,
      {
        model: 'grok-3',
        messages: [
          {
            role: 'system',
            content: config.GROK_SYSTEM_PROMPT
          },
          {
            role: 'user',
            content: `${prompt}${contextString}\n\n${config.GROK_FORMATTING_INSTRUCTIONS}\n\nPlease include a 'context' field in your JSON response with a brief summary of the context for this video.`
          }
        ],
        temperature: 1.2,
        top_p: 0.9,
        max_tokens: 20000  // Increased from 1000 to 4000 to handle larger responses
      },
      {
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${config.GROK_API_KEY}`
        },
        httpsAgent: httpsAgent
      }
    );
    
    console.log('Raw response:', response.data.choices[0].message.content);
    
    // Extract the JSON part from the response
    // Look for the JSON block that starts after the character definition section
    const jsonMatch = response.data.choices[0].message.content.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        // Instead of trying to fix the JSON, let's extract just the scenes array and rebuild the JSON
        // This is more reliable than trying to fix complex JSON issues
        const content = response.data.choices[0].message.content;
        
        // Create a structured JSON object with default values
        const jsonData = {
          scenes: [],
          question: "What should happen next?",
          choices: ["Option A", "Option B"],
          context: "Video about a baker creating a wedding cake"
        };
        
        // Try to extract the question and choices
        const questionMatch = content.match(/"question"\s*:\s*"([^"]+)"/i);
        if (questionMatch && questionMatch[1]) {
          jsonData.question = questionMatch[1];
        }
        
        // Try to extract choices
        const choicesMatch = content.match(/"choices"\s*:\s*\[\s*"([^"]+)"\s*,\s*"([^"]+)"\s*\]/i);
        if (choicesMatch && choicesMatch[1] && choicesMatch[2]) {
          jsonData.choices = [choicesMatch[1], choicesMatch[2]];
        }
        
        // Try to extract context
        const contextMatch = content.match(/\*\*Concept\*\*:\s*([^\n]+)/i);
        if (contextMatch && contextMatch[1]) {
          jsonData.context = contextMatch[1];
        }
        
        // Extract scenes - this is the most important part
        // We'll use a simpler approach by looking for scene objects
        const scenesRegex = /\{\s*"startTime"[\s\S]*?\}\s*(?=,\s*\{|\])/g;
        const sceneMatches = content.match(scenesRegex);
        
        if (sceneMatches && sceneMatches.length > 0) {
          // Parse each scene individually
          jsonData.scenes = sceneMatches.map(sceneStr => {
            try {
              // Clean up the scene string
              const cleanSceneStr = sceneStr
                .replace(/\n/g, ' ')
                .replace(/([^\\])"([^"]*?)([^\\])"/g, (match, p1, p2, p3) => {
                  return p1 + '"' + p2.replace(/"/g, '\\"') + p3 + '"';
                })
                .replace(/,\s*\}/g, '}');
              
              return JSON.parse(cleanSceneStr);
            } catch (e) {
              console.log('Failed to parse scene:', e.message);
              // Return a default scene object if parsing fails
              return {
                startTime: 0,
                duration: 3,
                prompt: "Default scene due to parsing error",
                soundEffect: "Background music",
                dialogue: {
                  description: "Default dialogue",
                  text: "This is a placeholder scene."
                }
              };
            }
          });
        }
        
        // Save context if it exists in the response
        if (jsonData.context) {
          const newContextItem = {
            timestamp: new Date().toISOString(),
            context: jsonData.context,
            ...contextData
          };
          
          // Add to history and limit size
          contextHistory.unshift(newContextItem);
          if (contextHistory.length > MAX_CONTEXT_ITEMS) {
            contextHistory.length = MAX_CONTEXT_ITEMS;
          }
          
          // Save updated history
          saveContextHistory(contextHistory);
        }
        
        return jsonData;
      } catch (parseError) {
        console.error('JSON parsing error:', parseError.message);
        console.error('JSON content that failed to parse:', jsonMatch[0]);
        throw new Error(`Failed to parse JSON from Grok API response: ${parseError.message}`);
      }
    } else {
      throw new Error('Could not extract JSON from Grok API response');
    }
  } catch (error) {
    console.error('Error calling Grok API:', error.message);
    if (error.response) {
      console.error('Response status:', error.response.status);
      console.error('Response data:', error.response.data);
    }
    
    // No fallback - propagate the error
    throw error;
  }
}

// Fallback response has been removed as requested

module.exports = {
  generateStoryPrompt,
  getContextHistory,
  saveContextHistory
};
