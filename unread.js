// unread.js — number shown on the "Messages" badge in the nav.
// Conversations the user has MUTED are left out, so a muted chat can't keep
// nagging with a red number. If the chat-options table isn't there yet
// (migration not run) this quietly falls back to the plain count.

export async function unreadMessageCount(supabase, userId) {
  const mine = 'buyer_id.eq.' + userId + ',seller_id.eq.' + userId;
  let muted = new Set();
  try {
    const { data, error } = await supabase
      .from('conversation_settings').select('thread_key')
      .eq('user_id', userId)
      .or('muted_always.eq.true,muted_until.gt.' + new Date().toISOString());
    if (!error) muted = new Set((data || []).map(r => r.thread_key));
  } catch (_) { /* fall through to the plain count */ }

  if (!muted.size) {
    // Common case: nothing muted — a cheap count-only query.
    const { count } = await supabase.from('messages').select('id', { count: 'exact', head: true })
      .or(mine).neq('sender_id', userId).eq('is_read', false);
    return count || 0;
  }
  // Something is muted: fetch the unread rows and drop the muted conversations.
  // A conversation is "me + one other person", and an unread message always comes from
  // that other person — so a conversation's key is simply the sender's id.
  const { data } = await supabase.from('messages').select('sender_id')
    .or(mine).neq('sender_id', userId).eq('is_read', false).limit(1000);
  return (data || []).filter(m => !muted.has(String(m.sender_id).toLowerCase())).length;
}
