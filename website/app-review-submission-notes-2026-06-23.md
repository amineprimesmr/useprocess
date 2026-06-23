# App Review Notes — Face Data Privacy

Use these notes in App Store Connect for the next resubmission.

## Review Context

The previous review requested additional information about face data handling under Guideline 2.1 / 5.1.1. The current resubmission clarifies face data collection, consent, storage, sharing, and retention in the app and privacy policy.

## What Changed In App

- Face Scan consent screen now separates local face scan permission from optional AI photo analysis.
- The AI photo analysis toggle is OFF by default.
- Face scan data sync is blocked unless the user has accepted Face Scan consent.
- Local face scan media is stored under Application Support, excluded from iCloud backup, and protected with iOS file protection.
- Firebase sync strips local media references and never uploads the 3D mesh, JPEG, or MP4.
- Settings now show separate statuses for "Face Scan" and "Face photo to AI".
- Privacy policy face-data section was updated on June 23, 2026.

## App Review Reply

Paste the full prepared response from:

`website/app-review-face-data-reply-en.txt`

## Privacy Policy URL

https://useprocess.xyz/confidentialite#donnees-faciales

## Reviewer Demo Flow

1. Open the app.
2. Go to the Face Scan feature.
3. The Face Scan privacy screen appears before capture.
4. Keep "AI analysis of my photo" OFF to verify local-only scan behavior.
5. Run a scan and check the scores/history.
6. Go to Settings and verify:
   - Face Scan: authorized
   - Face photo to AI: disabled unless the toggle was enabled
   - Revoke Face Scan deletes local/cloud face scan history.

## Important Claims

- No face recognition or identity verification is performed.
- Apple Face ID templates are never accessed or stored by the app.
- 3D mesh and MP4 remain local only.
- JPEG remains local by default and is never uploaded to Firebase; it is sent to Anthropic only if the user explicitly enables AI photo analysis.
- Only derived scores, metadata, and optional AI text analysis sync to Firebase.
- Anthropic receives a face JPEG only when the user explicitly enables AI photo analysis.
- Face data is not used for advertising, tracking, or data mining.
