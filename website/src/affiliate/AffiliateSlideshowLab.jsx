import { useCallback, useEffect, useMemo, useState } from "react";
import { appCopy } from "../features/app-copy.js";
import { IconSlides, IconTikTok } from "./AffiliateIcons.jsx";
import { FORMAT_SPECS } from "./method-catalog.js";
import { navigateHash, readHashQuery } from "./affiliate-utils.js";
import "./affiliate-slideshow-lab.css";

const SPEC_TO_COLLECTION = {
  "01": "debloat",
  "02": "glowup",
  "03": "foods",
};

export const LAB_LESSONS = [
  {
    id: "what",
    title: { fr: "C'est quoi le format slideshow", en: "What the slideshow format is" },
    blurb: {
      fr: "Sur TikTok, un slideshow c'est un post Photo — l'icône deux carrés sur la miniature. Tu swipe les slides. Pas une facecam. Voici @mannyprcs, puis les mêmes formats dans Format.",
      en: "On TikTok a slideshow is a Photo post — the two-square icon on the thumbnail. You swipe the slides. Not a talking head. Here's @mannyprcs, then the same formats in Format.",
    },
    src: "/assets/affiliate/lab/what-is-slideshow.mp4",
    poster: "/assets/affiliate/lab/what-is-slideshow.jpg",
  },
];

function lessonFromHash() {
  const id = String(readHashQuery().l || "").trim();
  return LAB_LESSONS.find((item) => item.id === id) || LAB_LESSONS[0];
}

export function AffiliateSlideshowLabPage() {
  const [lessonId, setLessonId] = useState(() => lessonFromHash()?.id || LAB_LESSONS[0].id);
  const [specId, setSpecId] = useState(FORMAT_SPECS[0]?.id || "01");
  const lesson = useMemo(
    () => LAB_LESSONS.find((item) => item.id === lessonId) || LAB_LESSONS[0],
    [lessonId]
  );
  const lessonIndex = Math.max(0, LAB_LESSONS.findIndex((item) => item.id === lesson.id));
  const spec = useMemo(
    () => FORMAT_SPECS.find((item) => item.id === specId) || FORMAT_SPECS[0],
    [specId]
  );
  const collectionId = SPEC_TO_COLLECTION[spec?.id] || "";

  const goLesson = useCallback((id) => {
    setLessonId(id);
    navigateHash(id === LAB_LESSONS[0].id ? "slideshowlab" : `slideshowlab?l=${id}`);
  }, []);

  useEffect(() => {
    const sync = () => setLessonId(lessonFromHash()?.id || LAB_LESSONS[0].id);
    window.addEventListener("hashchange", sync);
    return () => window.removeEventListener("hashchange", sync);
  }, []);

  return (
    <div className="af-lab">
      <header className="af-lab-head">
        <p className="af-lab-kicker">
          <IconSlides />
          Lab
        </p>
        <h2>SlideshowLab</h2>
        <p className="af-lab-lead">
          {appCopy(
            "Les leçons d'abord. Les structures officielles sont en bas, les exemples TikTok dans Format.",
            "Lessons first. Official structures are below, TikTok examples live in Format."
          )}
        </p>
      </header>

      <div className="af-lab-lessons">
        {LAB_LESSONS.length > 1 ? (
          <div className="af-lab-lesson-tabs" role="tablist" aria-label={appCopy("Leçons", "Lessons")}>
            {LAB_LESSONS.map((item, index) => (
              <button
                key={item.id}
                type="button"
                role="tab"
                aria-selected={item.id === lesson.id}
                className={`af-lab-spec${item.id === lesson.id ? " is-on" : ""}`}
                onClick={() => goLesson(item.id)}
              >
                {index + 1}. {appCopy(item.title.fr, item.title.en)}
              </button>
            ))}
          </div>
        ) : null}

        {lesson ? (
          <article className="af-lab-lesson" key={lesson.id}>
            <h3>
              <span>{lessonIndex + 1}</span>
              {appCopy(lesson.title.fr, lesson.title.en)}
            </h3>
            {lesson.blurb ? (
              <p className="af-lab-lesson-blurb">{appCopy(lesson.blurb.fr, lesson.blurb.en)}</p>
            ) : null}
            <video
              className="af-lab-video"
              controls
              playsInline
              preload="metadata"
              poster={lesson.poster}
              src={lesson.src}
            >
              {appCopy("Ta vidéo n'est pas lisible dans ce navigateur.", "This browser can't play the video.")}
            </video>
          </article>
        ) : null}
      </div>

      <h3 className="af-lab-sub">{appCopy("Structures officielles", "Official structures")}</h3>

      <div className="af-lab-specs" role="tablist" aria-label={appCopy("Formats", "Formats")}>
        {FORMAT_SPECS.map((item) => (
          <button
            key={item.id}
            type="button"
            role="tab"
            aria-selected={item.id === spec?.id}
            className={`af-lab-spec${item.id === spec?.id ? " is-on" : ""}`}
            onClick={() => setSpecId(item.id)}
          >
            {appCopy(item.name.fr, item.name.en)}
          </button>
        ))}
      </div>

      {spec ? (
        <section className="af-lab-board">
          <div className="af-lab-canvas">
            {spec.slides.map((slide) => (
              <figure key={slide.src}>
                <img src={slide.src} alt={appCopy(slide.fr, slide.en)} width={180} height={320} />
                <figcaption>{appCopy(slide.fr, slide.en)}</figcaption>
              </figure>
            ))}
          </div>
          <div className="af-lab-meta">
            <p className="af-lab-hook">“{appCopy(spec.hook.fr, spec.hook.en)}”</p>
            <ol>
              {spec.structure.map((item) => (
                <li key={item.en}>{appCopy(item.fr, item.en)}</li>
              ))}
            </ol>
            {collectionId ? (
              <button
                type="button"
                className="af-btn af-btn-sm af-btn-black"
                onClick={() => navigateHash(`format?f=${collectionId}`)}
              >
                <IconTikTok />
                {appCopy("Voir les exemples dans Format", "See examples in Format")}
              </button>
            ) : null}
          </div>
        </section>
      ) : null}
    </div>
  );
}
