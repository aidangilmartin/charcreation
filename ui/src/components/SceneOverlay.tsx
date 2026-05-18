import { useEffect, useRef } from 'react';
import { nuiPost } from '../nui';

type Props = {
  hoveredName: string | null;
  enabled: boolean;
};

// Transparent fullscreen layer that:
//   - tracks the cursor and forwards normalized coords to Lua (for raycast)
//   - forwards background clicks to Lua so it can select the hovered ped
//   - renders a small floating label near the cursor when hovering a player ped
export function SceneOverlay({ hoveredName, enabled }: Props) {
  const ref = useRef<HTMLDivElement>(null);
  const labelRef = useRef<HTMLDivElement>(null);
  const mouseRef = useRef({ x: 0, y: 0 });
  const lastSentRef = useRef(0);

  useEffect(() => {
    if (!enabled) return;
    let raf = 0;
    const tick = () => {
      const now = performance.now();
      if (now - lastSentRef.current > 50) {
        lastSentRef.current = now;
        nuiPost('cursor', {
          x: mouseRef.current.x / window.innerWidth,
          y: mouseRef.current.y / window.innerHeight,
        });
      }
      if (labelRef.current) {
        labelRef.current.style.transform = `translate(${mouseRef.current.x + 16}px, ${mouseRef.current.y + 16}px)`;
      }
      raf = requestAnimationFrame(tick);
    };
    raf = requestAnimationFrame(tick);
    return () => cancelAnimationFrame(raf);
  }, [enabled]);

  const onMove = (e: React.MouseEvent) => {
    mouseRef.current = { x: e.clientX, y: e.clientY };
  };

  const onClick = () => {
    if (!enabled) return;
    nuiPost('selectClick');
  };

  return (
    <div
      ref={ref}
      className="cc-scene-overlay"
      onMouseMove={onMove}
      onClick={onClick}
    >
      {hoveredName && (
        <div ref={labelRef} className="cc-hover-label">
          {hoveredName}
          <span className="cc-hover-hint">Click to select</span>
        </div>
      )}
    </div>
  );
}
