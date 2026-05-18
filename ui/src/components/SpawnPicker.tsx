import { useState } from 'react';
import type { SpawnOption, SpawnPickerPayload, UIConfig } from '../types';

type Props = {
  ui: UIConfig;
  data: SpawnPickerPayload;
  disabled: boolean;
  onSelect: (s: SpawnOption) => void;
  onPreview: (s: SpawnOption) => void;
};

const KIND_BADGE: Record<string, string> = {
  last: 'Last Location',
  static: 'Spawn Point',
  apartment: 'Apartment',
  job: 'Workplace',
};

export function SpawnPicker({ ui, data, disabled, onSelect, onPreview }: Props) {
  const [activeId, setActiveId] = useState(data.options[0]?.id ?? null);
  const active = data.options.find((o) => o.id === activeId) ?? null;

  const handleHover = (option: SpawnOption) => {
    setActiveId(option.id);
    onPreview(option);
  };

  return (
    <div className="cc-spawn-layout">
      <aside className="cc-sidebar">
        <div className="cc-sidebar-title">{ui.text.spawnTitle || 'Choose Where to Spawn'}</div>
        <div className="cc-slot-count">{data.character.name}</div>
        <ul className="cc-card-list">
          {data.options.map((opt) => (
            <li
              key={opt.id}
              className={`cc-card ${activeId === opt.id ? 'is-active' : ''}`}
              onMouseEnter={() => handleHover(opt)}
              onClick={() => handleHover(opt)}
            >
              <div className="cc-card-name">{opt.label}</div>
              <div className="cc-card-job">{KIND_BADGE[opt.kind] || opt.kind}</div>
              {opt.description && <div className="cc-card-meta">{opt.description}</div>}
            </li>
          ))}
        </ul>
      </aside>

      <section className="cc-details">
        <div className="cc-detail-head">
          <div className="cc-detail-name">{active?.label ?? '—'}</div>
          <div className="cc-detail-sub">{active ? KIND_BADGE[active.kind] || active.kind : ''}</div>
        </div>
        {active?.description && <p className="cc-spawn-desc">{active.description}</p>}
        <div className="cc-actions">
          <button
            className="cc-btn cc-btn-primary"
            disabled={!active || disabled}
            onClick={() => active && onSelect(active)}
          >
            {ui.text.spawnButton || 'Spawn Here'}
          </button>
        </div>
      </section>
    </div>
  );
}
