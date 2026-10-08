import { useEffect, useState } from "react";

function easeOutCubic(t) {
  return 1 - (1 - t) ** 3;
}

function useAnimatedNumber(active, target, delayMs, durationMs) {
  const [value, setValue] = useState(0);

  useEffect(() => {
    if (!active) return undefined;

    const reduced = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
    if (reduced) {
      setValue(target);
      return undefined;
    }

    let cancelled = false;
    let startTs = null;

    const tick = (now) => {
      if (cancelled) return;
      if (startTs === null) startTs = now;
      const elapsed = now - startTs - delayMs;
      if (elapsed < 0) {
        requestAnimationFrame(tick);
        return;
      }
      const progress = Math.min(1, elapsed / durationMs);
      const eased = easeOutCubic(progress);
      setValue(target * eased);
      if (progress < 1) requestAnimationFrame(tick);
      else setValue(target);
    };

    requestAnimationFrame(tick);
    return () => {
      cancelled = true;
    };
  }, [active, target, delayMs, durationMs]);

  return value;
}

function DigitColumn({ digit }) {
  return (
    <span className="fk-stat-digit" aria-hidden="true">
      <span className="fk-stat-digit__track" style={{ transform: `translateY(-${digit * 10}%)` }}>
        {Array.from({ length: 10 }, (_, index) => (
          <span key={index} className="fk-stat-digit__cell">
            {index}
          </span>
        ))}
      </span>
    </span>
  );
}

function RollingDigits({ value, suffix = "" }) {
  const rounded = Math.round(value);
  const chars = String(Math.max(0, rounded)).split("");

  return (
    <>
      <span className="fk-stat-value__digits">
        {chars.map((char, index) => (
          <DigitColumn key={index} digit={Number(char)} />
        ))}
      </span>
      {suffix ? <span className="fk-stat-value__suffix">{suffix}</span> : null}
    </>
  );
}

function RollingGroupedValue({ value }) {
  const rounded = Math.max(0, Math.round(value));
  const formatted = rounded.toLocaleString("en-US");

  return (
    <>
      <span className="fk-stat-value__digits">
        {formatted.split("").map((char, index) =>
          char >= "0" && char <= "9" ? (
            <DigitColumn key={index} digit={Number(char)} />
          ) : (
            <span key={index} className="fk-stat-value__sep">
              {char}
            </span>
          )
        )}
      </span>
      <span className="fk-stat-value__suffix">+</span>
    </>
  );
}

export function StatAnimatedValue({ target, format, active, delay = 0 }) {
  const value = useAnimatedNumber(active, target, delay, 1900);
  const rolling = active && value < target - 0.5;

  return (
    <div className={`fk-stat-value${rolling ? " fk-stat-value--rolling" : ""}`}>
      {format === "grouped" ? (
        <RollingGroupedValue value={value} />
      ) : (
        <RollingDigits value={value} suffix="k+" />
      )}
    </div>
  );
}
