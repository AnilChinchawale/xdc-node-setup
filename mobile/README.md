# XDC Node Monitor - Mobile App

A React Native / Expo companion app for monitoring and managing XDC Network nodes.

## Features

- 📊 **Dashboard** - Overview of all nodes with key metrics
- 🖥️ **Node Management** - View detailed node status, restart, add peers
- 🔔 **Alerts** - Real-time notifications for node issues
- 🔐 **Biometric Auth** - Secure access with Face ID / fingerprint
- 📱 **Widgets** - Home screen widgets for quick status (coming soon)

## Quick Start

### Prerequisites

- Node.js 18+
- npm or yarn
- Expo CLI: `npm install -g expo-cli`
- iOS Simulator (Mac) or Android Studio / physical device

### Installation

```bash
cd mobile
npm install
```

### Development

```bash
# Start development server
npm start

# Run on iOS
npm run ios

# Run on Android
npm run android
```

### Configuration

1. Open Settings in the app
2. Set your SkyNet API endpoint
3. Enable push notifications for alerts
4. Optionally enable biometric authentication

## Architecture

```
mobile/
├── app/                    # Expo Router pages
│   ├── (tabs)/            # Tab navigation screens
│   │   ├── index.tsx      # Dashboard
│   │   ├── nodes.tsx      # Node list
│   │   ├── alerts.tsx     # Alert center
│   │   └── settings.tsx   # App settings
│   ├── node/[id].tsx      # Node detail screen
│   └── _layout.tsx        # Root layout
├── components/            # Reusable UI components
├── lib/
│   └── api.ts            # SkyNet API client
├── hooks/                # Custom React hooks
├── store/                # Zustand state management
├── types/                # TypeScript definitions
└── docs/                 # Documentation
```

## API Integration

The app connects to the SkyNet API for node management. See `lib/api.ts` for available endpoints.

### Authentication

API authentication uses Bearer tokens. Store your API key in app settings.

### Real-time Updates

Data auto-refreshes every 30 seconds (configurable). Pull-to-refresh available on all screens.

## Building for Production

```bash
# Build for iOS
eas build --platform ios

# Build for Android
eas build --platform android
```

## Documentation

- [Mobile App Design Document](docs/MOBILE-APP.md)
- [API Reference](../docs/API.md)
- [Contributing Guide](../CONTRIBUTING.md)

## License

MIT - Part of [XDC-Node-Setup](https://github.com/AnilChinchawale/xdc-node-setup)
