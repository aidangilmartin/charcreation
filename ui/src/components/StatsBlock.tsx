import type { CharacterStats } from '../types';

type Props = { stats: CharacterStats | null };

const rows: Array<{
  key: keyof CharacterStats;
  label: string;
  format?: (v: any, all: CharacterStats) => string;
}> = [
  { key: 'playtimeMinutes', label: 'Playtime',     format: (v) => formatMinutes(v) },
  { key: 'lastSeen',        label: 'Last Seen' },
  { key: 'jobName',         label: 'Job Title',    format: (v, all) => all.jobGrade ? `${v} (${all.jobGrade})` : String(v) },
  { key: 'cash',            label: 'Cash',         format: (v) => '$' + Number(v).toLocaleString() },
  { key: 'bank',            label: 'Bank',         format: (v) => '$' + Number(v).toLocaleString() },
  { key: 'kd',              label: 'K/D',          format: (v, all) => `${(all.kills ?? 0)}/${(all.deaths ?? 0)} (${Number(v).toFixed(2)})` },
  { key: 'distanceDrivenKm',label: 'Distance',     format: (v) => `${Math.round(Number(v) * 100) / 100} km` },
  { key: 'ownedVehicles',   label: 'Vehicles',     format: (v) => String(v) },
  { key: 'favoriteVehicle', label: 'Top Vehicle' },
  { key: 'ownedProperties', label: 'Properties',   format: (v) => String(v) },
  { key: 'citations',       label: 'Citations',    format: (v) => String(v) },
];

function formatMinutes(min: number) {
  if (!min) return '0 min';
  if (min < 60) return `${min} min`;
  const h = Math.floor(min / 60);
  const m = min % 60;
  return `${h}h ${m}m`;
}

export function StatsBlock({ stats }: Props) {
  if (!stats) {
    return <div className="cc-stats-loading">Loading stats…</div>;
  }

  const visible = rows.filter((r) => stats[r.key] !== undefined && stats[r.key] !== null);
  if (visible.length === 0) return null;

  return (
    <div className="cc-stats-block">
      <div className="cc-stats-title">Stats</div>
      <dl className="cc-detail-grid">
        {visible.map((r) => (
          <div className="cc-detail-row" key={r.key}>
            <dt>{r.label}</dt>
            <dd>{r.format ? r.format(stats[r.key], stats) : String(stats[r.key])}</dd>
          </div>
        ))}
      </dl>
    </div>
  );
}
