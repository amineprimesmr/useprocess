import { hueFromKey } from "@/lib/format";

type Props = {
  title: string;
  icon?: string;
  listingKey?: string;
  size?: number;
  className?: string;
  mogged?: boolean;
};

export function AppAvatar({ title, icon, listingKey, size = 56, className = "", mogged = false }: Props) {
  const letter = (title.replace(/^@/, "").trim()[0] ?? "A").toUpperCase();
  const hue = hueFromKey(listingKey || title);
  const dim = `${size}px`;
  const rounded = "rounded-[22%]";

  if (icon) {
    return (
      <span className={`relative inline-block shrink-0 ${className}`} style={{ width: dim, height: dim }}>
        {/* eslint-disable-next-line @next/next/no-img-element */}
        <img
          src={icon}
          alt=""
          width={size}
          height={size}
          className={`h-full w-full object-cover shadow-[0_8px_18px_rgba(0,0,0,0.08)] ${rounded} ${mogged ? "opacity-90" : ""}`}
        />
        {mogged ? (
          // eslint-disable-next-line @next/next/no-img-element
          <img
            src="/mogged.png"
            alt=""
            width={size}
            height={size}
            className={`mogged-stamp pointer-events-none absolute inset-0 h-full w-full object-cover ${rounded}`}
            aria-hidden="true"
          />
        ) : null}
      </span>
    );
  }

  return (
    <span className={`relative inline-block shrink-0 ${className}`} style={{ width: dim, height: dim }}>
      <span
        className={`grid h-full w-full place-items-center text-white shadow-[0_8px_18px_rgba(0,0,0,0.08)] ${rounded}`}
        style={{
          fontSize: size * 0.38,
          fontWeight: 700,
          background: `linear-gradient(145deg, hsl(${hue} 78% 62%), hsl(${(hue + 40) % 360} 82% 48%))`,
        }}
      >
        {letter}
      </span>
      {mogged ? (
        // eslint-disable-next-line @next/next/no-img-element
        <img
          src="/mogged.png"
          alt=""
          width={size}
          height={size}
          className={`mogged-stamp pointer-events-none absolute inset-0 h-full w-full object-cover ${rounded}`}
          aria-hidden="true"
        />
      ) : null}
    </span>
  );
}
