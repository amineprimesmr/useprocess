import Image from "next/image";

type Props = {
  size?: number;
  className?: string;
  priority?: boolean;
};

export function BrandLogo({ size = 32, className = "", priority = false }: Props) {
  return (
    <Image
      src="/icon.png"
      alt="footgoat"
      width={size}
      height={size}
      priority={priority}
      className={`rounded-[22%] object-cover shadow-[0_6px_18px_rgba(0,0,0,0.14)] ${className}`}
      style={{ width: size, height: size, minWidth: size, minHeight: size }}
    />
  );
}
