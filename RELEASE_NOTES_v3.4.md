# StepPulse v3.4

## 🎯 What's New

### 🔒 Security Enhancement
- **API Key Protection**: Gemini API key now stored in a gitignored config file to prevent exposure on GitHub
- Created setup instructions for new developers

### 📱 Responsive Design Improvements
- **Dashboard**: All elements now scale properly based on screen size (works great on both small and large screens)
- **Bottom Navigation**: Improved spacing and margins for better appearance on all devices
- Fixed profile button edge spacing issue on smaller screens

### ⚡ Performance & UX Improvements
- **Removed All Animations**: Instant navigation everywhere for snappier experience
  - Profile screen loads instantly
  - Leaderboard user profiles open without delay
  - Fitness chat navigation is immediate
- **Smoother Experience**: No more fade-in delays across the app

### 🗺️ GPS Tracking Fix
- **Background Tracking**: GPS now continues tracking even when screen is off
- Walks will show smooth paths instead of straight lines
- Implemented Android-specific location settings with:
  - 3-second interval updates
  - Foreground notification during walks
  - Wake lock to keep GPS active

## 📝 Technical Details

**Changed Files:**
- Dashboard & navigation responsiveness
- Profile screen animation removal
- GPS service background tracking configuration
- API key configuration structure

**Version**: 3.4.0 (Build 21)

## 🐛 Known Issues
- None reported

## 📥 Installation

Download the APK below and install on your Android device.

**Note**: You may need to enable "Install from Unknown Sources" in your device settings.
