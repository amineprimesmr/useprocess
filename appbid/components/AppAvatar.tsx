import { hueFromKey } from "@/lib/format";

type Props = {
  title: string;
  icon?: string;
  listingKey?: string;
  size?: number;
};

export function AppAvatar({ title, icon, listingKey, size = 56 }: Props) {
  const letter = (title.replace(/^@/, "").trim()[0] ?? "A").toUpperCase();
  const hue = hueFromKey(listingKey || title);
  const dim = `${size}px`;

  if (icon) {
    return (
      // eslint-disable-next-line @next/next/no-img-element
      <img
        src={icon}
        alt=""
        width={size}
        height={size}
        className="shrink-0 rounded-[22%] object-cover shadow-[0_8px_18px_rgba(0,0,0,0.08)]"
        style={{ width: dim, height: dim }}
      />
    );
  }

  return (
    <span
      className="grid shrink-0 place-items-center rounded-full text-white shadow-[0_8px_18px_rgba(0,0,0,0.08)]"
      style={{
        width: dim,
        height: dim,
        fontSize: size * 0.38,
        fontWeight: 700,
        background: `linear-gradient(145deg, hsl(${hue} 78% 62%), hsl(${(hue + 40) % 360} 82% 48%))`,
      }}
    >
      {letter}
    </span>
  );
}
