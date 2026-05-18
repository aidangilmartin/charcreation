export type Character = {
  cid: string;
  firstname: string;
  lastname: string;
  name: string;
  dob: string;
  gender: 'm' | 'f' | string;
  nationality: string;
  job: string;
  bank: number;
  cash: number;
  playtime: number;
};

export type SpawnOption = {
  id: string;
  label: string;
  description?: string;
  kind: 'last' | 'static' | 'apartment' | 'job' | string;
  coords: { x: number; y: number; z: number; w?: number };
};

export type UITheme = {
  accent: string;
  accentHover: string;
  background: string;
  panel: string;
  panelBorder: string;
  text: string;
  textMuted: string;
  danger: string;
  success: string;
};

export type UIText = Record<string, string>;

export type UIConfig = {
  serverName: string;
  serverTagline: string;
  theme: UITheme;
  showFields: string[];
  text: UIText;
  genders: { value: string; label: string }[];
  validation: {
    minNameLength: number;
    maxNameLength: number;
    minAge: number;
    maxAge: number;
  };
  enableSounds: boolean;
};

export type OpenPayload = {
  framework: string;
  characters: Character[];
  slots: number;
  ui: UIConfig;
};

export type SpawnPickerPayload = {
  character: Character;
  options: SpawnOption[];
  previewFlyTo?: boolean;
  previewFlyDurationMs?: number;
};

export type CreateResult =
  | { ok: true; character: Character }
  | { ok: false; reason: string };

export type DeleteResult =
  | { ok: true; cid: string; characters: Character[] }
  | { ok: false; reason: string };
