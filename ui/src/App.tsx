import { useCallback, useEffect, useMemo, useState } from 'react';
import { nuiPost, onMessage } from './nui';
import type {
  Character,
  CreateResult,
  DeleteResult,
  OpenPayload,
  SpawnOption,
  SpawnPickerPayload,
  UIConfig,
} from './types';
import { CharacterList } from './components/CharacterList';
import { DetailsPanel } from './components/DetailsPanel';
import { CreateForm } from './components/CreateForm';
import { DeleteConfirm } from './components/DeleteConfirm';
import { SpawnPicker } from './components/SpawnPicker';

type Screen = 'select' | 'create' | 'spawn';

const defaultUI: UIConfig = {
  serverName: '',
  serverTagline: '',
  theme: {
    accent: '#e8c275',
    accentHover: '#f5d189',
    background: 'rgba(8,10,16,0.55)',
    panel: 'rgba(20,24,34,0.78)',
    panelBorder: 'rgba(255,255,255,0.08)',
    text: '#f3f4f6',
    textMuted: '#9aa3b2',
    danger: '#ef4444',
    success: '#22c55e',
  },
  showFields: [],
  text: {},
  genders: [],
  validation: { minNameLength: 2, maxNameLength: 24, minAge: 18, maxAge: 90 },
  enableSounds: false,
};

function applyTheme(theme: UIConfig['theme']) {
  const root = document.documentElement;
  for (const [k, v] of Object.entries(theme)) {
    root.style.setProperty(`--cc-${k}`, v);
  }
}

export function App() {
  const [visible, setVisible] = useState(false);
  const [ui, setUI] = useState<UIConfig>(defaultUI);
  const [characters, setCharacters] = useState<Character[]>([]);
  const [slots, setSlots] = useState(0);
  const [activeCid, setActiveCid] = useState<string | null>(null);
  const [screen, setScreen] = useState<Screen>('select');
  const [deletingCid, setDeletingCid] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [createError, setCreateError] = useState<string | null>(null);
  const [spawnData, setSpawnData] = useState<SpawnPickerPayload | null>(null);
  const [busy, setBusy] = useState(false);

  useEffect(() => {
    const off = [
      onMessage('open', (payload: OpenPayload) => {
        if (payload?.ui) {
          setUI(payload.ui);
          applyTheme(payload.ui.theme);
        }
        setCharacters(payload.characters || []);
        setSlots(payload.slots ?? 0);
        setActiveCid(payload.characters?.[0]?.cid ?? null);
        setScreen('select');
        setDeletingCid(null);
        setDeleteError(null);
        setCreateError(null);
        setVisible(true);
        nuiPost('ready');
      }),
      onMessage('deleteResult', (result: DeleteResult) => {
        if (result?.ok) {
          setCharacters(result.characters);
          setActiveCid(result.characters[0]?.cid ?? null);
          setDeletingCid(null);
          setDeleteError(null);
        } else {
          setDeleteError(
            result?.reason === 'name_mismatch' ? 'Name did not match.' : 'Failed to delete character.',
          );
        }
        setBusy(false);
      }),
      onMessage('createResult', (result: CreateResult) => {
        if (result?.ok) {
          setCharacters((prev) => [...prev, result.character]);
          setActiveCid(result.character.cid);
          setScreen('select');
          setCreateError(null);
          // Hand off to in-game appearance editor next
          nuiPost('beginCreatorAppearance');
        } else {
          setCreateError(reasonText(result?.reason));
        }
        setBusy(false);
      }),
      onMessage('spawnPicker', (data: SpawnPickerPayload) => {
        setSpawnData(data);
        setScreen('spawn');
        setBusy(false);
      }),
      onMessage('close', () => {
        setVisible(false);
        setSpawnData(null);
      }),
    ];
    return () => off.forEach((fn) => fn());
  }, []);

  const activeCharacter = useMemo(
    () => characters.find((c) => c.cid === activeCid) ?? null,
    [characters, activeCid],
  );

  const onSelect = useCallback((c: Character) => {
    setActiveCid(c.cid);
    setDeletingCid(null);
    setDeleteError(null);
    nuiPost('previewCharacter', { cid: c.cid });
  }, []);

  const onPlay = useCallback(() => {
    if (!activeCharacter || busy) return;
    setBusy(true);
    nuiPost('selectCharacter', { cid: activeCharacter.cid });
  }, [activeCharacter, busy]);

  const onCreateRequest = useCallback(() => {
    setCreateError(null);
    setScreen('create');
  }, []);

  const onDeleteRequest = useCallback(() => {
    if (!activeCharacter) return;
    setDeleteError(null);
    setDeletingCid(activeCharacter.cid);
  }, [activeCharacter]);

  const onConfirmDelete = useCallback(
    (typedName: string) => {
      if (!activeCharacter || busy) return;
      setBusy(true);
      nuiPost('deleteCharacter', { cid: activeCharacter.cid, typedName });
    },
    [activeCharacter, busy],
  );

  const onSubmitCreate = useCallback(
    (info: { firstname: string; lastname: string; dob: string; gender: string; nationality: string }) => {
      if (busy) return;
      setBusy(true);
      nuiPost('createCharacter', { info });
    },
    [busy],
  );

  const onSelectSpawn = useCallback(
    (spawn: SpawnOption) => {
      if (busy) return;
      setBusy(true);
      nuiPost('selectSpawn', { spawnId: spawn.id });
    },
    [busy],
  );

  const onPreviewSpawn = useCallback((spawn: SpawnOption) => {
    if (!spawnData?.previewFlyTo) return;
    nuiPost('previewSpawn', { coords: spawn.coords });
  }, [spawnData]);

  if (!visible) return null;

  return (
    <div className="cc-root">
      <header className="cc-header">
        <div className="cc-server-name">{ui.serverName}</div>
        <div className="cc-server-tag">{ui.serverTagline}</div>
      </header>

      {screen === 'select' && (
        <div className="cc-layout">
          <CharacterList
            characters={characters}
            slots={slots}
            activeCid={activeCid}
            text={ui.text}
            onSelect={onSelect}
            onCreate={onCreateRequest}
          />
          <DetailsPanel
            ui={ui}
            character={activeCharacter}
            disabled={busy}
            onPlay={onPlay}
            onDelete={onDeleteRequest}
          />
        </div>
      )}

      {screen === 'create' && (
        <CreateForm
          ui={ui}
          error={createError}
          disabled={busy}
          onCancel={() => setScreen('select')}
          onSubmit={onSubmitCreate}
        />
      )}

      {screen === 'spawn' && spawnData && (
        <SpawnPicker
          ui={ui}
          data={spawnData}
          disabled={busy}
          onSelect={onSelectSpawn}
          onPreview={onPreviewSpawn}
        />
      )}

      {deletingCid && activeCharacter && (
        <DeleteConfirm
          ui={ui}
          character={activeCharacter}
          error={deleteError}
          disabled={busy}
          onCancel={() => {
            setDeletingCid(null);
            setDeleteError(null);
          }}
          onConfirm={onConfirmDelete}
        />
      )}
    </div>
  );
}

function reasonText(reason: string | undefined) {
  switch (reason) {
    case 'slots_full': return 'You have no character slots remaining.';
    case 'create_failed': return 'Server failed to create character.';
    default: return 'Could not create character.';
  }
}
