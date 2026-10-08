export function getGetAppPageHtml() {
  return `
<div class="get-app-shell">
  <div id="get-app-guest-pass" class="get-app-guest-pass hidden" hidden>
    <div class="get-app-guest-pass-inner">
      <div class="get-app-guest-watermark" aria-hidden="true">
        <img src="/assets/icone.png?v=20260808" alt="" width="120" height="120" decoding="async" />
      </div>
      <img
        src="/assets/icone.png?v=20260808"
        alt="Process"
        class="get-app-guest-icon"
        width="56"
        height="56"
        decoding="async"
      />
      <div class="get-app-guest-brand">Process</div>
      <p id="get-app-guest-label" class="get-app-guest-label">Invitation parrainage</p>
      <p id="get-app-guest-value" class="get-app-guest-value">Coach IA &amp; protocole debloat</p>
    </div>
  </div>

  <img
    id="get-app-logo-plain"
    class="get-app-logo-plain hidden"
    hidden
    height="200"
    src="/assets/icone.png?v=20260808"
    alt="Process"
    decoding="async"
  />

  <div class="get-app-hero">
    <h1 id="get-app-title" class="get-app-title">Télécharge Process et dégonfle ton visage.</h1>
    <p id="get-app-subtitle" class="get-app-subtitle">Process — coach IA &amp; protocole debloat. Sur iPhone.</p>
  </div>

  <div id="get-app-tap-hint" class="get-app-tap-hint hidden" hidden aria-hidden="true">
    <svg class="get-app-tap-arrow" viewBox="0 0 48 80" fill="none" aria-hidden="true">
      <path
        d="M24 4v52M24 4l-8 10M24 4l8 10M8 68c6 8 14 12 16 12s10-4 16-12"
        stroke="currentColor"
        stroke-width="2.5"
        stroke-linecap="round"
        stroke-linejoin="round"
      />
    </svg>
    <p id="get-app-tap-hint-text">Tap the banner to start</p>
  </div>

  <section id="get-app-steps-primary" class="get-app-steps-card hidden" hidden aria-labelledby="get-app-steps-primary-title">
    <h2 id="get-app-steps-primary-title" class="get-app-steps-heading">How to get started</h2>
    <ol class="get-app-steps-list">
      <li class="get-app-step get-app-step--qr">
        <div class="get-app-step-row">
          <span class="get-app-step-num" aria-hidden="true">1</span>
          <p id="get-app-step-qr-label" class="get-app-step-label">Scan QR Code with your iPhone</p>
        </div>
        <div id="get-app-qr-container" class="get-app-qr-wrap hidden">
          <div id="get-app-qr" class="get-app-qr-code"></div>
        </div>
      </li>
      <li class="get-app-step">
        <span class="get-app-step-num" aria-hidden="true">2</span>
        <p class="get-app-step-label">
          <span id="get-app-step-code-prefix">Your referral code is</span>
          <strong id="get-app-referral-code" class="get-app-code-strong"></strong>
        </p>
      </li>
      <li class="get-app-step">
        <span class="get-app-step-num" aria-hidden="true">3</span>
        <p id="get-app-step-benefit" class="get-app-step-label">Enjoy Process with your friend's code</p>
      </li>
    </ol>
  </section>

  <section id="get-app-steps-fallback" class="get-app-steps-card hidden" hidden aria-labelledby="get-app-steps-fallback-title">
    <h2 id="get-app-steps-fallback-title" class="get-app-steps-heading">Don't see the banner?</h2>
    <ol class="get-app-steps-list">
      <li class="get-app-step">
        <span class="get-app-step-num" aria-hidden="true">1</span>
        <div class="get-app-step-body">
          <p id="get-app-step-download-label" class="get-app-step-label">Download the app</p>
          <div class="store-download-buttons get-app-store-row">
            <button
              type="button"
              id="get-app-store-ios-fallback"
              class="store-download-btn store-download-btn--apple get-app-store-btn"
              aria-label="Download on App Store"
            >
              <svg class="store-download-btn__logo store-download-btn__logo--apple" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
                <path fill="currentColor" d="M16.7 12.4c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.8-3.1.8-.7 0-1.7-.7-2.8-.7-1.4 0-2.8.9-3.5 2.2-1.5 2.6-.4 6.4 1.1 8.5.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7c1.2 0 1.9-1 2.6-2 .8-1.2 1.1-2.3 1.1-2.4-.1 0-2.2-.8-2.2-3.7zm-2-6.1c.6-.7 1-1.7.9-2.7-1 .1-2.1.6-2.8 1.4-.6.7-1.1 1.7-1 2.7 1 .1 2.1-.5 2.9-1.4z"/>
              </svg>
              <span class="store-download-btn__copy">
                <span class="store-download-btn__eyebrow">Download on</span>
                <span class="store-download-btn__name">App Store</span>
              </span>
            </button>
          </div>
        </div>
      </li>
      <li class="get-app-step">
        <span class="get-app-step-num" aria-hidden="true">2</span>
        <p class="get-app-step-label">
          <span id="get-app-step-code-prefix-fb">Your referral code is</span>
          <strong id="get-app-referral-code-fb" class="get-app-code-strong"></strong>
        </p>
      </li>
      <li class="get-app-step">
        <span class="get-app-step-num" aria-hidden="true">3</span>
        <p id="get-app-step-benefit-fb" class="get-app-step-label">Enjoy Process with your friend's code</p>
      </li>
    </ol>
  </section>

  <div id="get-app-store-plain" class="get-app-store-plain hidden" hidden>
    <div class="store-download-buttons get-app-store-row">
      <button
        type="button"
        id="get-app-store-ios"
        class="store-download-btn store-download-btn--apple get-app-store-btn"
        aria-label="Download on App Store"
      >
        <svg class="store-download-btn__logo store-download-btn__logo--apple" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path fill="currentColor" d="M16.7 12.4c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.8-3.1.8-.7 0-1.7-.7-2.8-.7-1.4 0-2.8.9-3.5 2.2-1.5 2.6-.4 6.4 1.1 8.5.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7c1.2 0 1.9-1 2.6-2 .8-1.2 1.1-2.3 1.1-2.4-.1 0-2.2-.8-2.2-3.7zm-2-6.1c.6-.7 1-1.7.9-2.7-1 .1-2.1.6-2.8 1.4-.6.7-1.1 1.7-1 2.7 1 .1 2.1-.5 2.9-1.4z"/>
        </svg>
        <span class="store-download-btn__copy">
          <span class="store-download-btn__eyebrow">Download on</span>
          <span class="store-download-btn__name">App Store</span>
        </span>
      </button>
    </div>
  </div>
</div>`;
}
