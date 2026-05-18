declare global {
  interface Window {
    GetParentResourceName?: () => string;
  }
}

const resourceName = () =>
  typeof window.GetParentResourceName === 'function'
    ? window.GetParentResourceName()
    : 'cc_multichar';

export async function nuiPost<T = unknown>(name: string, data: unknown = {}): Promise<T | null> {
  try {
    const res = await fetch(`https://${resourceName()}/${name}`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(data),
    });
    if (!res.ok) return null;
    const text = await res.text();
    if (!text) return null;
    return JSON.parse(text) as T;
  } catch {
    return null;
  }
}

type Handler = (data: any) => void;
const handlers: Record<string, Set<Handler>> = {};

export function onMessage(action: string, handler: Handler) {
  if (!handlers[action]) handlers[action] = new Set();
  handlers[action].add(handler);
  return () => handlers[action]?.delete(handler);
}

window.addEventListener('message', (event) => {
  const msg = event.data;
  if (!msg || typeof msg.action !== 'string') return;
  const set = handlers[msg.action];
  if (!set) return;
  for (const h of set) h(msg.data);
});
