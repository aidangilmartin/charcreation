import { useCallback, useEffect, useMemo, useState } from 'react';
import { nuiPost, onMessage } from './nui';
import type {
  Character,
  CharacterStats,
  CreateResult,
  DeleteResult,
  OpenPayload,
  SpawnOption,
  SpawnPickerPayload,
  SwitchRejection,
  UIConfig,
} from './types';
import { CreateForm } from './components/CreateForm';
import { DeleteConfirm } from './components/DeleteConfirm';
import { SpawnPicker } from './components/SpawnPicker';
import { SceneOverlay } from './components/SceneOverlay';
import { CharacterPanel } from './components/CharacterPanel';
import { SwitchConfirm } from './components/SwitchConfirm';

type Modal = 'none' | 'create' | 'delete' | 'spawn';

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
  const [hoveredCid, setHoveredCid] = useState<string | null>(null);
  const [selectedCid, setSelectedCid] = useState<string | null>(null);
  const [modal, setModal] = useState<Modal>('none');
  const [spawnData, setSpawnData] = useState<SpawnPickerPayload | null>(null);
  const [createError, setCreateError] = useState<string | null>(null);
  const [deleteError, setDeleteError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);
  const [statsByCid, setStatsByCid] = useState<Record<string, CharacterStats>>({});
  const [switchModal, setSwitchModal] = useState<{ open: boolean; cooldownSec: number; rejection: SwitchRejection | null }>({
    open: false, cooldownSec: 60, rejection: null,
  });
  const [introSkipHint, setIntroSkipHint] = useState<string | null>(null);

  useEffect(() => {
    const off = [
      onMessage('open', (payload: OpenPayload) => {
        if (payload?.ui) {
          setUI(payload.ui);
          applyTheme(payload.ui.theme);
        }
        setCharacters(payload.characters || []);
        setSlots(payload.slots ?? 0);
        setHoveredCid(null);
        setSelectedCid(null);
        setModal('none');
        setCreateError(null);
        setDeleteError(null);
        setVisible(true);
        nuiPost('ready');
      }),
      onMessage('hovered', (data: { cid: string | null }) => {
        setHoveredCid(data?.cid ?? null);
      }),
      onMessage('selected', (data: { cid: string | null; character?: Character }) => {
        setSelectedCid(data?.cid ?? null);
      }),
      onMessage('deleteResult', (result: DeleteResult) => {
        if (result?.ok) {
          setCharacters(result.characters);
          setSelectedCid(null);
          setModal('none');
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
          setSelectedCid(result.character.cid);
          setModal('none');
          setCreateError(null);
          nuiPost('beginCreatorAppearance');
        } else {
          setCreateError(reasonText(result?.reason));
        }
        setBusy(false);
      }),
      onMessage('spawnPicker', (data: SpawnPickerPayload) => {
        setSpawnData(data);
        setModal('spawn');
        setBusy(false);
      }),
      onMessage('close', () => {
        setVisible(false);
        setSpawnData(null);
        setModal('none');
      }),
      onMessage('stats', (data: { cid: string; stats: CharacterStats }) => {
        if (data?.cid) {
          setStatsByCid((prev) => ({ ...prev, [data.cid]: data.stats || {} }));
        }
      }),
      onMessage('switchConfirm', (data: { cooldownSeconds: number }) => {
        setSwitchModal({ open: true, cooldownSec: data?.cooldownSeconds ?? 60, rejection: null });
      }),
      onMessage('switchConfirmClose', () => {
        setSwitchModal({ open: false, cooldownSec: 60, rejection: null });
      }),
      onMessage('switchRejected', (data: { reason: SwitchRejection }) => {
        setSwitchModal((prev) => ({ ...prev, rejection: data?.reason ?? null }));
      }),
      onMessage('introHint', (data: { text: string | null }) => {
        setIntroSkipHint(data?.text ?? null);
      }),
    ];
    return () => off.forEach((fn) => fn());
  }, []);

  const selectedCharacter = useMemo(
    () => characters.find((c) => c.cid === selectedCid) ?? null,
    [characters, selectedCid],
  );

  // Request stats whenever selection changes
  useEffect(() => {
    if (selectedCid && !statsByCid[selectedCid]) {
      nuiPost('requestStats', { cid: selectedCid });
    }
  }, [selectedCid, statsByCid]);

  const hoveredCharacter = useMemo(
    () => characters.find((c) => c.cid === hoveredCid) ?? null,
    [characters, hoveredCid],
  );

  const onPlay = useCallback(() => {
    if (!selectedCharacter || busy) return;
    setBusy(true);
    nuiPost('playCharacter', { cid: selectedCharacter.cid });
  }, [selectedCharacter, busy]);

  const onDeleteRequest = useCallback(() => {
    if (!selectedCharacter) return;
    setDeleteError(null);
    setModal('delete');
  }, [selectedCharacter]);

  const onConfirmDelete = useCallback(
    (typedName: string) => {
      if (!selectedCharacter || busy) return;
      setBusy(true);
      nuiPost('deleteCharacter', { cid: selectedCharacter.cid, typedName });
    },
    [selectedCharacter, busy],
  );

  const onCreateRequest = useCallback(() => {
    setCreateError(null);
    setModal('create');
  }, []);

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

  const onPreviewSpawn = useCallback(
    (spawn: SpawnOption) => {
      if (spawnData?.previewFlyTo === false) return;
      nuiPost('previewSpawn', {
        coords: spawn.coords,
        durationMs: spawnData?.previewFlyDurationMs,
      });
    },
    [spawnData],
  );

  const onCloseSelection = useCallback(() => {
    setSelectedCid(null);
    nuiPost('clearSelection');
  }, []);

  // The switch confirm modal can be triggered when the selector itself isn't open.
  if (!visible) {
    if (!switchModal.open) return null;
    return (
      <SwitchConfirm
        cooldownSeconds={switchModal.cooldownSec}
        rejection={switchModal.rejection}
        onClose={() => setSwitchModal({ open: false, cooldownSec: 60, rejection: null })}
      />
    );
  }

  const sceneEnabled = modal === 'none';
  const showCreate = slots > characters.length;

  return (
    <div className="cc-root">
      <SceneOverlay
        enabled={sceneEnabled}
        hoveredName={
          sceneEnabled && hoveredCharacter && hoveredCharacter.cid !== selectedCid
            ? hoveredCharacter.name
            : null
        }
      />

      <header className="cc-header">
        <div className="cc-server-name">{ui.serverName}</div>
        <div className="cc-server-tag">{ui.serverTagline}</div>
        {sceneEnabled && characters.length > 0 && !selectedCharacter && (
          <div className="cc-hint">Click a character in the scene to select them</div>
        )}
      </header>

      {showCreate && sceneEnabled && (
        <button className="cc-create-btn" onClick={onCreateRequest} disabled={busy}>
          + {ui.text.createButton || 'Create Character'}
        </button>
      )}

      {selectedCharacter && sceneEnabled && (
        <CharacterPanel
          ui={ui}
          character={selectedCharacter}
          stats={statsByCid[selectedCharacter.cid] ?? null}
          disabled={busy}
          onPlay={onPlay}
          onDelete={onDeleteRequest}
          onClose={onCloseSelection}
        />
      )}

      {introSkipHint && sceneEnabled && (
        <div className="cc-intro-hint">{introSkipHint}</div>
      )}

      {switchModal.open && (
        <SwitchConfirm
          cooldownSeconds={switchModal.cooldownSec}
          rejection={switchModal.rejection}
          onClose={() => setSwitchModal({ open: false, cooldownSec: 60, rejection: null })}
        />
      )}

      {modal === 'create' && (
        <CreateForm
          ui={ui}
          error={createError}
          disabled={busy}
          onCancel={() => setModal('none')}
          onSubmit={onSubmitCreate}
        />
      )}

      {modal === 'spawn' && spawnData && (
        <SpawnPicker
          ui={ui}
          data={spawnData}
          disabled={busy}
          onSelect={onSelectSpawn}
          onPreview={onPreviewSpawn}
        />
      )}

      {modal === 'delete' && selectedCharacter && (
        <DeleteConfirm
          ui={ui}
          character={selectedCharacter}
          error={deleteError}
          disabled={busy}
          onCancel={() => {
            setModal('none');
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
