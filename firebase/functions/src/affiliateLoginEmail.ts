import * as admin from "firebase-admin";
import nodemailer from "nodemailer";

import { isAppleRelayEmail } from "./affiliateShared";

export const AFFILIATE_LOGIN_FROM = "contact@useprocess.xyz";
export const AFFILIATE_LOGIN_SMTP_HOST = "smtp.hostinger.com";
export const AFFILIATE_LOGIN_SMTP_PORT = 465;
export const CLIPPING_PORTAL_URL = "https://useprocess.xyz/clipping";

function emailDomain(email: string): string {
  return String(email || "").split("@")[1] ?? "unknown";
}

function escapeHtml(raw: string): string {
  return String(raw || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

function isAllowedContinueUrl(raw: string): boolean {
  try {
    const url = new URL(raw);
    const host = url.hostname.toLowerCase();
    if (host === "localhost" || host === "127.0.0.1") return true;
    return host === "useprocess.xyz" || host === "www.useprocess.xyz";
  } catch {
    return false;
  }
}

function buildLoginEmailHtml(link: string, email: string): string {
  const safeLink = escapeHtml(link);
  const safeEmail = escapeHtml(email);
  return `<!DOCTYPE html>
<html lang="fr">
  <body style="margin:0;padding:0;background:#f4f4f5;font-family:Inter,Segoe UI,Roboto,Helvetica,Arial,sans-serif;color:#111;">
    <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f4f4f5;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:520px;background:#fff;border:1px solid #e4e4e7;border-radius:16px;padding:32px 28px;">
            <tr>
              <td>
                <p style="margin:0 0 8px;font-size:12px;letter-spacing:0.08em;text-transform:uppercase;color:#71717a;">Process Clipping</p>
                <h1 style="margin:0 0 12px;font-size:24px;line-height:1.2;">Connexion au portail clipper</h1>
                <p style="margin:0 0 20px;font-size:15px;line-height:1.6;color:#3f3f46;">
                  Bonjour,<br>
                  Clique sur le bouton pour te connecter au portail clipper Process avec <strong>${safeEmail}</strong>.
                  Ce lien est valable une seule fois.
                </p>
                <p style="margin:0 0 24px;">
                  <a href="${safeLink}" style="display:inline-block;padding:14px 22px;background:#111;color:#fff;text-decoration:none;border-radius:999px;font-size:15px;font-weight:600;">
                    Se connecter
                  </a>
                </p>
                <p style="margin:0 0 16px;font-size:13px;line-height:1.6;color:#71717a;">
                  English: tap the button above to sign in to the Process clipper portal. One-time link only.
                </p>
                <p style="margin:0;font-size:12px;line-height:1.6;color:#a1a1aa;word-break:break-all;">
                  Si le bouton ne marche pas, copie ce lien :<br>${safeLink}
                </p>
              </td>
            </tr>
          </table>
          <p style="margin:16px 0 0;font-size:12px;color:#a1a1aa;">
            Process · <a href="https://useprocess.xyz/clipping" style="color:#71717a;">useprocess.xyz/clipping</a><br>
            Tu n'as pas demandé ce lien ? Ignore cet email.
          </p>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}

function buildLoginEmailText(link: string, email: string): string {
  return [
    "Process — Connexion au portail clipper",
    "",
    `Bonjour,`,
    `Connecte-toi au portail clipper Process avec ${email}.`,
    "",
    link,
    "",
    "English: use the link above to sign in to the Process clipper portal.",
    "",
    "Si tu n'as pas demandé ce lien, ignore cet email.",
    "Process — https://useprocess.xyz/clipping",
  ].join("\n");
}

export async function sendAffiliateLoginEmail(params: {
  email: string;
  continueUrl: string;
  smtpPassword: string;
}): Promise<void> {
  const email = params.email.trim().toLowerCase();
  const continueUrl = String(params.continueUrl || CLIPPING_PORTAL_URL).trim();
  const smtpPassword = String(params.smtpPassword || "").trim();

  if (!email || !email.includes("@")) throw new Error("INVALID_EMAIL");
  // Apple's relay rejects us at RCPT TO, minutes after this function already replied OK.
  // Fail here instead, so the caller can tell the clipper what to do.
  if (isAppleRelayEmail(email)) throw new Error("APPLE_RELAY_EMAIL");
  if (!smtpPassword) throw new Error("SMTP_NOT_CONFIGURED");
  if (!isAllowedContinueUrl(continueUrl)) throw new Error("INVALID_CONTINUE_URL");

  const link = await admin.auth().generateSignInWithEmailLink(email, {
    url: continueUrl,
    handleCodeInApp: true,
  });

  const transporter = nodemailer.createTransport({
    host: AFFILIATE_LOGIN_SMTP_HOST,
    port: AFFILIATE_LOGIN_SMTP_PORT,
    secure: true,
    auth: {
      user: AFFILIATE_LOGIN_FROM,
      pass: smtpPassword,
    },
  });

  try {
    const info = await transporter.sendMail({
      from: `"Process" <${AFFILIATE_LOGIN_FROM}>`,
      replyTo: AFFILIATE_LOGIN_FROM,
      to: email,
      subject: "Connexion au portail clipper Process",
      text: buildLoginEmailText(link, email),
      html: buildLoginEmailHtml(link, email),
    });

    // SMTP only tells us the relay accepted it. Bounces land in contact@useprocess.xyz
    // minutes later, so log the domain here to make silent failures greppable.
    console.log("[affiliateLoginEmail] accepted", {
      domain: emailDomain(email),
      messageId: info?.messageId ?? null,
      rejected: info?.rejected?.length ?? 0,
    });
  } catch (error: any) {
    console.error("[affiliateLoginEmail] send failed", {
      domain: emailDomain(email),
      code: error?.code ?? null,
      response: error?.response ?? null,
    });
    throw error;
  }
}
