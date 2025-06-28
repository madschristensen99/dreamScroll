// Appium server management utilities
const { spawn } = require('child_process');
const axios = require('axios');
const path = require('path');
const appiumConfig = require('../config/appium.config');

let appiumProcess = null;

/**
 * Start the Appium server
 * @param {Object} options - Server options
 * @param {number} [options.port=4723] - Port to run the server on
 * @param {string} [options.host='localhost'] - Host to run the server on
 * @param {boolean} [options.showLogs=false] - Whether to show server logs
 * @returns {Promise<void>}
 */
async function startAppiumServer(options = {}) {
  const port = options.port || appiumConfig.server.port || 4723;
  const host = options.host || appiumConfig.server.host || 'localhost';
  const showLogs = options.showLogs || appiumConfig.server.showLogs || false;
  
  // Check if server is already running
  try {
    // Try both Appium 1.x and 2.x URL paths
    let response;
    try {
      response = await axios.get(`http://${host}:${port}/status`, { timeout: 1000 });
    } catch (e) {
      // Fall back to old URL structure
      response = await axios.get(`http://${host}:${port}/wd/hub/status`, { timeout: 1000 });
    }
    if (response.status === 200) {
      console.log(`Appium server is already running on ${host}:${port}`);
      return;
    }
  } catch (error) {
    // Server is not running, which is what we want
  }
  
  return new Promise((resolve, reject) => {
    console.log(`Starting Appium server on ${host}:${port}...`);
    
    try {
      // Find the path to the Appium executable
      const appiumPath = path.join(process.cwd(), 'node_modules', '.bin', 'appium');
      
      // Start Appium server
      appiumProcess = spawn(appiumPath, [
        '--address', host,
        '--port', port.toString(),
        '--log-level', showLogs ? 'info' : 'error'
      ]);
      
      let serverStarted = false;
      
      // Handle server output
      appiumProcess.stdout.on('data', (data) => {
        const output = data.toString();
        if (showLogs) {
          console.log(`[Appium] ${output.trim()}`);
        }
        
        // Check if server has started successfully
        if (output.includes('Appium REST http interface listener started')) {
          serverStarted = true;
          console.log(`Appium server started successfully on ${host}:${port}`);
          resolve();
        }
      });
      
      appiumProcess.stderr.on('data', (data) => {
        const output = data.toString();
        if (showLogs) {
          console.error(`[Appium Error] ${output.trim()}`);
        }
      });
      
      appiumProcess.on('error', (error) => {
        console.error('Failed to start Appium server:', error);
        reject(error);
      });
      
      appiumProcess.on('close', (code) => {
        if (!serverStarted) {
          console.error(`Appium server process exited with code ${code} before starting`);
          reject(new Error(`Appium server process exited with code ${code}`));
        }
      });
      
      // Set a timeout to check if the server started
      setTimeout(() => {
        if (!serverStarted) {
          console.log('Checking if Appium server is running...');
          // Try both Appium 1.x and 2.x URL paths
          axios.get(`http://${host}:${port}/status`, { timeout: 2000 })
            .then(response => {
              if (response.status === 200) {
                console.log(`Appium server is running on ${host}:${port}`);
                resolve();
              } else {
                reject(new Error('Appium server did not start properly'));
              }
            })
            .catch(error => {
              reject(new Error('Appium server did not start properly: ' + error.message));
            });
        }
      }, 5000);
    } catch (error) {
      console.error('Error starting Appium server:', error);
      reject(error);
    }
  });
}

/**
 * Stop the Appium server
 * @returns {Promise<void>}
 */
async function stopAppiumServer() {
  return new Promise((resolve) => {
    if (appiumProcess) {
      console.log('Stopping Appium server...');
      
      // Kill the process
      appiumProcess.kill();
      
      appiumProcess.on('close', () => {
        console.log('Appium server stopped');
        appiumProcess = null;
        resolve();
      });
      
      // Force resolve after a timeout in case the close event doesn't fire
      setTimeout(() => {
        if (appiumProcess) {
          console.log('Force stopping Appium server...');
          try {
            process.kill(appiumProcess.pid, 'SIGKILL');
          } catch (error) {
            console.error('Error force stopping Appium server:', error);
          }
          appiumProcess = null;
          resolve();
        }
      }, 5000);
    } else {
      console.log('No Appium server to stop');
      resolve();
    }
  });
}

/**
 * Check if the Appium server is running
 * @param {Object} options - Server options
 * @param {number} [options.port=4723] - Port to check
 * @param {string} [options.host='localhost'] - Host to check
 * @returns {Promise<boolean>}
 */
async function isAppiumServerRunning(options = {}) {
  const port = options.port || 4723;
  const host = options.host || 'localhost';
  
  try {
    const response = await axios.get(`http://${host}:${port}/wd/hub/status`, { timeout: 2000 });
    return response.status === 200;
  } catch (error) {
    return false;
  }
}

module.exports = {
  startAppiumServer,
  stopAppiumServer,
  isAppiumServerRunning
};
