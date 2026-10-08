# Android Firebase integration

Project: useprocess-d4385. Android app: com.process.android, app ID 1:3107027616:android:b7449b8bac87414159a7c5. Registered 8 October 2026. The downloaded client configuration is in app/google-services.json; it contains client configuration, never a server/service-account credential. The existing local debug SHA-1 was registered. Release signing/SHA and Play setup remain unverified.

Firebase BoM 35.0.0 and google-services plugin 4.5.0 resolved and compiled. Auth, Firestore and Functions dependencies are present. No Analytics dependency, automatic anonymous registration, backend rule deployment or user data mutation was performed.

ProcessFirebaseSession supplies Apple OAuth, current identity, auth flow and account-generation guards. ProcessCloudRepository reads users/{uid}, users/{uid}/debloatTrajectory, users/{uid}/welcomePlan/current; it updates only validated editable fields of an existing profile, and atomically claims a username while releasing an owned previous tag. These APIs are compiled but not wired into a finished production shell. Network auth/data paths have not been exercised with a real user. New profile creation needs the complete original Codable schema; no partial placeholder account record is written.

Read-only provider inspection returned HTTP200, Apple enabled, but clientId/Service ID absent. Android Apple web OAuth requires that Service ID, Apple web return URL and OAuth server configuration; the enabled native iOS provider alone does not prove Android login readiness. Do not replace existing Apple provider credentials without understanding the shared iOS setup. Official integration reference: https://firebase.google.com/docs/auth/android/apple . Sanitized evidence: firebase-apple-readiness.json.

Never copy Firebase app configuration, authentication services or credentials into standalone 10K component packages. Host apps supply their own services. Subscription entitlements remain server/payment owned; the Android profile editor cannot set them.

## Read-only plan decoder continuation
`loadPlan()` now returns the complete raw JSON plus a typed,account-checked calendar/task/nutrition projection. Swift dates use the2001reference epoch. Actual calendar order,length and local-day lookup are validated; unknown fields are preserved and never overwritten. Six pure model tests plus host JSON preservation/identity checks pass (`remote-plan-validation.json`). This is not a complete FaceOriginPlan decoder or a production root integration; no real user read/write or sign-in was performed.
