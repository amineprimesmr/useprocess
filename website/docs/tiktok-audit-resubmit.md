# TikTok App Review — Process Studio (resubmit pack)

App ID: `7673250598694963220`  
Portal: https://developers.tiktok.com/app/7673250598694963220/

## Rejection (exact)

TikTok asked to update and resubmit:

1. **Website URL**
2. **App name**
3. **Redirect domain**

## Portal draft (current)

| Field | Value |
|--------|--------|
| App name | **Process Studio** |
| Website / Web URL | **https://useprocess.xyz/studio** |
| Terms | https://useprocess.xyz/cgu |
| Privacy | https://useprocess.xyz/confidentialite |
| Platforms | **Web only** (Desktop / Android / iOS unchecked) |
| Redirect URI | https://useprocess.xyz/tiktok/callback |
| Login Kit platforms | Web only |
| Scopes | `user.info.basic`, `user.info.profile`, `user.info.stats`, `video.list`, `video.upload`, `video.publish` |

## Code fixes (must be live before resubmit)

- Callback **never** redirects to `127.0.0.1` / localhost (`website/public/tiktok/callback/index.html`).
- Studio multi-account + analytics UI (`StudioApp.jsx` + `/api/tiktok/accounts`, `/videos`).
- Privacy + CGU TikTok Studio clauses.

**Deploy gate:** production still served the old localhost bridge until the next git push / Vercel deploy of `website/`.

## You must finish in the portal (automation cannot)

1. **Upload App icon** — file ready on Desktop:  
   `~/Desktop/process-studio-tiktok-app-icon-1024.png`  
   (Save fails with “App icon is required” until this is done.)
2. **Upload sandbox demo video** (mp4) on `useprocess.xyz/studio` showing:
   - Login Kit OAuth
   - Profile + stats
   - Recent posts (`video.list`)
   - Preview carousel + publish / inbox (`video.upload` / `video.publish`)
   - Privacy + commercial disclosure toggles
3. **Save** → **Submit for review** (do not submit while production callback still has localhost).

## After approval

- Switch Vercel `TIKTOK_CLIENT_KEY` / `TIKTOK_CLIENT_SECRET` to **production** credentials.
- Reconnect TikTok accounts in Studio.
