# Isolated host rendering

Opt-in command: `python3 scripts/build.py --wait :app:testDebugUnitTest -Pprocess.uiTests=true --tests com.process.android.ProcessRenderTest`. This uses Robolectric 4.17 native graphics and Compose UI tests, one JVM, one worker, two logical processors, low CPU priority inherited from the build wrapper. The test source set is `app/src/uiTest/java`; ordinary builds do not load the renderer dependencies.

Outputs go to `parity/host-render`. A generated PNG is evidence of this host rendering configuration only (API34,393x852dp,mdpi), not a captured phone or the shared emulator. Check actual screenshots and interaction assertions before recording a pass. Never use it to claim original iOS pixel/animation or physical-device parity.

Primary references: https://robolectric.org/getting-started/ , https://developer.android.com/training/testing/ui-tests/screenshot .

Current state is recorded in host-render/validation.json and test-results.xml. Latest checkpoint:72interaction/JSON tests pass,69PNG captures inspected. Captures use Android decorView.draw(Canvas(bitmap)) under native Robolectric graphics: Compose PixelCopy capture timed out waiting for a hardware frame. GPU effects,media playback,timing and physical performance remain unverified. Dialogs require an explicit host measure/layout because Robolectric has no real WindowManager traversal. Dialog PNGs contain only that window,not the underlying activity composite. The confirmation component uses a software pure-label fallback on nonaccelerated windows; retained hardware snapshots are untested.


Manual clock tests drain Android measure/draw after state-changing recomposition before sampling. Reference: https://developer.android.com/develop/ui/compose/testing/synchronization .
