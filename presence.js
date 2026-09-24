// presence.js — online/offline status for Student Marketplace.
//
// How it works: signed-in users send a lightweight heartbeat (RPC touch_presence)
// every minute while a tab is visible. Anyone can then ask "how many seconds ago
// was user X last seen?" (RPC get_presence). Someone counts as "online" if their
// last heartbeat was within ONLINE_WINDOW_S seconds. The server returns a relative
// number of seconds, so a visitor with a wrong device clock still sees the right thing.

export const HEARTBEAT_MS = 60 * 1000;
export const ONLINE_WINDOW_S = 150; // 2 missed heartbeats' worth of slack

let started = false;

export function startPresence(supabase, userId) {
  if (started || !userId) return;
  started = true;
  const beat = () => {
    if (document.visibilityState === 'hidden') return;
    supabase.rpc('touch_presence').then(() => {}, () => {}); // best-effort; never break the page
  };
  beat();
  setInterval(beat, HEARTBEAT_MS);
  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible') beat();
  });
}

// Returns { [userId]: secondsAgo } — users who have never been seen are absent.
export async function fetchPresence(supabase, userIds) {
  const ids = [...new Set((userIds || []).filter(Boolean))];
  const out = {};
  if (!ids.length) return out;
  try {
    // get_presence caps at 50 ids per call, so chunk larger lists
    for (let i = 0; i < ids.length; i += 50) {
      const { data } = await supabase.rpc('get_presence', { p_user_ids: ids.slice(i, i + 50) });
      (data || []).forEach(r => { out[r.user_id] = r.seconds_ago; });
    }
  } catch (_) { /* presence is a nicety, never fatal */ }
  return out;
}

export function isOnline(secondsAgo) {
  return typeof secondsAgo === 'number' && secondsAgo <= ONLINE_WINDOW_S;
}

// "Online" or "Offline" — no "last seen" detail.
export function presenceLabel(secondsAgo) {
  return isOnline(secondsAgo) ? 'Online' : 'Offline';
}

// Updates every .pdot[data-uid] (the green/grey dot on avatars) and
// .pstatus[data-uid] (the text label) on the page from a presence map.
export function applyPresence(map, root) {
  const scope = root || document;
  scope.querySelectorAll('.pdot[data-uid]').forEach(el => {
    el.classList.toggle('on', isOnline(map[el.dataset.uid]));
  });
  scope.querySelectorAll('.pstatus[data-uid]').forEach(el => {
    const s = map[el.dataset.uid];
    el.textContent = presenceLabel(s);
    el.classList.toggle('on', isOnline(s));
  });
}
