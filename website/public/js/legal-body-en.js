window.LEGAL_BODY_EN = {
  "/cgu": `
      <p class="meta">Last updated: August 17, 2026</p>

      <p>
        These terms govern access to and use of the mobile application
        <strong>Process AI</strong> ("the App"), the website <strong>useprocess.xyz</strong>,
        and <strong>Process Studio</strong> (<a href="https://useprocess.xyz/studio">/studio</a>),
        published by <strong>Process</strong>.
        By downloading or using these services, you agree to these terms.
      </p>

      <h2>1. Purpose</h2>
      <p>
        Process AI is a wellness and fitness tracking application offering an AI coach,
        health tracking (including via Apple Health), body/face scans, and personalized
        programs. The App does not replace professional medical advice.
      </p>
      <p>
        <strong>Process Studio</strong> is the creator web tool on useprocess.xyz that lets you
        connect one or more TikTok accounts (OAuth Login Kit), publish photo carousels
        via the TikTok Content Posting API, and view public stats / posts to analyze performance.
        You remain responsible for published content and compliance with TikTok rules.
      </p>

      <h2>2. Account</h2>
      <ul>
        <li>You may create an account using Sign in with Apple.</li>
        <li>You are responsible for the security of your device and session.</li>
        <li>You can delete your account from the App settings.</li>
      </ul>

      <h2>3. Subscriptions</h2>
      <p>
        Some features require a paid subscription managed by Apple (In-App Purchase).
        Payment is charged to your Apple account. Renewal is automatic unless canceled
        at least 24 hours before the end of the current period, via Settings &gt; Apple ID &gt; Subscriptions.
      </p>
      <p>
        Prices, free trial durations, and promotional terms are displayed in the App
        before any purchase. Restore purchases is available from the paywall or iOS Settings.
      </p>

      <h2>4. Acceptable use</h2>
      <p>You agree not to:</p>
      <ul>
        <li>Use the App for illegal or fraudulent purposes.</li>
        <li>Attempt to bypass security measures or access systems without authorization.</li>
        <li>Copy, decompile, or resell the App or its content.</li>
        <li>Use the App as a substitute for medical diagnosis or treatment.</li>
      </ul>

      <h2>5. AI coach</h2>
      <p>
        Coach responses are generated automatically for informational and motivational purposes.
        They may contain errors. If you have health concerns, consult a qualified professional.
      </p>

      <h2>6. Health data</h2>
      <p>
        Access to HealthKit and sensors (camera, motion) requires your explicit consent.
        Process AI does not request access to your device's GPS location.
        You can revoke these permissions at any time in iOS Settings.
        See our <a href="/confidentialite">privacy policy</a>.
      </p>

      <h2>7. Intellectual property</h2>
      <p>
        The App, its brand, design, text, and algorithms are protected.
        No license is granted beyond personal use as intended by these terms.
      </p>

      <h2>8. Availability</h2>
      <p>
        We strive to provide reliable service but do not guarantee uninterrupted availability.
        Updates, maintenance, or interruptions may occur.
      </p>

      <h2>9. Limitation of liability</h2>
      <p>
        To the extent permitted by law, Process shall not be liable for indirect damages
        related to use of the App. Our total liability is limited to the amount paid by you
        over the past 12 months, if any.
      </p>

      <h2>10. Termination</h2>
      <p>
        You may stop using the App at any time. We may suspend or terminate access
        in case of a material violation of these terms.
      </p>

      <h2>11. Governing law</h2>
      <p>
        These terms are governed by French law. In case of dispute, and absent amicable resolution,
        French courts shall have jurisdiction, subject to mandatory consumer protection rules.
      </p>

      <h2>12. Contact</h2>
      <p>
        <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a> —
        <a href="/support">Support page</a>
      </p>
`,

  "/confidentialite": `
      <p class="meta">Last updated: August 17, 2026</p>

      <p>
        This policy describes how <strong>Process AI</strong> ("the App," "we")
        collects, uses, shares, and retains your data when you use the iOS mobile application
        available on the App Store, the website <a href="https://useprocess.xyz">useprocess.xyz</a>,
        and <strong>Process Studio</strong> (<a href="https://useprocess.xyz/studio">/studio</a>),
        the TikTok publishing / analytics web tool.
      </p>

      <h2>1. Data controller</h2>
      <p>
        Publisher: <strong>Process</strong><br>
        Contact: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a><br>
        Website: <a href="https://useprocess.xyz">useprocess.xyz</a>
      </p>

      <h2>2. Data collected</h2>
      <p>Depending on the features you use, we may process:</p>
      <ul>
        <li><strong>Account</strong>: Apple identifier (Sign in with Apple), relay email address if applicable, first name.</li>
        <li><strong>Profile</strong>: goals, fitness and nutrition preferences, onboarding responses.</li>
        <li><strong>Health data</strong> (with your HealthKit authorization): activity, sleep, heart rate, calories, steps, etc.</li>
        <li><strong>Facial data</strong> (with your authorization — see section 3): ARKit facial geometry, temporary facial coefficients, local photo, short local video, derived scores.</li>
        <li><strong>Physical activity</strong> (motion sensors, if authorized).</li>
        <li><strong>AI coach</strong>: messages exchanged with the assistant (see section 4).</li>
        <li><strong>Audio</strong> (if authorized): voice dictation converted to text on-device.</li>
        <li><strong>Subscription</strong>: subscription status via Apple and RevenueCat (we do not collect payment card data).</li>
        <li><strong>Technical</strong>: session identifiers, error logs, app version.</li>
        <li><strong>Process Studio / TikTok</strong> (if you connect TikTok via OAuth Login Kit): see section 2bis.</li>
      </ul>

      <h2 id="tiktok-studio">2bis. Process Studio and TikTok data</h2>
      <p>
        Process Studio (<a href="https://useprocess.xyz/studio">https://useprocess.xyz/studio</a>) is a creator web tool
        hosted on the <strong>useprocess.xyz</strong> domain. When you click
        "Connect with TikTok," you authorize Process via the official TikTok Login Kit.
      </p>
      <p>Depending on the scopes you approve, we may process:</p>
      <ul>
        <li><strong>TikTok identity</strong> (<code>user.info.basic</code> / <code>user.info.profile</code>): open_id, avatar, display name, username, bio, profile link.</li>
        <li><strong>Profile statistics</strong> (<code>user.info.stats</code>): follower count, following count, likes, and public video count.</li>
        <li><strong>Video list</strong> (<code>video.list</code>): metadata and metrics for public posts (views, likes, comments, shares) for performance analysis.</li>
        <li><strong>Publishing</strong> (<code>video.upload</code> / <code>video.publish</code>): sending photo carousels to the TikTok account you connected, only after your explicit action in Studio.</li>
        <li><strong>OAuth tokens</strong>: access_token / refresh_token stored in a signed HttpOnly session cookie on useprocess.xyz (no TikTok password).</li>
      </ul>
      <p>
        Purposes: publish Process educational content, display your stats and posts to help you
        optimize your accounts, and secure the session. We do not sell your TikTok data.
        You can disconnect an account (token revocation) at any time from Studio.
        Deletion / rights requests: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a>.
      </p>
      <p>
        OAuth redirect domain: <strong>useprocess.xyz</strong>
        (<code>https://useprocess.xyz/tiktok/callback</code>). No localhost redirects in production.
      </p>
      <p>
        <strong>GPS location:</strong> Process AI does not collect your geographic location.
        No location data is requested or transmitted by the application.
      </p>

      <h2 id="donnees-faciales">3. Facial data</h2>
      <p>
        If you choose to use the face scan, the App uses <strong>ARKit Face Tracking</strong>
        with the front camera (Face ID sensor) to estimate indicators
        relative to your own baseline.
        <strong>No biometric identity recognition</strong> (unlock, facial biometric authentication,
        person identification, identity verification) is performed
        as part of the face scan. The App does not access Apple's Face ID models and does not create
        a biometric identification model.
      </p>

      <h3>3.1 Information collected via ARKit Face Tracking</h3>
      <ul>
        <li><strong>ARKit facial geometry</strong>: vertex positions, triangles, and texture coordinates of the 3D face mesh. This geometry is processed on-device; only the latest reference mesh may be kept locally to display the baseline and trends.</li>
        <li><strong>Temporary ARKit facial coefficients</strong>: <code>blendShapes</code> values used during the scan (e.g., cheeks, eye blink/squint, eyebrows, jaw opening, mouth frown) to compute wellness scores. These coefficients are not sent to Firebase or stored as persistent raw data.</li>
        <li><strong>Camera image</strong>: a JPEG photo of the face during the scan, stored locally on the device. It may be sent to Anthropic only if you explicitly enable AI photo analysis.</li>
        <li><strong>Short video</strong>: local recording of the scan, stored only on the device and not uploaded to Firebase.</li>
        <li><strong>Capture metadata</strong>: angular coverage of the scan, scan identifier, date/time, scan quality/confidence.</li>
        <li><strong>Derived wellness scores</strong>: relative daily score, puffiness, dark circles/fatigue, jaw tension, skin clarity, scan confidence, and technical alignment/symmetry reference (0–100 scale, without morphology judgment).</li>
        <li><strong>Metadata</strong>: scan date, scores, sleep/HRV at scan time if HealthKit is authorized.</li>
      </ul>

      <h3>3.2 Uses</h3>
      <ul>
        <li>Personalized wellness tracking and trend comparison over time, relative to your personal baseline.</li>
        <li>Sync across your devices via your account.</li>
        <li>Coach context enrichment (scores, not the photo, unless you authorize AI photo analysis — see 3.3).</li>
        <li><strong>Optional AI analysis</strong>: if you explicitly enable the option in the App (disabled by default), the scan photo may be sent to Anthropic (Claude) to generate wellness analysis text.</li>
      </ul>

      <h3>3.3 Sharing and storage</h3>
      <ul>
        <li><strong>On your iPhone/iPad</strong>: the latest reference 3D mesh, JPEG photo, and short video are stored in the App folder (Application Support), excluded from iCloud backup by the App and protected by iOS file protections.</li>
        <li><strong>Cloud</strong>: if you are signed in, only wellness scores, metadata, and any AI analysis text are synced to <strong>Google Firebase Firestore</strong> (<code>faceScans</code> collection), linked to your account identifier. <strong>The 3D mesh, JPEG photo files, and video are not uploaded to Firebase</strong> — they remain on your device.</li>
        <li><strong>Anthropic (Claude)</strong>: only if you have enabled the face scan AI analysis option — the JPEG photo and associated scores are transmitted via our <strong>Firebase Cloud Functions</strong> (proxy). Anthropic processes this data to produce the requested text analysis. Under Anthropic's commercial terms, API data is not used to train their models.</li>
      </ul>

      <h3>3.4 Retention period</h3>
      <ul>
        <li><strong>Local and cloud history</strong>: up to <strong>90 scans</strong> per account (oldest are automatically deleted, including on Firebase Firestore).</li>
        <li><strong>Local mesh, photos, and videos</strong>: deleted when the scan falls out of history (90) or when you revoke face scan consent in settings.</li>
        <li><strong>Account deletion</strong>: all facial data associated with the account is deleted within <strong>30 days</strong> of your request.</li>
        <li><strong>Consent revocation</strong>: via Settings → Privacy → "Revoke face scan" — removes history, local media, and associated cloud data.</li>
        <li><strong>AI analysis</strong>: analysis text is stored with the scan; the photo sent to Anthropic is processed for the current request (Anthropic retention policy applies).</li>
      </ul>

      <blockquote>
        <strong>Excerpt — facial data collection and use:</strong>
        "If you choose to use the face scan, the App collects via ARKit Face Tracking
        3D facial geometry, temporary facial coefficients, a JPEG photo, an optional short video,
        and derived wellness scores. Except for optional AI analysis you explicitly enable,
        the mesh, photos, and videos remain on your device; if you are signed in, only scores, metadata,
        and any AI analysis text are synced to Firebase Firestore. If you explicitly authorize
        AI analysis, the photo may be sent to Anthropic (Claude) via Firebase Cloud
        Functions. No identity recognition is performed. Retention: max. 90 scans;
        deletion within 30 days after account deletion."
      </blockquote>

      <h2 id="intelligence-artificielle">4. Third-party artificial intelligence (Anthropic Claude)</h2>
      <p>
        The App integrates an AI coach and AI features. <strong>Before sending any personal data
        to a third-party AI service, the App asks for your explicit consent</strong>
        (dedicated "AI Coach" screen). You can refuse or revoke this consent in settings.
      </p>

      <h3>4.1 Provider</h3>
      <p>
        <strong>Anthropic PBC</strong> — <strong>Claude</strong> model (conversational and vision AI).<br>
        Transmission via <strong>Google Firebase Cloud Functions</strong> (secure proxy; API key on server side).<br>
        Anthropic policy: <a href="https://www.anthropic.com/privacy" target="_blank" rel="noopener noreferrer">anthropic.com/privacy</a>
      </p>

      <h3>4.2 Data that may be sent (with your consent)</h3>
      <ul>
        <li>Written or dictated messages to the coach and conversation history.</li>
        <li>Profile: first name, age, gender, goals, fitness, nutrition, onboarding responses.</li>
        <li>HealthKit summaries: steps, sleep, heart rate, HRV, readiness score.</li>
        <li>Scan scores (face, posture) and aggregated history.</li>
        <li>Photos you voluntarily send (coach, meals, face scan if AI option enabled).</li>
      </ul>

      <h3>4.3 Purposes</h3>
      <ul>
        <li>Personalized coach responses.</li>
        <li>Protocol generation and summarization.</li>
        <li>Meal suggestions and food image analysis.</li>
        <li>Optional wellness analyses (face/body scan).</li>
      </ul>

      <h3>4.4 Equivalent protection</h3>
      <p>
        We select Anthropic as a processor offering appropriate contractual and
        technical safeguards (encryption in transit, commercial API terms, non-use of
        API data for model training under their terms). Standard contractual clauses
        apply for transfers outside the EU where applicable.
      </p>

      <blockquote>
        <strong>Excerpt — third-party AI:</strong>
        "With your explicit consent, Process sends certain personal data to Anthropic (Claude)
        via Firebase Cloud Functions for the AI coach, meal suggestions, and optional analyses.
        You can refuse or revoke at any time in the App. Anthropic receives your data
        only after your in-app agreement."
      </blockquote>

      <h2>5. General purposes</h2>
      <ul>
        <li>Provide and personalize the App (program, coach, health tracking).</li>
        <li>Sync your data across devices via your account.</li>
        <li>Manage subscriptions and restore your purchases.</li>
        <li>Send reminders (notifications) if you enable them.</li>
        <li>Improve service reliability and security.</li>
        <li>Comply with our legal obligations.</li>
      </ul>

      <h2>6. Legal bases (GDPR)</h2>
      <ul>
        <li><strong>Contract performance</strong>: providing the App and subscription.</li>
        <li><strong>Consent</strong>: HealthKit, front camera / face scan, notifications, microphone, <strong>Anthropic AI coach</strong>, <strong>face scan AI photo analysis</strong>.</li>
        <li><strong>Legitimate interest</strong>: security, fraud prevention, service improvement.</li>
      </ul>

      <h2>7. Processors and third-party services</h2>
      <ul>
        <li><strong>Apple</strong>: App Store, Sign in with Apple, HealthKit, in-app purchases, Speech (on-device dictation).</li>
        <li><strong>Google Firebase</strong>: authentication, Firestore, Cloud Functions (AI proxy).</li>
        <li><strong>RevenueCat</strong>: subscription management.</li>
        <li><strong>Crisp</strong>: support chat (messages you send via the website widget or in-app chat). Hosted in the EU (Crisp IM SAS).</li>
        <li><strong>Anthropic (Claude)</strong>: AI coach and vision analyses — <strong>only with explicit consent</strong> (section 4).</li>
      </ul>

      <h2>8. Retention period</h2>
      <ul>
        <li>Account data: while the account is active, then deletion within <strong>30 days</strong> of request.</li>
        <li>Synced health data: deleted with the account.</li>
        <li>Facial data: see section 3.4 (max. 90 scans).</li>
        <li>Coach conversations: retained while the account is active; deletable by you.</li>
        <li>Subscription data: per applicable accounting and legal obligations.</li>
      </ul>

      <h2>9. Your rights</h2>
      <p>
        Under the GDPR, you have the rights of access, rectification, erasure,
        restriction, objection, and portability. You can withdraw your consent
        (HealthKit, AI, face scan) via iOS Settings or in the App (Settings → AI Privacy).
      </p>
      <p>
        To exercise your rights: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a>.
        You may also lodge a complaint with the CNIL.
      </p>

      <h2>10. Security</h2>
      <p>
        We implement reasonable technical and organizational measures
        (TLS encryption in transit, Firebase authentication, restricted access) to protect your data.
      </p>

      <h2>11. Transfers outside the EU</h2>
      <p>
        Some providers (Firebase, Anthropic) may process data in the United States.
        Appropriate safeguards are in place (standard contractual clauses, etc.).
      </p>

      <h2>12. Minors</h2>
      <p>
        The App is intended for people <strong>16 years and older</strong>. If you believe a minor
        has sent us data without parental authorization, contact us for deletion.
      </p>

      <h2>13. Changes</h2>
      <p>
        We may update this policy. The date at the top of the page will be updated accordingly.
        In case of material changes, we may ask for new in-app consent.
      </p>

      <h2>14. Contact</h2>
      <p>
        Questions: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a><br>
        Support: <a href="/support">useprocess.xyz/support</a>
      </p>
`,

  "/mentions-legales": `
      <p class="meta">In accordance with French law no. 2004-575 of June 21, 2004 (LCEN). Last updated: June 18, 2026.</p>

      <h2>Website and application publisher</h2>
      <p>
        <strong>Process</strong> — publisher of the Process AI mobile application (iOS)<br>
        Email: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a><br>
        Website: <a href="https://useprocess.xyz">https://useprocess.xyz</a>
      </p>

      <h2>Publication director</h2>
      <p>The legal representative of Process.</p>

      <h2>Website hosting</h2>
      <p>
        <strong>Vercel Inc.</strong><br>
        440 N Barranca Avenue #4133, Covina, CA 91723, United States<br>
        Website: <a href="https://vercel.com" target="_blank" rel="noopener noreferrer">vercel.com</a>
      </p>

      <h2>Mobile application</h2>
      <p>
        Distributed on the Apple App Store by <strong>Apple Inc.</strong><br>
        Apple Distribution International Ltd., Hollyhill Industrial Estate, Hollyhill, Cork, Ireland.
      </p>
      <p>
        Bundle identifier: <code>com.useprocess</code>
      </p>

      <h2>Intellectual property</h2>
      <p>
        All elements of the website and application (text, graphics, logos, icons, software)
        are protected by intellectual property law. Any unauthorized reproduction or use
        is prohibited.
      </p>

      <h2>Personal data</h2>
      <p>
        For information on how we process your data, see our
        <a href="/confidentialite">privacy policy</a>.
        To exercise your rights: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a>.
      </p>

      <h2>Contact</h2>
      <p>
        <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a> —
        <a href="/support">Support page</a>
      </p>
`,

  "/support": `
      <p class="meta">Process AI user support (iOS)</p>

      <p>
        Have a question about the app, your subscription, your data, or a technical issue?
        Open the chat in the bottom-right corner, or email us — we typically respond within 2 business days.
      </p>

      <p>
        <strong>Email:</strong>
        <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a>
      </p>

      <h2>Before you write</h2>
      <ul>
        <li>iPhone or iPad model and iOS version.</li>
        <li>Process AI version (Profile &gt; Settings &gt; About).</li>
        <li>Clear description of the issue and steps to reproduce it.</li>
        <li>Screenshot if possible.</li>
      </ul>

      <h2>Frequently asked questions</h2>
      <div class="faq">
        <details>
          <summary>How do I cancel my subscription?</summary>
          <p>
            Open iOS Settings, tap your name, then Subscriptions, select Process AI Premium,
            and choose Cancel. Apple handles billing and refunds under its terms.
          </p>
        </details>
        <details>
          <summary>How do I restore my purchases?</summary>
          <p>
            From the app paywall, open the menu (⋯) then "Restore."
            You must be signed in with the same Apple ID used for the purchase.
          </p>
        </details>
        <details>
          <summary>How do I delete my account and data?</summary>
          <p>
            Profile &gt; Settings &gt; Delete account. This action is permanent.
            You can also revoke Apple Health access in iOS Settings &gt; Health.
          </p>
        </details>
        <details>
          <summary>Does the app request my GPS location?</summary>
          <p>
            No. Process AI does not collect your GPS location. Only the permissions shown
            by iOS (Health, camera, notifications, microphone, etc.) may be requested depending
            on the features you use.
          </p>
        </details>
        <details>
          <summary>Does Process AI replace a doctor?</summary>
          <p>
            No. The app provides wellness estimates and general guidance.
            Consult a healthcare professional for any medical advice.
            See also <a href="/sources-sante">Health sources</a>.
          </p>
        </details>
      </div>

      <h2>Documents</h2>
      <p>
        <a href="/confidentialite">Privacy policy</a> ·
        <a href="/cgu">Terms of Service</a> ·
        <a href="/mentions-legales">Legal notice</a> ·
        <a href="/sources-sante">Health sources</a>
      </p>
`,

  "/sources-sante": `
      <p class="meta">Last updated: June 18, 2026</p>

      <div class="notice notice-warn">
        Process AI scores, reports, and recommendations are wellness estimates.
        They do not replace medical, physical therapy, or dermatology advice.
      </div>

      <p>
        Process AI relies on data you authorize (Apple Health, device sensors)
        and recognized public references to contextualize physical activity,
        sleep, and general wellness.
      </p>

      <h2>References used in the app</h2>
      <ul class="source-list">
        <li>
          <a href="https://www.apple.com/health/" target="_blank" rel="noopener noreferrer">Apple Health — data and privacy</a>
        </li>
        <li>
          <a href="https://www.who.int/news-room/fact-sheets/detail/physical-activity" target="_blank" rel="noopener noreferrer">WHO — physical activity and health</a>
        </li>
        <li>
          <a href="https://www.cdc.gov/physical-activity-basics/" target="_blank" rel="noopener noreferrer">CDC — physical activity basics</a>
        </li>
        <li>
          <a href="https://www.heart.org/en/healthy-living/fitness" target="_blank" rel="noopener noreferrer">American Heart Association — fitness</a>
        </li>
        <li>
          <a href="https://www.nhlbi.nih.gov/health/sleep" target="_blank" rel="noopener noreferrer">NIH — sleep and health</a>
        </li>
      </ul>

      <h2>Limitations</h2>
      <ul>
        <li>Face scan indicators are wellness estimates, not a diagnosis.</li>
        <li>The AI coach produces automated responses that may contain errors.</li>
        <li>If you have symptoms, pain, or a medical condition, consult a healthcare professional.</li>
      </ul>

      <h2>Contact</h2>
      <p>
        Questions: <a href="mailto:support@useprocess.xyz">support@useprocess.xyz</a> —
        <a href="/support">Support page</a>
      </p>
`,
};
