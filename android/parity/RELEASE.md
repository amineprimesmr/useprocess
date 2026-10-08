# Process Android release preparation

The installed/debug deliverable remains a component gallery. It is not the complete Process app. Do not publish it.

## Upload signing

`scripts/setup-signing.py` prepared a candidate private RSA 2048 upload key valid until 23 February 2054. The key and properties are outside the repository under `~/Library/Application Support/Process Android Signing` (directory 0700, private files 0600). Do not add them to Git, component archives, logs or web assets. The script reuses existing material and refuses to replace an unexpected existing key.

Gradle reads the private properties at that path, or `PROCESS_ANDROID_SIGNING_FILE` when explicitly configured. `:app:signingReport` passed; the release variant resolves the candidate upload key. No release bundle was built. Public certificate: `upload-certificate.pem`; sanitized proof: `upload-signing-validation.json`. The public upload certificate is not automatically the eventual Play app-signing certificate.

The key has not been registered with Google Play. Before any eventual upload, reconcile it with any existing Play app/upload-key registration; do not replace an existing application identity. A secure owner-controlled backup of the private key is still needed before production use.

## External readiness

The existing Google account token returned 403 ACCESS_TOKEN_SCOPE_INSUFFICIENT on a read-only Play API request (`google-play-access.json`). This is evidence of insufficient token scope, not evidence that the developer account or app is absent. No Play app, track, store listing or purchase was modified.

Firebase Apple provider is enabled but has no Service ID/clientId. Android web sign-in is not ready (`FIREBASE.md`). Billing/entitlement verification, account migration, actual plan/camera/health integration, full navigation and complete visual/runtime verification remain unfinished. Do not manufacture success, grant premium locally or publish the gallery.

The reusable catalog libraries exclude the Firebase client config, host auth services and all signing material. Their build proof establishes compilation only; visual, animation and physical-device parity remain unverified.

## Native camera preview checkpoint
CameraX1.6.2/bundled ML Kit16.1.7 photo capture compiles. Actual device capture,EXIF/crop/permission/lifecycle behavior and ML inference are unverified. ARKit-equivalent3D capture/video and wellness analysis are unfinished. Review SDK privacy/Data Safety declarations and real capture consent before release. No photo was captured or uploaded during host validation.

## 8 October 2026 final overnight checkpoint

69 of 200 selected catalog entries have compiled partial Android previews; 131 remain pending and zero have complete fidelity evidence. 196 unit tests and 68 host UI tests pass; 65 software-rendered captures were inspected. Lint reports 0 errors and 48 warnings. The 70 independent package builds include one private prototype outside catalog coverage. The debug gallery is not a releasable Process application.

PDF instrumentation builds against the current app but has not run on device. Actual QR inference, front-camera capture, hardware PixelCopy, paired iOS/Android images and animation timing remain unverified. No store upload, release bundle, purchase, real sign-in, SMS or photo upload was performed. Web/MCP delivery passes 34 tests and a local production build/HTTP check, but is not deployed. The catalog release gate rejects the current state as intended; see `/Users/amine/Desktop/10kdesign/android/parity/release-readiness.json`.

## Reproducible resumption

`native-checkpoint.json` seals current native source/resource/test hashes and local debug/test APK hashes. Debug outputs contain gallery fixtures and are for development only. Firebase configuration and private signing properties are excluded from this integrity report.

From this Android project, use the existing shared build wrapper for all compilations:

```sh
python3 scripts/build.py --wait :app:assembleDebug :app:testDebugUnitTest :app:lintDebug
python3 scripts/build.py --wait :app:testDebugUnitTest -Pprocess.uiTests=true --tests com.process.android.ProcessRenderTest
```

Run these sequentially, preserve the host test XML before the ordinary unit-test task overwrites its output, and inspect captures after relevant changes. `:app:assembleDebugAndroidTest` compiles the existing device PDF tests; it does not execute them. Do not run connected tests while the other chat owns the emulator. The catalog export/independent validation/web workflow remains in 10K Design `android/DELIVERY.md`.
