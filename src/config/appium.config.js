// Appium configuration for YouTube Shorts integration
module.exports = {
  // Appium server configuration
  server: {
    port: 4723,
    host: 'localhost',
    showLogs: false
  },
  
  // Android device/emulator configuration
  android: {
    deviceName: 'YouTube_Emulator',
    platformName: 'Android',
    platformVersion: '13.0', // Android 13 (API 33)
    appPackage: 'com.google.android.youtube',
    appActivity: 'com.google.android.youtube.HomeActivity',
    automationName: 'UiAutomator2',
    noReset: true, // Preserve app state between sessions (keeps login)
    fullReset: false, // Don't uninstall app after session
    autoGrantPermissions: true, // Automatically grant permissions
    avd: 'YouTube_Emulator' // Specify the AVD name we created
  },
  
  // YouTube app configuration
  youtube: {
    // Maximum wait time for video upload (in milliseconds)
    uploadTimeoutMs: 10 * 60 * 1000, // 10 minutes
    
    // Default poll duration in days (1, 3, or 7)
    defaultPollDurationDays: 7
  }
};
