export function getGetAppPageHtml() {
  return `
<div class="container get-app-container">
  <img height="200" src="/assets/icone.png?v=20260804" alt="Process" class="get-app-logo" decoding="async" />
  <div class="color-foreground">
    <div class="content">
      <h2 id="get-app-title" class="title">Dégonfle ton visage.</h2>
      <p id="get-app-subtitle" class="color-foreground-secondary subtitle">Process — coach IA &amp; protocole debloat. Télécharge sur iPhone.</p>
    </div>
    <div id="get-app-qr-container" class="qr-container hidden">
      <div id="get-app-qr" class="qr-code"></div>
    </div>
    <div class="two-buttons">
      <button type="button" id="get-app-store-ios" class="get-app-store-btn" aria-label="Télécharger sur l&apos;App Store">
        <img class="store-logo" src="/assets/get/app_store_white.svg" alt="App Store" width="120" height="40" decoding="async" />
      </button>
    </div>
  </div>
</div>`;
}
