import type { Character, CharacterStats, UIConfig } from '../types';
import { StatsBlock } from './StatsBlock';

type Props = {
  ui: UIConfig;
  character: Character;
  stats: CharacterStats | null;
  disabled: boolean;
  onPlay: () => void;
  onDelete: () => void;
  onClose: () => void;
};

const FIELD_LABELS: Record<string, string> = {
  dob: 'Date of Birth',
  gender: 'Gender',
  nationality: 'Nationality',
  job: 'Job',
  bank: 'Bank',
  cash: 'Cash',
  playtime: 'Playtime',
};

function formatField(c: Character, field: string) {
  switch (field) {
    case 'bank':
    case 'cash':
      return '$' + ((c[field as 'bank' | 'cash'] as number) || 0).toLocaleString();
    case 'playtime': {
      const minutes = Math.round(c.playtime || 0);
      if (minutes < 60) return `${minutes} min`;
      const h = Math.floor(minutes / 60);
      const m = minutes % 60;
      return `${h}h ${m}m`;
    }
    case 'gender':
      return c.gender === 'f' ? 'Female' : c.gender === 'm' ? 'Male' : c.gender;
    default:
      return String((c as any)[field] ?? '—');
  }
}

export function CharacterPanel({ ui, character, stats, disabled, onPlay, onDelete, onClose }: Props) {
  return (
    <aside className="cc-character-panel">
      <button className="cc-panel-close" onClick={onClose} aria-label="Close">×</button>
      <div className="cc-panel-head">
        <div className="cc-panel-name">{character.name}</div>
        <div className="cc-panel-sub">{character.job}</div>
      </div>
      <dl className="cc-detail-grid">
        {ui.showFields
          .filter((f) => f !== 'name')
          .map((field) => (
            <div className="cc-detail-row" key={field}>
              <dt>{FIELD_LABELS[field] || field}</dt>
              <dd>{formatField(character, field)}</dd>
            </div>
          ))}
      </dl>
      <StatsBlock stats={stats} />
      <div className="cc-actions">
        <button className="cc-btn cc-btn-primary" disabled={disabled} onClick={onPlay}>
          {ui.text.playButton || 'Play'}
        </button>
        <button className="cc-btn cc-btn-danger" disabled={disabled} onClick={onDelete}>
          {ui.text.deleteButton || 'Delete'}
        </button>
      </div>
    </aside>
  );
}
