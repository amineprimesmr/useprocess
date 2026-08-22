import { hueFromKey } from "@/lib/format";

type Props = {
  title: string;
  icon?: string;
  listingKey?: string;
  size?: number;
  className?: string;
  featured?: boolean;
};

export function AppAvatar({ title, icon, listingKey, size = 56, className = "", featured = false }: Props) {
  const letter = (title.replace(/^@/, "").trim()[0] ?? "A").toUpperCase();
  const hue = hueFromKey(listingKey || title);
  const dim = `${size}px`;
  const rounded = "rounded-[22%]";
  const customArt = Boolean(icon?.startsWith("/players/"));

  if (icon) {
    return (
      <span className={`player-avatar relative inline-block shrink-0 ${featured ? "player-avatar-goat" : ""} ${className}`} style={{ width: dim, height: dim }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={icon}
          alt=""
          width={size}
          height={size}
          className={`player-photo h-full w-full object-cover ${customArt ? "player-photo-art" : ""} ${rounded}`}
        />
      </span>
    );
  }

  return (
    <span className={`player-avatar relative inline-block shrink-0 ${featured ? "player-avatar-goat" : ""} ${className}`} style={{ width: dim, height: dim }}>
      <span
        className={`grid h-full w-full place-items-center text-white ${rounded}`}
        style={{
          fontSize: size * 0.38,
          fontWeight: 700,
          background: `linear-gradient(145deg, hsl(${hue} 78% 62%), hsl(${(hue + 40) % 360} 82% 48%))`,
        }}
      >
        {letter}
      </span>
    </span>
  );
}
