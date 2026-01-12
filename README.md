# StepPulse 🚶‍♂️

A beautifully designed, gamified step counter app built with Flutter. Track your daily steps, earn XP, level up, and maintain streaks to stay motivated on your fitness journey.

![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart)
![License](https://img.shields.io/badge/License-MIT-green)

## ✨ Features

### 📊 Real-Time Step Tracking
- Live step count using device's pedometer sensor
- Distance calculation (km/miles)
- Calorie estimation
- Active time tracking
- Beautiful circular progress ring

### 🎮 Gamification System
- **XP Rewards**: Earn 1 XP for every 100 steps
- **Goal Bonus**: +50 XP when you hit your daily goal
- **Streak Bonus**: +10 XP per day for consecutive days
- **10 Levels**: Progress from Beginner to Master
  - Level 1: Beginner (0 XP)
  - Level 2: Walker (200 XP)
  - Level 3: Strider (500 XP)
  - Level 4: Hiker (1,000 XP)
  - Level 5: Explorer (2,000 XP)
  - Level 6: Adventurer (3,500 XP)
  - Level 7: Trailblazer (5,500 XP)
  - Level 8: Champion (8,000 XP)
  - Level 9: Legend (12,000 XP)
  - Level 10: Master (18,000 XP)

### 📈 Progress Tracking
- Activity heatmap (GitHub-style contribution graph)
- Historical step data
- Streak tracking (current & longest)
- Weekly & monthly statistics

### 🔔 Smart Notifications
- Foreground service with live step count in notification bar
- Goal achievement notifications
- Level-up celebrations

### 👤 Profile & Customization
- Custom profile photo
- Personalized name
- Daily goal setting (5,000 - 15,000 steps)
- Metric/Imperial unit toggle

## 📱 Screenshots

| Dashboard | Progress | Profile |
|-----------|----------|---------|
| Step count with progress ring | Activity heatmap | XP & Level display |

## 🛠️ Tech Stack

- **Framework**: Flutter 3.x
- **State Management**: Riverpod
- **Local Storage**: Hive
- **Step Counting**: pedometer package
- **Background Service**: flutter_foreground_task
- **Notifications**: flutter_local_notifications
- **Permissions**: permission_handler

## 📦 Project Structure

```
lib/
├── core/
│   ├── constants/      # App constants
│   └── theme/          # App theming
├── models/
│   ├── step_data.dart  # Step data model
│   └── xp_data.dart    # XP/Level data model
├── providers/
│   ├── step_provider.dart      # Step tracking state
│   ├── xp_provider.dart        # XP/gamification state
│   ├── settings_provider.dart  # User settings
│   └── history_provider.dart   # Historical data
├── screens/
│   ├── dashboard/      # Main step tracking screen
│   ├── stats/          # Statistics screen
│   ├── progress/       # Progress & heatmap screen
│   ├── profile/        # User profile screen
│   ├── onboarding/     # Onboarding flow
│   └── settings/       # Settings screen
├── services/
│   ├── step_service.dart        # Pedometer integration
│   ├── storage_service.dart     # Hive storage
│   ├── foreground_service.dart  # Background tracking
│   └── smart_notifications.dart # Notification logic
└── widgets/            # Reusable widgets
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK 3.x or higher
- Dart 3.x or higher
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/aniketapai/StepPulse.git
   cd StepPulse
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Run the app**
   ```bash
   flutter run
   ```

### Platform-Specific Setup

#### Android
Add the following permissions to `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.ACTIVITY_RECOGNITION" />
<uses-permission android:name="android.permission.FOREGROUND_SERVICE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

#### iOS
Add the following to `ios/Runner/Info.plist`:
```xml
<key>NSMotionUsageDescription</key>
<string>StepPulse needs access to motion data to count your steps.</string>
<key>UIBackgroundModes</key>
<array>
    <string>processing</string>
</array>
```

## 🎯 Roadmap

- [ ] Apple Health / Google Fit integration
- [ ] Achievements & badges system
- [ ] Social features & challenges
- [ ] Weekly/monthly challenges
- [ ] Widget support
- [ ] Apple Watch / Wear OS companion app
- [ ] Cloud sync & backup

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👨‍💻 Author

**Aniket Pai**

- GitHub: [@aniketapai](https://github.com/aniketapai)

---

<p align="center">
  Made with ❤️ and Flutter
</p>
