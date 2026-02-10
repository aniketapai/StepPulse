# API Keys Configuration

This directory contains sensitive API keys that should **NEVER** be committed to version control.

## Setup

1. Copy the template file:
   ```bash
   cp lib/config/api_keys.dart.example lib/config/api_keys.dart
   ```

2. Edit `lib/config/api_keys.dart` and replace `YOUR_GEMINI_API_KEY_HERE` with your actual Gemini API key.

3. Get your Gemini API key from: https://makersuite.google.com/app/apikey

## Important

- ✅ `api_keys.dart.example` - Safe to commit (template with placeholder)
- ❌ `api_keys.dart` - **NEVER commit** (contains actual secrets, gitignored)

The `api_keys.dart` file is already added to `.gitignore` to prevent accidental commits.
