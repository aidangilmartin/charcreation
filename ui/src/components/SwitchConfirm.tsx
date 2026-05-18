import { useState, useEffect } from 'react';
import { nuiPost } from '../nui';

type Props = {
  cooldownSeconds: number;
  rejection: { code: string; reason?: string; retryInSec?: number } | null;
  onClose: () => void;
};

const REASON_MAP: Record<string, string> = {
  in_combat: 'You cannot switch while in combat.',
  in_vehicle: 'Get out of the vehicle first.',
  cuffed: 'You are restrained.',
  dead: 'You are not alive.',
  swimming: 'You are in the water.',
};

export function SwitchConfirm({ cooldownSeconds, rejection, onClose }: Props) {
  const [confirming, setConfirming] = useState(false);

  useEffect(() => {
    if (rejection) setConfirming(false);
  }, [rejection]);

  const onConfirm = () => {
    setConfirming(true);
    nuiPost('confirmSwitch');
  };

  const onCancel = () => {
    nuiPost('cancelSwitch');
    onClose();
  };

  const rejectionText = rejection
    ? rejection.code === 'cooldown'
      ? `Switch is on cooldown. Try again in ${rejection.retryInSec ?? cooldownSeconds}s.`
      : REASON_MAP[rejection.reason ?? ''] || `Switch blocked: ${rejection.reason ?? rejection.code}`
    : null;

  return (
    <div className="cc-modal-backdrop">
      <div className="cc-modal">
        <div className="cc-modal-title">Switch Character?</div>
        <p className="cc-modal-text">
          Your current character will be saved and you'll return to the
          selector. Cooldown after switching: {cooldownSeconds}s.
        </p>
        {rejectionText && <div className="cc-form-error">{rejectionText}</div>}
        <div className="cc-actions">
          <button className="cc-btn" disabled={confirming} onClick={onCancel}>Cancel</button>
          <button className="cc-btn cc-btn-primary" disabled={confirming} onClick={onConfirm}>
            {confirming ? 'Switching…' : 'Switch'}
          </button>
        </div>
      </div>
    </div>
  );
}
