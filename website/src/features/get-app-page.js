export function getGetAppPageHtml() {
  return `
<div class="container get-app-container">
  <div id="get-app-lang-host" class="get-app-lang-host"></div>
  <img height="200" src="/assets/icone.png?v=20260808" alt="Process" class="get-app-logo" decoding="async" />
  <div class="color-foreground">
    <div class="content">
      <h2 id="get-app-title" class="title">Téléchargez Process et dégonflez votre visage.</h2>
      <p id="get-app-subtitle" class="color-foreground-secondary subtitle">Process — coach IA &amp; protocole debloat. Télécharge sur iPhone.</p>
      <p id="get-app-referral-banner" class="get-app-referral-banner hidden" hidden>
        <span class="get-app-referral-eyebrow">Invitation parrainage</span>
        <span id="get-app-referral-code" class="referral-code"></span>
      </p>
    </div>
    <div id="get-app-qr-container" class="qr-container hidden">
      <div id="get-app-qr" class="qr-code"></div>
    </div>
    <div class="store-download-buttons get-app-store-row">
      <button type="button" id="get-app-store-ios" class="store-download-btn store-download-btn--apple get-app-store-btn" aria-label="Télécharger sur App Store">
        <svg class="store-download-btn__logo store-download-btn__logo--apple" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path fill="currentColor" d="M16.7 12.4c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.8-3.1.8-.7 0-1.7-.7-2.8-.7-1.4 0-2.8.9-3.5 2.2-1.5 2.6-.4 6.4 1.1 8.5.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7c1.2 0 1.9-1 2.6-2 .8-1.2 1.1-2.3 1.1-2.4-.1 0-2.2-.8-2.2-3.7zm-2-6.1c.6-.7 1-1.7.9-2.7-1 .1-2.1.6-2.8 1.4-.6.7-1.1 1.7-1 2.7 1 .1 2.1-.5 2.9-1.4z"/>
        </svg>
        <span class="store-download-btn__copy">
          <span class="store-download-btn__eyebrow">Télécharger sur</span>
          <span class="store-download-btn__name">App Store</span>
        </span>
      </button>
    </div>
  </div>
</div>`;
}
