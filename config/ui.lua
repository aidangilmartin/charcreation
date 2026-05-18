Config = Config or {}

Config.UI = {
  serverName = 'My RP Server',
  serverTagline = 'Choose your story',

  theme = {
    -- All CSS-compatible color strings; applied as CSS variables in the NUI
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

  showFields = { 'name', 'dob', 'gender', 'nationality', 'job', 'bank', 'cash', 'playtime' },

  text = {
    selectTitle      = 'Select a Character',
    createTitle      = 'Create a New Character',
    spawnTitle       = 'Choose Where to Spawn',
    deleteConfirm    = 'Type the character\'s full name to confirm deletion.',
    emptySlot        = 'Empty Slot',
    createButton     = 'Create Character',
    playButton       = 'Play',
    deleteButton     = 'Delete',
    spawnButton      = 'Spawn Here',
    backButton       = 'Back',
    cancelButton     = 'Cancel',
    nationalityHint  = 'American, British, etc.',
  },

  -- Genders shown in the create form
  genders = {
    { value = 'm', label = 'Male' },
    { value = 'f', label = 'Female' },
  },

  -- Validation rules for the create form
  validation = {
    minNameLength = 2,
    maxNameLength = 24,
    minAge = 18,
    maxAge = 90,
  },

  enableSounds = true,
}
