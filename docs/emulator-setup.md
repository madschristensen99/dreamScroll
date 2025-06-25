# Android Emulator Setup for YouTube Shorts Publishing

This guide will walk you through setting up an Android emulator for publishing videos to YouTube Shorts with polls using the dreamScroll application.

## Prerequisites

1. Android Studio installed on your system
2. Java Development Kit (JDK) installed
3. At least 4GB of free RAM and 10GB of free disk space

## Step 1: Install Android Studio and Android SDK

If you haven't already installed Android Studio:

1. Download Android Studio from [developer.android.com](https://developer.android.com/studio)
2. Follow the installation instructions for your operating system
3. During installation, make sure to select the "Android SDK" and "Android Virtual Device" components

## Step 2: Set Up Android SDK

1. Open Android Studio
2. Go to Tools > SDK Manager
3. In the "SDK Platforms" tab, select at least one Android version (Android 11 or newer recommended)
4. In the "SDK Tools" tab, make sure the following are installed:
   - Android SDK Build-Tools
   - Android Emulator
   - Android SDK Platform-Tools
   - Intel x86 Emulator Accelerator (HAXM) or Google USB Driver (depending on your system)
5. Click "Apply" to install the selected components

## Step 3: Create an Android Virtual Device (AVD)

1. In Android Studio, go to Tools > AVD Manager
2. Click "Create Virtual Device"
3. Select a phone device (e.g., Pixel 4) and click "Next"
4. Select a system image (Android 11 or newer recommended) and click "Next"
   - If you don't have the system image downloaded, click "Download" next to the system image
5. Configure the AVD with the following settings:
   - AVD Name: "YouTube_Emulator" (or any name you prefer)
   - Startup orientation: Portrait
   - Device Frame: Enabled
   - Memory and Storage: At least 2GB RAM and 2GB internal storage
   - Enable "Store a snapshot for faster startup" if you want faster boot times
6. Click "Finish" to create the AVD

## Step 4: Configure Environment Variables

Add Android SDK to your PATH:

### For Linux/macOS:

Add these lines to your `~/.bashrc` or `~/.zshrc`:

```bash
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/tools/bin
export PATH=$PATH:$ANDROID_HOME/platform-tools
```

Then run:

```bash
source ~/.bashrc  # or source ~/.zshrc
```

### For Windows:

1. Right-click on "This PC" or "My Computer" and select "Properties"
2. Click on "Advanced system settings"
3. Click on "Environment Variables"
4. Under "System Variables", click "New" and add:
   - Variable name: ANDROID_HOME
   - Variable value: C:\Users\YOUR_USERNAME\AppData\Local\Android\Sdk
5. Find the "Path" variable, select it, and click "Edit"
6. Click "New" and add the following paths:
   - %ANDROID_HOME%\tools
   - %ANDROID_HOME%\tools\bin
   - %ANDROID_HOME%\platform-tools

## Step 5: Install and Configure YouTube App

1. Start the emulator by opening Android Studio > AVD Manager > Play button next to your AVD
2. Once the emulator is running, open a terminal/command prompt and run:

```bash
adb install -r path/to/youtube.apk
```

If you don't have the YouTube APK, you can download it from a trusted source or use the Google Play Store on the emulator:

1. In the emulator, open the Google Play Store
2. Sign in with your Google account
3. Search for "YouTube" and install the app
4. Open the YouTube app and sign in with your Google account

## Step 6: Update Configuration for Your Emulator

Update the Appium configuration in your project to match your emulator:

1. Open `/home/remsee/dreamScroll/src/config/appium.config.js`
2. Update the Android configuration to match your emulator:

```javascript
android: {
  deviceName: 'YouTube_Emulator', // Use the name you gave your AVD
  platformName: 'Android',
  platformVersion: '11.0', // Update to match your emulator's Android version
  appPackage: 'com.google.android.youtube',
  appActivity: 'com.google.android.apps.youtube.app.WatchWhileActivity',
  automationName: 'UiAutomator2',
  noReset: true,
  fullReset: false,
  autoGrantPermissions: true
}
```

## Step 7: Test the Setup

1. Make sure your emulator is running
2. Run the test script:

```bash
cd /home/remsee/dreamScroll
node test-youtube-publish.js --video /path/to/test/video.mp4 --caption "Test video"
```

If everything is set up correctly, the script should:
1. Start the Appium server
2. Connect to your emulator
3. Open the YouTube app
4. Upload the video with a poll
5. Return the URL of the uploaded Short

## Troubleshooting

### Common Issues:

1. **Appium server fails to start**:
   - Make sure you have Appium installed globally: `npm install -g appium`
   - Check if the port is already in use: `lsof -i :4723`

2. **Cannot connect to the emulator**:
   - Make sure the emulator is running: `adb devices` should list your emulator
   - Try restarting the ADB server: `adb kill-server && adb start-server`

3. **YouTube app not found**:
   - Verify the app is installed: `adb shell pm list packages | grep youtube`
   - Check the correct package name and activity: `adb shell dumpsys package com.google.android.youtube`

4. **Authentication issues**:
   - Make sure you're signed in to the YouTube app on the emulator
   - Check that `noReset: true` is set in the Appium config to preserve the login state

5. **Video upload fails**:
   - Check that the video file exists and is a valid format
   - Ensure the emulator has internet connectivity
   - Verify that the YouTube account has upload permissions

For more detailed troubleshooting, check the Appium logs and the application logs.
