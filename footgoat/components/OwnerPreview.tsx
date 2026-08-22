"use client";

import { siteCopy } from "@/lib/copy";
import { parseNickname } from "@/lib/nickname";

type Props = {
  owner: string;
  preview: string;
  copy: ReturnType<typeof siteCopy>;
};

export function OwnerPreview({ owner, preview, copy }: Props) {
  const draft = preview.trim().replace(/^@+/, "");
  const ready = Boolean(parseNickname(draft));

  if (!draft) {
    return <p className="truncate text-[13px] font-medium text-[var(--ink)]">{owner ? copy.ownedBy(owner) : copy.unclaimed}</p>;
  }

  return (
    <p className={`owner-preview ${ready ? "owner-preview-ready" : "owner-preview-draft"}`}>
      <span className="owner-preview-badge">{copy.preview}</span>
      <span className="owner-preview-nick" aria-label={`@${draft}`}>
        <span className="owner-at">@</span>
        {draft.split("").map((letter, index) => (
          <span key={`${index}-${letter}`} className="owner-letter" style={{ animationDelay: `${index * 26}ms` }}>
            {letter}
          </span>
        ))}
        <span className="owner-caret" aria-hidden="true" />
      </span>
    </p>
  );
}
