# TripGenie

AI-powered travel planning app built with Flutter and Google's Gemini AI.

## Features

- 🔍 **Smart Destination Search** - Search any destination and get AI-curated tourist attractions with ratings, reviews, and opening hours
- 🗺️ **Google Maps Integration** - Get directions to any place with one tap
- 🔖 **Bookmarking** - Save your favorite places for later
- 💰 **Expense Tracking** - Track your travel expenses by category with visual pie chart breakdown
- 🔑 **Secure API Key Management** - Enter your Gemini API key on first launch (stored locally)

## Getting Started

### Prerequisites

- Flutter SDK (^3.10.3)
- A Gemini API key from [Google AI Studio](https://aistudio.google.com/)

### Installation

1. Clone the repository
2. Run `flutter pub get` to install dependencies
3. Run `flutter run` to launch the app
4. Enter your Gemini API key when prompted

### Building

```bash
# Android
flutter build apk

# iOS
flutter build ios
```

## Project Structure

```
lib/
├── main.dart              # App entry point
├── models/
│   ├── place.dart         # Place data model
│   └── expense.dart       # Expense data model
├── screens/
│   ├── api_key_setup_screen.dart
│   ├── home_screen.dart
│   ├── planner_screen.dart
│   ├── saved_screen.dart
│   └── expenses_screen.dart
├── services/
│   ├── gemini_service.dart    # Gemini AI integration
│   └── storage_service.dart   # Local storage (SharedPreferences)
└── widgets/
    ├── place_card.dart
    ├── expense_form.dart
    └── expense_chart.dart
```

## Dependencies

- `google_generative_ai` - Gemini AI SDK
- `shared_preferences` - Local data persistence
- `fl_chart` - Pie chart visualization
- `url_launcher` - Open maps URLs
- `uuid` - Generate unique IDs
