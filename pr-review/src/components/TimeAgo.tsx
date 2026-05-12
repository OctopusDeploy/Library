interface Props {
  isoDate: string;
}

const SECONDS_PER_UNIT: ReadonlyArray<readonly [number, string]> = [
  [31536000, "year"],
  [2592000, "month"],
  [604800, "week"],
  [86400, "day"],
  [3600, "hour"],
  [60, "minute"],
];

export function formatTimeAgo(date: Date): string {
  const seconds = Math.max(0, Math.floor((Date.now() - date.getTime()) / 1000));
  for (const [secs, label] of SECONDS_PER_UNIT) {
    const count = Math.floor(seconds / secs);
    if (count >= 1) return `${count} ${label}${count === 1 ? "" : "s"} ago`;
  }
  return "just now";
}

export default function TimeAgo({ isoDate }: Props) {
  const date = new Date(isoDate);
  return (
    <time dateTime={isoDate} title={date.toLocaleString()}>
      {formatTimeAgo(date)}
    </time>
  );
}
