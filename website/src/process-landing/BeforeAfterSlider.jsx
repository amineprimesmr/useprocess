import { useState } from "react";
import { appCopy } from "../features/app-copy.js";
import "./before-after-slider.css";

export function BeforeAfterSlider({ pairs, beforeLabel, afterLabel, seeMoreLabel }) {
  const [activePair, setActivePair] = useState(0);
  const [pos, setPos] = useState(50);
  const sliderAria = appCopy(
    "Glisser pour comparer avant et après",
    "Drag to compare before and after"
  );

  const pair = pairs[activePair];
  const before = pair.before;
  const after = pair.after;

  const handleSeeMore = () => {
    setActivePair((current) => (current + 1) % pairs.length);
    setPos(50);
  };

  return (
    <div className="fk-ba-slider">
      <figure className="fk-ba-slider__frame">
        <img
          className="fk-ba-slider__img fk-ba-slider__img--before"
          src={before}
          alt=""
          loading="lazy"
          decoding="async"
          key={before}
        />
        <img
          className="fk-ba-slider__img fk-ba-slider__img--after"
          src={after}
          alt=""
          loading="lazy"
          decoding="async"
          key={after}
          style={{ clipPath: `inset(0 0 0 ${pos}%)` }}
        />
        <span className="fk-ba-slider__label fk-ba-slider__label--before">{beforeLabel}</span>
        <span className="fk-ba-slider__label fk-ba-slider__label--after">{afterLabel}</span>
        <div className="fk-ba-slider__handle" style={{ left: `${pos}%` }} aria-hidden="true">
          <span className="fk-ba-slider__knob" />
        </div>
        <input
          type="range"
          min={0}
          max={100}
          value={pos}
          onChange={(event) => setPos(Number(event.target.value))}
          className="fk-ba-slider__input"
          aria-label={sliderAria}
        />
        <button type="button" className="fk-ba-slider__more" onClick={handleSeeMore}>
          {seeMoreLabel}
        </button>
      </figure>
    </div>
  );
}
