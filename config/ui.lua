--[[
  cc_multichar — UI configuration
  ---------------------------------------------------------------------------
  Controls every text string, theme color, and validation rule used by the
  React NUI. Theme values become CSS custom properties (--cc-accent etc.)
  and are applied at runtime when the selector opens, so changing colors
  here does not require a UI rebuild.

  After editing text/labels, no rebuild is needed either — they are sent
  to the NUI in the open payload. Only adding new fields or layout changes
  to ui/src/* requires `cd ui && npm run build`.
]]

Config = Config or {}

Config.UI = {

  -- ===========================================================================
  -- Branding
  -- ===========================================================================
  -- Shown in the top-left corner of the selector and (optionally) as the
  -- Discord rich presence "details" line.
  serverName     = 'My RP Server',
  serverTagline  = 'Choose your story',

  -- ===========================================================================
  -- Theme (CSS variables)
  -- ===========================================================================
  -- All values must be valid CSS color strings (hex, rgb(), rgba(), hsl()).
  -- Applied as --cc-* on the document root so the React app picks them up.
  --
  --   accent       - primary accent color (Play button, highlights, focus rings)
  --   accentHover  - hover state for accent surfaces
  --   background   - root tint applied over the cinematic scene
  --   panel        - background of character panel / modals / picker
  --   panelBorder  - border lines and dividers
  --   text         - primary text color
  --   textMuted    - secondary/disabled text
  --   danger       - destructive action color (Delete)
  --   success      - confirmation color (rarely visible by default)
  theme = {
    accent       = '#e8c275',
    accentHover  = '#f5d189',
    background   = 'rgba(8, 10, 16, 0.55)',
    panel        = 'rgba(20, 24, 34, 0.78)',
    panelBorder  = 'rgba(255, 255, 255, 0.08)',
    text         = '#f3f4f6',
    textMuted    = '#9aa3b2',
    danger       = '#ef4444',
    success      = '#22c55e',
  },

  -- ===========================================================================
  -- Fields shown on the character panel
  -- ===========================================================================
  -- Each entry references a top-level field on the character object served
  -- from Characters.Load. Unrecognized fields are ignored.
  -- Available: name, dob, gender, nationality, job, bank, cash, playtime
  showFields = { 'name', 'dob', 'gender', 'nationality', 'job', 'bank', 'cash', 'playtime' },

  -- ===========================================================================
  -- Localized text
  -- ===========================================================================
  -- Every string visible on the NUI is here. To localize, override this
  -- table per-server.
  text = {
    selectTitle      = 'Select a Character',
    createTitle      = 'Create a New Character',
    spawnTitle       = 'Choose Where to Spawn',
    deleteConfirm    = "Type the character's full name to confirm deletion.",
    emptySlot        = 'Empty Slot',
    createButton     = 'Create Character',
    playButton       = 'Play',
    deleteButton     = 'Delete',
    spawnButton      = 'Spawn Here',
    backButton       = 'Back',
    cancelButton     = 'Cancel',
    nationalityHint  = 'American, British, etc.',
  },

  -- ===========================================================================
  -- Create form
  -- ===========================================================================
  -- Gender options offered on the create form. Each option's `value` is
  -- what gets stored ('m'/'f' for QBCore/Qbox; ESX uses the same).
  genders = {
    { value = 'm', label = 'Male' },
    { value = 'f', label = 'Female' },
  },

  -- ===========================================================================
  -- Create form validation
  -- ===========================================================================
  -- Validated both client-side (instant feedback) and server-side (security).
  -- Server-side validation in server/main.lua is the source of truth.
  --
  --   minNameLength / maxNameLength : length bounds for first AND last name
  --   minAge / maxAge               : computed from the DOB the player enters
  validation = {
    minNameLength = 2,
    maxNameLength = 24,
    minAge = 18,
    maxAge = 90,
  },

  -- ===========================================================================
  -- Sound effects within the NUI (button clicks, etc.)
  -- ===========================================================================
  -- When true, the UI plays optional click sounds. The NUI source does not
  -- currently bundle audio; enable this only if you add audio files to
  -- ui/public and wire them into the React components.
  enableSounds = true,
}
