# Poker Manager

A cross-platform mobile application for managing poker games, buy-ins, cash-outs, and settlements.

## Features

- User authentication and profile management
- Create and manage poker groups
- Schedule games with recurring options
- Track multiple buy-ins per player
- Smart settlement calculation to minimize payments
- Player statistics and leaderboards
- Location selection from group member addresses

## Tech Stack

- **Frontend**: Flutter
- **Backend**: Supabase (PostgreSQL)
- **State Management**: Riverpod
- **Routing**: GoRouter
- **Local Storage**: Drift

## Setup Instructions

### Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK
- A Supabase account

### 1. Clone the Repository

```bash
git clone <your-repo-url>
cd poker_manager
```

### 2. Install Dependencies

```bash
flutter pub get
```

### 3. Set Up Supabase

1. Create a new project at [supabase.com](https://supabase.com)
2. Copy your project URL and anon key
3. Create a `.env` file in the root directory:

```env
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
```

### 4. Run Database Migrations

Execute the SQL scripts in the following order in your Supabase SQL editor:

1. Create tables (from technical spec section 5.1)
2. Set up RLS policies (from technical spec section 5.2)
3. Create database functions (from technical spec section 5.3)
4. Create storage buckets (from technical spec section 5.5)

### 5. Generate Code

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### 6. Run the App

```bash
flutter run
```

## Project Structure

```
lib/
├── app/              # App configuration (router, theme)
├── core/             # Core utilities and constants
├── features/         # Feature modules
│   ├── auth/         # Authentication
│   ├── profile/      # User profiles
│   ├── groups/       # Group management
│   ├── games/        # Game management
│   ├── settlements/  # Settlement calculations
│   └── statistics/   # Statistics and leaderboards
└── shared/           # Shared models and utilities
```

## Building for Production

### Android

```bash
flutter build apk --release
```

### iOS

```bash
flutter build ios --release
```

## Testing

Run unit tests:
```bash
flutter test
```

Run integration tests:
```bash
flutter test integration_test
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

MIT License

## Support

For issues and questions, please create an issue on GitHub.
