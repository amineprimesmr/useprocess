import { useEffect, useRef, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { armSettingsChange, playSettingsChange } from "../features/process-sound.js";
import { IconCheck } from "./AffiliateIcons.jsx";

const SUCCESS_HOLD_MS = 1200;

/** Same confirmation clip as ProcessSoundPlayer.playSettingsChange() in the iOS app. */
export function playConfirm() {
  playSettingsChange();
}

export function useActionFeedback() {
  const [phase, setPhase] = useState("idle");
  const timer = useRef(0);
  const locked = useRef(false);

  useEffect(() => () => window.clearTimeout(timer.current), []);

  async function run(action) {
    if (locked.current) return false;
    locked.current = true;
    window.clearTimeout(timer.current);
    armSettingsChange();
    setPhase("saving");
    try {
      const result = await action();
      playConfirm();
      setPhase("success");
      timer.current = window.setTimeout(() => {
        locked.current = false;
        setPhase("idle");
      }, SUCCESS_HOLD_MS);
      return result === undefined ? true : result;
    } catch (err) {
      locked.current = false;
      setPhase("idle");
      throw err;
    }
  }

  function confirmNow() {
    playConfirm();
    window.clearTimeout(timer.current);
    locked.current = true;
    setPhase("success");
    timer.current = window.setTimeout(() => {
      locked.current = false;
      setPhase("idle");
    }, SUCCESS_HOLD_MS);
  }

  return {
    phase,
    run,
    confirmNow,
    isSaving: phase === "saving",
    isSuccess: phase === "success",
  };
}

export function SuccessActionButton({
  onAction,
  onSuccess,
  validate,
  idleLabel,
  savingLabel,
  successLabel,
  className = "af-btn af-btn-sm af-btn-black",
  disabled = false,
  type = "button",
}) {
  const { run, isSaving, isSuccess } = useActionFeedback();

  async function handle(event) {
    event.preventDefault();
    if (disabled || isSaving || isSuccess) return;
    const form = event.currentTarget.form;
    if (form && !form.reportValidity()) return;
    if (validate && validate() === false) return;
    try {
      await run(onAction);
      onSuccess?.();
    } catch {
      /* caller surfaces the error */
    }
  }

  const label = isSuccess
    ? successLabel || appCopy("Enregistré", "Saved")
    : isSaving
      ? savingLabel || appCopy("Enregistrement…", "Saving…")
      : idleLabel;

  return (
    <button
      type={type}
      className={`${className}${isSaving ? " is-saving" : ""}${isSuccess ? " is-success" : ""}`}
      disabled={disabled || isSaving || isSuccess}
      onClick={handle}
    >
      {isSuccess ? (
        <span className="af-action-check" aria-hidden>
          <IconCheck />
        </span>
      ) : isSaving ? (
        <span className="af-action-spin" aria-hidden />
      ) : null}
      {label}
    </button>
  );
}
