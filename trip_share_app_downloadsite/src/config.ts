/**
 * App Store Configuration
 * Update these values with your actual app store IDs
 */

export const APP_CONFIG = {
  // iOS App Store - Update with your actual app ID
  // Find it at: https://apps.apple.com/app/yourappname/id{APP_ID}
  IOS_APP_ID: '1234567890',
  IOS_APP_URL: 'https://apps.apple.com/app/tripshare/id1234567890',

  // Android Google Play - Update with your actual package name
  // Find it at: https://play.google.com/store/apps/details?id={PACKAGE_NAME}
  ANDROID_PACKAGE_NAME: 'com.tripshare.app',
  ANDROID_APP_URL: 'https://play.google.com/store/apps/details?id=com.tripshare.app',

  // Custom deep link scheme for the app
  // This should match the scheme configured in your Flutter app
  DEEP_LINK_SCHEME: 'tripshare',
};
