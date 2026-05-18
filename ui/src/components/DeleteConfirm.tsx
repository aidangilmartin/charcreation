import { useState } from 'react';
import type { Character, UIConfig } from '../types';

type Props = {
  ui: UIConfig;
  character: Character;
  error: string | null;
  disabled: boolean;
  onCancel: () => void;
  onConfirm: (typedName: string) => void;
};

export function DeleteConfirm({ ui, character, error, disabled, onCancel, onConfirm }: Props) {
  const [typed, setTyped] = useState('');
  const matches = typed.trim().toLowerCase() === character.name.toLowerCase();

  return (
    <div className="cc-modal-backdrop">
      <div className="cc-modal">
        <div className="cc-modal-title">Delete {character.name}?</div>
        <p className="cc-modal-text">{ui.text.deleteConfirm || 'Type the character\'s full name to confirm.'}</p>
        <p className="cc-modal-hint">
          Type <strong>{character.name}</strong> exactly.
        </p>
        <input
          autoFocus
          type="text"
          className="cc-modal-input"
          value={typed}
          onChange={(e) => setTyped(e.target.value)}
          placeholder={character.name}
        />
        {error && <div className="cc-form-error">{error}</div>}
        <div className="cc-actions">
          <button className="cc-btn" disabled={disabled} onClick={onCancel}>
            {ui.text.cancelButton || 'Cancel'}
          </button>
          <button
            className="cc-btn cc-btn-danger"
            disabled={!matches || disabled}
            onClick={() => onConfirm(typed.trim())}
          >
            {ui.text.deleteButton || 'Delete'}
          </button>
        </div>
      </div>
    </div>
  );
}
