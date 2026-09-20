// avatar.js — profile pictures: rendering helpers + the upload flow.

const COLORS = ['#7c3aed', '#2563eb', '#059669', '#d97706', '#dc2626', '#db2777', '#0891b2', '#65a30d'];

export function escapeHtml(s) {
  return String(s ?? '').replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}
export function initialOf(name) { return ((name || '?').trim().charAt(0) || '?').toUpperCase(); }
export function colorFor(name) {
  let h = 0; const s = name || 'U';
  for (let i = 0; i < s.length; i++) h = s.charCodeAt(i) + ((h << 5) - h);
  return COLORS[Math.abs(h) % COLORS.length];
}
// A user's profile picture, falling back to their store logo (sellers) if they haven't set one
export function pickAvatar(p) { return (p && (p.avatar_url || p.store_logo_url)) || null; }

// Round avatar: the picture if there is one, otherwise a coloured circle with the
// person's initial. `uid` + `dot` add the online/offline dot (kept in sync by
// applyPresence in presence.js).
export function avatarHTML({ url, name, size = 40, uid = null, dot = false }) {
  const inner = url
    ? '<img src="' + escapeHtml(url) + '" alt="" loading="lazy" onerror="this.remove()"/>'
    : '';
  return '<span class="av" style="width:' + size + 'px;height:' + size + 'px;font-size:' + Math.round(size * 0.4) +
    'px;background:' + colorFor(name) + '">' + escapeHtml(initialOf(name)) + inner +
    (dot && uid ? '<i class="pdot" data-uid="' + escapeHtml(uid) + '"></i>' : '') + '</span>';
}

// Centre-crops to a square and resizes to 512px — a profile picture never needs more.
function cropToAvatar(file) {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const reader = new FileReader();
    reader.onload = e => { img.src = e.target.result; };
    reader.onerror = reject;
    img.onload = () => {
      const side = Math.min(img.width, img.height);
      const out = Math.min(512, side);
      const canvas = document.createElement('canvas');
      canvas.width = out; canvas.height = out;
      canvas.getContext('2d').drawImage(img, (img.width - side) / 2, (img.height - side) / 2, side, side, 0, 0, out, out);
      canvas.toBlob(b => b ? resolve(new File([b], 'avatar.jpg', { type: 'image/jpeg' })) : reject(new Error('Could not process image')), 'image/jpeg', 0.85);
    };
    img.onerror = () => reject(new Error('That file does not look like an image'));
    reader.readAsDataURL(file);
  });
}

// Wires up the "Profile Picture" upload block (ids: avatar-input, btn-avatar-change,
// btn-avatar-remove, avatar-preview, avatar-err). Uploading/removing saves straight
// away — no need to press the form's Save button. Returns { setUser(url,name) }.
export function bindAvatarUploader(supabase, userId, { url, name, onChange }) {
  const $ = id => document.getElementById(id);
  const input = $('avatar-input'), preview = $('avatar-preview'), err = $('avatar-err');
  const changeBtn = $('btn-avatar-change'), removeBtn = $('btn-avatar-remove');
  let cur = url || null, curName = name || '';

  function paint() {
    preview.innerHTML = cur
      ? '<img src="' + escapeHtml(cur) + '" alt="Your profile picture"/>'
      : '<span style="background:' + colorFor(curName) + '">' + escapeHtml(initialOf(curName)) + '</span>';
    removeBtn.style.display = cur ? 'inline-block' : 'none';
    changeBtn.textContent = cur ? '📷 Change photo' : '📷 Upload photo';
  }
  const say = (msg, ok) => { err.style.color = ok ? '#2e7d32' : '#9333ea'; err.textContent = msg; };

  // Old picture files are removed so storage doesn't fill up with abandoned uploads
  function pathOf(u) {
    const m = u && u.match(/\/listing-images\/(.+)$/);
    return m && m[1].startsWith(userId + '/avatar-') ? decodeURIComponent(m[1]) : null;
  }
  async function dropFile(u) { const p = pathOf(u); if (p) await supabase.storage.from('listing-images').remove([p]).catch(() => {}); }

  async function save(newUrl, oldUrl) {
    const { error } = await supabase.from('profiles').update({ avatar_url: newUrl }).eq('id', userId);
    if (error) { say('❌ ' + error.message); return false; }
    cur = newUrl; paint(); onChange && onChange(cur);
    if (oldUrl && oldUrl !== newUrl) dropFile(oldUrl);
    return true;
  }

  changeBtn.onclick = () => input.click();
  input.onchange = async () => {
    const file = input.files[0]; input.value = '';
    if (!file) return;
    say('');
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type)) return say('❌ Only JPG, PNG or WEBP images');
    if (file.size > 8 * 1024 * 1024) return say('❌ That photo is over 8MB — pick a smaller one');
    changeBtn.disabled = true; changeBtn.textContent = 'Uploading...';
    try {
      const blob = await cropToAvatar(file);
      const fname = userId + '/avatar-' + Date.now() + '.jpg';
      const { error } = await supabase.storage.from('listing-images').upload(fname, blob, { cacheControl: '31536000', upsert: false });
      if (error) throw error;
      const { data: u } = supabase.storage.from('listing-images').getPublicUrl(fname);
      const old = cur;
      if (await save(u.publicUrl, old)) say('✅ Profile picture updated', true);
      else dropFile(u.publicUrl);
    } catch (e) { say('❌ ' + (e.message || 'Upload failed')); }
    changeBtn.disabled = false; paint();
  };
  removeBtn.onclick = async () => {
    say('');
    const old = cur;
    if (await save(null, null)) { dropFile(old); say('Profile picture removed', true); }
  };

  paint();
  return { setUser(u, n) { cur = u || null; curName = n || ''; paint(); }, setName(n) { curName = n || ''; if (!cur) paint(); } };
}
