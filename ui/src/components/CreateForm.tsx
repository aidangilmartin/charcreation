import { useMemo, useState } from 'react';
import type { UIConfig } from '../types';

type Props = {
  ui: UIConfig;
  error: string | null;
  disabled: boolean;
  onCancel: () => void;
  onSubmit: (info: {
    firstname: string;
    lastname: string;
    dob: string;
    gender: string;
    nationality: string;
  }) => void;
};

function ageFromDob(dob: string): number | null {
  const m = dob.match(/^(\d{4})-(\d{2})-(\d{2})$/);
  if (!m) return null;
  const [, y, mo, d] = m;
  const date = new Date(Number(y), Number(mo) - 1, Number(d));
  if (
    date.getFullYear() !== Number(y) ||
    date.getMonth() !== Number(mo) - 1 ||
    date.getDate() !== Number(d)
  ) {
    return null;
  }
  const now = new Date();
  let age = now.getFullYear() - date.getFullYear();
  const md = now.getMonth() - date.getMonth();
  if (md < 0 || (md === 0 && now.getDate() < date.getDate())) age--;
  return age;
}

export function CreateForm({ ui, error, disabled, onCancel, onSubmit }: Props) {
  const [firstname, setFirstname] = useState('');
  const [lastname, setLastname] = useState('');
  const [dob, setDob] = useState('');
  const [gender, setGender] = useState(ui.genders[0]?.value ?? 'm');
  const [nationality, setNationality] = useState('');

  const v = ui.validation;

  const validation = useMemo(() => {
    const issues: string[] = [];
    if (firstname.trim().length < v.minNameLength) issues.push('First name too short');
    if (firstname.length > v.maxNameLength) issues.push('First name too long');
    if (lastname.trim().length < v.minNameLength) issues.push('Last name too short');
    if (lastname.length > v.maxNameLength) issues.push('Last name too long');
    if (!/^\d{4}-\d{2}-\d{2}$/.test(dob)) {
      issues.push('Date of birth must be YYYY-MM-DD');
    } else {
      const age = ageFromDob(dob);
      if (age === null) issues.push('Invalid date of birth');
      else if (age < v.minAge) issues.push(`Must be at least ${v.minAge}`);
      else if (age > v.maxAge) issues.push(`Must be ${v.maxAge} or younger`);
    }
    if (!nationality.trim()) issues.push('Nationality required');
    if (nationality.length > v.maxNameLength) issues.push('Nationality too long');
    return issues;
  }, [firstname, lastname, dob, nationality, v]);

  const canSubmit = !disabled && validation.length === 0;

  return (
    <div className="cc-form-wrap">
      <div className="cc-form-card">
        <div className="cc-form-title">{ui.text.createTitle || 'Create a New Character'}</div>

        <div className="cc-form-grid">
          <label className="cc-field">
            <span>First Name</span>
            <input
              type="text"
              value={firstname}
              maxLength={v.maxNameLength}
              onChange={(e) => setFirstname(e.target.value)}
            />
          </label>
          <label className="cc-field">
            <span>Last Name</span>
            <input
              type="text"
              value={lastname}
              maxLength={v.maxNameLength}
              onChange={(e) => setLastname(e.target.value)}
            />
          </label>
          <label className="cc-field">
            <span>Date of Birth</span>
            <input
              type="text"
              placeholder="YYYY-MM-DD"
              value={dob}
              onChange={(e) => setDob(e.target.value)}
            />
          </label>
          <label className="cc-field">
            <span>Gender</span>
            <select value={gender} onChange={(e) => setGender(e.target.value)}>
              {ui.genders.map((g) => (
                <option key={g.value} value={g.value}>{g.label}</option>
              ))}
            </select>
          </label>
          <label className="cc-field cc-field-full">
            <span>Nationality</span>
            <input
              type="text"
              placeholder={ui.text.nationalityHint || ''}
              value={nationality}
              maxLength={v.maxNameLength}
              onChange={(e) => setNationality(e.target.value)}
            />
          </label>
        </div>

        {validation.length > 0 && (
          <ul className="cc-form-issues">
            {validation.map((m) => <li key={m}>{m}</li>)}
          </ul>
        )}
        {error && <div className="cc-form-error">{error}</div>}

        <div className="cc-actions">
          <button className="cc-btn" disabled={disabled} onClick={onCancel}>
            {ui.text.cancelButton || 'Cancel'}
          </button>
          <button
            className="cc-btn cc-btn-primary"
            disabled={!canSubmit}
            onClick={() =>
              onSubmit({
                firstname: firstname.trim(),
                lastname: lastname.trim(),
                dob: dob.trim(),
                gender,
                nationality: nationality.trim(),
              })
            }
          >
            Continue
          </button>
        </div>
      </div>
    </div>
  );
}
