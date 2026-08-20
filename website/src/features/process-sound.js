let settingsAudio = null;
let playbackToken = 0;

/** Same short confirmation clip as ProcessSoundPlayer.playSettingsChange() in the app. */
export function playSettingsChange() {
  try {
    playbackToken += 1;
    const token = playbackToken;

    if (!settingsAudio) {
      settingsAudio = new Audio("/assets/sounds/revolut_pay.mp3");
      settingsAudio.preload = "auto";
    }

    const audio = settingsAudio;
    audio.pause();
    audio.currentTime = 0;
    audio.volume = 1;

    const playPromise = audio.play();
    if (playPromise?.catch) playPromise.catch(() => {});

    const maxDurationMs = 420;
    const fadeStartMs = 280;
    const fadeDurationMs = maxDurationMs - fadeStartMs;

    window.setTimeout(() => {
      if (token !== playbackToken) return;

      const steps = 8;
      const stepMs = fadeDurationMs / steps;
      let step = 0;

      const fade = window.setInterval(() => {
        if (token !== playbackToken) {
          window.clearInterval(fade);
          return;
        }
        step += 1;
        audio.volume = Math.max(0, 1 - step / steps);
        if (step >= steps) {
          window.clearInterval(fade);
          audio.pause();
          audio.volume = 1;
        }
      }, stepMs);
    }, fadeStartMs);
  } catch {
    /* ignore — autoplay blocked or missing asset */
  }
}
