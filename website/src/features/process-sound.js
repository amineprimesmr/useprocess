let settingsAudio = null;
let playbackToken = 0;
let sharedAudioCtx = null;
let unlockClip = null;

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

/** Unlock the confirmation clip from a click so it can play after an await. */
export function armSettingsChange() {
  try {
    unlockAudioContext();
    if (!unlockClip) {
      unlockClip = new Audio("/assets/sounds/revolut_pay.mp3");
      unlockClip.preload = "auto";
    }
    unlockClip.muted = true;
    unlockClip.volume = 0;
    const primed = unlockClip.play();
    if (primed?.then) {
      primed
        .then(() => {
          unlockClip.pause();
          unlockClip.currentTime = 0;
        })
        .catch(() => {});
    }

    if (!settingsAudio) {
      settingsAudio = new Audio("/assets/sounds/revolut_pay.mp3");
      settingsAudio.preload = "auto";
    }
    const audio = settingsAudio;
    const tokenAtArm = playbackToken;
    audio.muted = true;
    audio.volume = 0;
    const unlock = audio.play();
    if (unlock?.then) {
      unlock
        .then(() => {
          if (playbackToken !== tokenAtArm) return;
          audio.pause();
          audio.currentTime = 0;
          audio.muted = false;
          audio.volume = 1;
        })
        .catch(() => {
          audio.muted = false;
          audio.volume = 1;
        });
    } else {
      audio.muted = false;
      audio.volume = 1;
    }
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
    audio.muted = false;
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
