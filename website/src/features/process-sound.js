let settingsAudio = null;
let playbackToken = 0;
let sharedAudioCtx = null;

function unlockAudioContext() {
  try {
    const Ctx = window.AudioContext || window.webkitAudioContext;
    if (!Ctx) return null;
    if (!sharedAudioCtx) sharedAudioCtx = new Ctx();
    if (sharedAudioCtx.state === "suspended") void sharedAudioCtx.resume();
    return sharedAudioCtx;
  } catch {
    return null;
  }
}

function playSuccessChime() {
  const ctx = unlockAudioContext();
  if (!ctx) return;
  const now = ctx.currentTime;
  const notes = [523.25, 659.25, 783.99, 1046.5];
  notes.forEach((freq, index) => {
    const osc = ctx.createOscillator();
    const gain = ctx.createGain();
    osc.type = "triangle";
    osc.frequency.value = freq;
    const start = now + index * 0.07;
    gain.gain.setValueAtTime(0.0001, start);
    gain.gain.exponentialRampToValueAtTime(0.22, start + 0.02);
    gain.gain.exponentialRampToValueAtTime(0.0001, start + 0.42);
    osc.connect(gain);
    gain.connect(ctx.destination);
    osc.start(start);
    osc.stop(start + 0.45);
  });
}

/** Full success sting — must be called from a click handler (autoplay). */
export function playDashboardOpen() {
  playSuccessChime();
  try {
    const audio = new Audio("/assets/sounds/revolut_pay.mp3");
    audio.preload = "auto";
    audio.volume = 1;
    void audio.play().catch(() => {});
  } catch {
    /* ignore */
  }
}

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
