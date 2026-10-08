# Process — physical-device testing

Follow the user's Mac performance rule: never build, boot, launch, or test on an iOS/iPadOS simulator. Use only the physical iPhone 14 Pro Max, announce the device build beforehand, and let the user perform UI/payment checks.

Run one build at a time with limited parallelism. If the Mac slows down, stop agent-started builds first. Preserve the existing source changes, signing configuration, credentials, and billing data when cleaning generated artifacts.

Use low CPU priority (`nice -n 15`) and `xcodebuild -jobs 1` for physical-device builds. Reuse the existing device cache; do not run another build concurrently.
