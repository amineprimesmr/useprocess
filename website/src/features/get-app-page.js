export function getGetAppPageHtml() {
  return `
<div class="container get-app-container">
  <img height="200" src="/assets/icone.png?v=20260808" alt="Process" class="get-app-logo" decoding="async" />
  <div class="color-foreground">
    <div class="content">
      <h2 id="get-app-title" class="title">Dégonfle ton visage.</h2>
      <p id="get-app-subtitle" class="color-foreground-secondary subtitle">Process — coach IA &amp; protocole debloat. Télécharge sur iPhone.</p>
    </div>
    <div id="get-app-qr-container" class="qr-container hidden">
      <div id="get-app-qr" class="qr-code"></div>
    </div>
    <div class="two-buttons get-app-store-row">
      <button type="button" id="get-app-store-ios" class="get-app-store-btn get-app-store-btn--badge" aria-label="Télécharger l&apos;app sur l&apos;App Store">
        <span class="get-app-store-badge get-app-store-badge--apple">
          <svg class="get-app-store-badge__logo" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
            <path fill="currentColor" d="M16.7 12.4c0-2.1 1.7-3.1 1.8-3.2-1-1.4-2.5-1.6-3-1.6-1.3-.1-2.5.8-3.1.8-.7 0-1.7-.7-2.8-.7-1.4 0-2.8.9-3.5 2.2-1.5 2.6-.4 6.4 1.1 8.5.7 1 1.6 2.2 2.7 2.1 1.1 0 1.5-.7 2.8-.7s1.7.7 2.8.7c1.2 0 1.9-1 2.6-2 .8-1.2 1.1-2.3 1.1-2.4-.1 0-2.2-.8-2.2-3.7zm-2-6.1c.6-.7 1-1.7.9-2.7-1 .1-2.1.6-2.8 1.4-.6.7-1.1 1.7-1 2.7 1 .1 2.1-.5 2.9-1.4z"/>
          </svg>
          <span class="get-app-store-badge__copy">
            <span class="get-app-store-badge__eyebrow">Télécharger l&apos;app</span>
            <span class="get-app-store-badge__name">App Store</span>
          </span>
        </span>
      </button>
      <span class="get-app-store-badge get-app-store-badge--play get-app-store-badge--soon" role="status" aria-label="Google Play — Coming soon">
        <svg class="get-app-store-badge__logo get-app-store-badge__logo--play" viewBox="0 0 24 24" aria-hidden="true" focusable="false">
          <path fill="#EA4335" d="M3.6 2.2 13.4 12 3.6 21.8c-.4-.2-.6-.6-.6-1V3.2c0-.4.2-.8.6-1z"/>
          <path fill="#FBBC04" d="m13.4 12 2.7-2.7 4.4 2.5c.6.3.6 1.1 0 1.4l-4.4 2.5L13.4 12z"/>
          <path fill="#4285F4" d="M13.4 12 3.6 2.2c.3-.2.6-.2.9 0l11.6 6.6L13.4 12z"/>
          <path fill="#34A853" d="M13.4 12 16.1 14.7 4.5 21.8c-.3.2-.6.1-.9 0L13.4 12z"/>
        </svg>
        <span class="get-app-store-badge__copy">
          <span class="get-app-store-badge__eyebrow">Coming soon</span>
          <span class="get-app-store-badge__name">Google Play</span>
        </span>
      </span>
    </div>
  </div>
</div>`;
}
