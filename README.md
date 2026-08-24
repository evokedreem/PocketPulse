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

## Private iPhone install

The `internal` EAS profile creates an ad-hoc build for registered iPhones. It requires an active Apple Developer Program membership for signing, but it does not publish PocketPulse to the App Store or submit it for App Review.

Register the iPhone once:

```bash
npx --yes eas-cli@22.2.0 device:create
```

After registration, create the private build:

```bash
npx --yes eas-cli@22.2.0 build \
  --platform ios \
  --profile internal \
  --no-wait
```

Open the resulting private EAS installation link on the registered iPhone. Rebuild when the Apple provisioning profile expires or when adding another device.

## TestFlight release

PocketPulse uses the `production` profile in `eas.json` for a signed App Store build. It automatically increments the iOS build number and uses Expo-managed remote signing credentials. Never commit Apple or Expo credentials.

Prerequisites:

- An Expo account.
- An active Apple Developer Program membership with App Store Connect access.
- Accepted App Store Connect agreements and an app record for `com.evokedreem.pocketpulse`.

One-time account setup:

```bash
npx --yes eas-cli@22.2.0 login --browser
npx --yes eas-cli@22.2.0 project:init
git add app.json
git commit -m "chore: link Expo EAS project"
git push
```

Create the standalone iOS build and upload it to TestFlight:

```bash
npx --yes eas-cli@22.2.0 build \
  --platform ios \
  --profile production \
  --auto-submit \
  --what-to-test "Verify pulse logging, reset, vibration, and accessibility labels."
```

The first build prompts an authorized Apple Developer team member to create or select the distribution certificate, provisioning profile, and App Store Connect credentials. After processing, install PocketPulse from TestFlight; Expo Go and the VPS tunnel are not involved in the standalone app.

## Server deployment

The deployment files are intentionally committed:

- `Dockerfile` runs Expo SDK 54 and Metro for App Store Expo Go compatibility.
- `docker-compose.yml` exposes Metro only on VPS loopback and sends device traffic through the outbound Expo tunnel.
- `deploy/server-deploy.sh` safely fetches and deploys `origin/main` under a lock.
- `deploy/pocketpulse-deploy.timer` polls GitHub every 30 seconds.

The production audit gate rejects all findings except the two currently unfixed `image-size` advisories inherited from Expo SDK 54's Metro dependency. Those exact advisory URLs and dependency paths are allowlisted in `scripts/check-production-audit.cjs`; any new advisory still fails CI.

- The server waits for the matching `Expo CI` run to pass before deploying; failed SHAs are blocked.

The original native SwiftUI project remains available in Git history at tag [`swiftui-v1.0.0`](https://github.com/evokedreem/PocketPulse/tree/swiftui-v1.0.0).
