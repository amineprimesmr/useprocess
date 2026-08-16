import { useCallback, useRef, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import "./before-after-slider.css";

export function BeforeAfterSlider({ pairs, beforeLabel, afterLabel, seeMoreLabel }) {
  const [activePair, setActivePair] = useState(0);
  const [pos, setPos] = useState(50);
  const frameRef = useRef(null);
  const isDraggingRef = useRef(false);

  const sliderAria = appCopy(
    "Glisser pour comparer avant et après",
    "Drag to compare before and after"
  );

  const pair = pairs[activePair];
  const before = pair.before;
  const after = pair.after;

  const setPosFromClientX = useCallback((clientX) => {
    const frame = frameRef.current;
    if (!frame) return;

    const { left, width } = frame.getBoundingClientRect();
    if (width <= 0) return;

    const ratio = (clientX - left) / width;
    setPos(Math.round(Math.min(1, Math.max(0, ratio)) * 100));
  }, []);

  const onPointerDown = (event) => {
    if (event.pointerType === "mouse" && event.button !== 0) return;
    if (event.target.closest(".fk-ba-slider__more")) return;

    isDraggingRef.current = true;
    frameRef.current?.setPointerCapture(event.pointerId);
    setPosFromClientX(event.clientX);
  };

  const endDrag = (event) => {
    if (!isDraggingRef.current) return;

    isDraggingRef.current = false;
    if (frameRef.current?.hasPointerCapture?.(event.pointerId)) {
      frameRef.current.releasePointerCapture(event.pointerId);
    }
  };

  const onKeyDown = (event) => {
    if (event.key === "ArrowLeft" || event.key === "ArrowDown") {
      event.preventDefault();
      setPos((value) => Math.max(0, value - 2));
      return;
    }

    if (event.key === "ArrowRight" || event.key === "ArrowUp") {
      event.preventDefault();
      setPos((value) => Math.min(100, value + 2));
      return;
    }

    if (event.key === "Home") {
      event.preventDefault();
      setPos(0);
      return;
    }

    if (event.key === "End") {
      event.preventDefault();
      setPos(100);
    }
  };

  const handleSeeMore = () => {
    setActivePair((current) => (current + 1) % pairs.length);
    setPos(50);
  };

  return (
    <div className="fk-ba-slider">
      <figure
        ref={frameRef}
        className="fk-ba-slider__frame"
        role="slider"
        tabIndex={0}
        aria-label={sliderAria}
        aria-valuemin={0}
        aria-valuemax={100}
        aria-valuenow={pos}
        onPointerDown={onPointerDown}
        onPointerMove={(event) => {
          if (!isDraggingRef.current) return;
          setPosFromClientX(event.clientX);
        }}
        onPointerUp={endDrag}
        onPointerCancel={endDrag}
        onKeyDown={onKeyDown}
      >
        <img
          className="fk-ba-slider__img fk-ba-slider__img--before"
          src={before}
          alt=""
          loading="lazy"
          decoding="async"
          draggable={false}
          key={before}
        />
        <img
          className="fk-ba-slider__img fk-ba-slider__img--after"
          src={after}
          alt=""
          loading="lazy"
          decoding="async"
          draggable={false}
          key={after}
          style={{ clipPath: `inset(0 0 0 ${pos}%)` }}
        />
        <span className="fk-ba-slider__label fk-ba-slider__label--before">{beforeLabel}</span>
        <span className="fk-ba-slider__label fk-ba-slider__label--after">{afterLabel}</span>
        <div className="fk-ba-slider__handle" style={{ left: `${pos}%` }} aria-hidden="true">
          <span className="fk-ba-slider__knob" />
        </div>
        <button
          type="button"
          className="fk-ba-slider__more"
          onClick={handleSeeMore}
          onPointerDown={(event) => event.stopPropagation()}
        >
          {seeMoreLabel}
        </button>
      </figure>
    </div>
  );
}
