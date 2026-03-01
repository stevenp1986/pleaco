const { WebSocketServer } = require('ws');
const crypto = require('crypto');

const PORT = parseInt(process.env.PORT || '8080', 10);
const MAX_ROOMS = 100;
const JOIN_TIMEOUT_MS = 5 * 60 * 1000; // 5 min

// Characters without confusables (no 0/O/1/I/L)
const CODE_CHARS = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
const CODE_LEN = 6;

const rooms = new Map(); // roomHash -> { clients: Set<ws>, code, timer }

function generateCode() {
  let code = '';
  const bytes = crypto.randomBytes(CODE_LEN);
  for (let i = 0; i < CODE_LEN; i++) {
    code += CODE_CHARS[bytes[i] % CODE_CHARS.length];
  }
  return code;
}

function hashCode(code) {
  return crypto.createHash('sha256').update(code).digest('hex');
}

function destroyRoom(hash) {
  const room = rooms.get(hash);
  if (!room) return;
  if (room.timer) clearTimeout(room.timer);
  rooms.delete(hash);
}

function send(ws, msg) {
  if (ws.readyState === 1) ws.send(JSON.stringify(msg));
}

function removeClientFromRoom(ws) {
  for (const [hash, room] of rooms) {
    if (!room.clients.has(ws)) continue;
    room.clients.delete(ws);
    // Notify remaining partner
    for (const peer of room.clients) {
      send(peer, { type: 'partner_left' });
    }
    // Destroy if empty
    if (room.clients.size === 0) destroyRoom(hash);
    return;
  }
}

const wss = new WebSocketServer({ port: PORT });

wss.on('connection', (ws) => {
  ws.on('close', () => removeClientFromRoom(ws));
  ws.on('error', () => removeClientFromRoom(ws));

  ws.on('message', (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }

    if (msg.type === 'ping') {
      return send(ws, { type: 'pong' });
    }

    if (msg.type === 'create') {
      if (rooms.size >= MAX_ROOMS) {
        return send(ws, { type: 'error', msg: 'Server full' });
      }
      // Remove from any existing room
      removeClientFromRoom(ws);

      const code = generateCode();
      const hash = hashCode(code);
      const timer = setTimeout(() => destroyRoom(hash), JOIN_TIMEOUT_MS);
      rooms.set(hash, { clients: new Set([ws]), code, timer });
      return send(ws, { type: 'code', code });
    }

    if (msg.type === 'join') {
      const hash = msg.room;
      const room = rooms.get(hash);
      if (!room) return send(ws, { type: 'error', msg: 'Room not found' });
      if (room.clients.size >= 2) return send(ws, { type: 'error', msg: 'Room full' });

      // Remove from any existing room
      removeClientFromRoom(ws);

      room.clients.add(ws);
      if (room.timer) { clearTimeout(room.timer); room.timer = null; }
      // Notify both
      for (const peer of room.clients) {
        send(peer, { type: 'joined' });
      }
      return;
    }

    if (msg.type === 'relay') {
      // Forward payload to partner
      for (const [, room] of rooms) {
        if (!room.clients.has(ws)) continue;
        for (const peer of room.clients) {
          if (peer !== ws) send(peer, { type: 'relay', payload: msg.payload });
        }
        return;
      }
    }
  });
});

console.log(`pleaco-relay listening on port ${PORT} (${rooms.size} rooms)`);
