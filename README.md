# PocketPulse

PocketPulse is a small Expo/React Native app built to verify this live-development path:

**GitHub → Hostinger VPS → Expo tunnel → Expo Go on iPhone**

The app records taps, animates the pulse display, uses iPhone vibration feedback, and includes accessibility labels. Source changes pushed to `main` are pulled by the VPS every 30 seconds. Metro sees ordinary TypeScript changes without restarting the tunnel; dependency or Expo configuration changes trigger a container rebuild.

## Open it on iPhone

1. Install [Expo Go from the App Store](https://apps.apple.com/app/expo-go/id982107779).
2. Open the active `exp://` link supplied with the deployment, or scan its QR code.
3. Keep Expo Go open while editing and pushing changes; Metro refreshes the JavaScript bundle after the VPS pulls the commit.

## Local development

```bash
npm ci --ignore-scripts
npm start
```

For a device outside the computer's local network:

```bash
npm run start:tunnel
```

## Verification

```bash
npm run typecheck
npm run lint
npm test -- --runInBand
npm run doctor
```

## Server deployment

The deployment files are intentionally committed:

- `Dockerfile` runs Expo SDK 57 and Metro.
- `docker-compose.yml` exposes Metro only on VPS loopback and sends device traffic through the outbound Expo tunnel.
- `deploy/server-deploy.sh` safely fetches and deploys `origin/main` under a lock.
- `deploy/pocketpulse-deploy.timer` polls GitHub every 30 seconds.
- The server waits for the matching `Expo CI` run to pass before deploying; failed SHAs are blocked.

The original native SwiftUI project remains available in Git history at tag [`swiftui-v1.0.0`](https://github.com/evokedreem/PocketPulse/tree/swiftui-v1.0.0).
