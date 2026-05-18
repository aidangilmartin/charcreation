import type { Character, UIText } from '../types';

type Props = {
  characters: Character[];
  slots: number;
  activeCid: string | null;
  text: UIText;
  onSelect: (c: Character) => void;
  onCreate: () => void;
};

export function CharacterList({ characters, slots, activeCid, text, onSelect, onCreate }: Props) {
  const emptySlots = Math.max(0, slots - characters.length);

  return (
    <aside className="cc-sidebar">
      <div className="cc-sidebar-title">{text.selectTitle || 'Select a Character'}</div>
      <div className="cc-slot-count">
        {characters.length} / {slots}
      </div>

      <ul className="cc-card-list">
        {characters.map((c) => (
          <li
            key={c.cid}
            className={`cc-card ${activeCid === c.cid ? 'is-active' : ''}`}
            onClick={() => onSelect(c)}
          >
            <div className="cc-card-name">{c.name}</div>
            <div className="cc-card-job">{c.job}</div>
            <div className="cc-card-meta">
              <span>${(c.cash || 0).toLocaleString()} cash</span>
              <span>${(c.bank || 0).toLocaleString()} bank</span>
            </div>
          </li>
        ))}

        {Array.from({ length: emptySlots }).map((_, i) => (
          <li
            key={`empty-${i}`}
            className="cc-card cc-card-empty"
            onClick={onCreate}
          >
            <div className="cc-card-name">{text.emptySlot || 'Empty Slot'}</div>
            <div className="cc-card-job">{text.createButton || 'Create Character'}</div>
          </li>
        ))}
      </ul>
    </aside>
  );
}
