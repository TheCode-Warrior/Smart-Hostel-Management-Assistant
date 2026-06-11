# Mess Management Cloud Functions

This folder contains Cloud Functions for generating mess tokens and validating them.

Functions:
- `generateMealTokens` (scheduled): generates tokens for eligible students.
- `validateMessToken` (callable): validates a scanned QR and atomically marks it used.

Local development:
- Install dependencies: `npm install`
- Run emulator: `firebase emulators:start --only functions`
- Deploy: `firebase deploy --only functions`
