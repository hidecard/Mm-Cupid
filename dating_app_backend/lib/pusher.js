const Pusher = require('pusher');

let pusherInstance = null;

function getPusher() {
  if (!pusherInstance) {
    if (!process.env.PUSHER_APP_ID || !process.env.PUSHER_KEY || !process.env.PUSHER_SECRET) {
      console.warn('Pusher credentials not configured. Real-time chat will not be available.');
      return null;
    }

    pusherInstance = new Pusher({
      appId: process.env.PUSHER_APP_ID,
      key: process.env.PUSHER_KEY,
      secret: process.env.PUSHER_SECRET,
      cluster: process.env.PUSHER_CLUSTER || 'us2',
      useTLS: true,
    });
  }

  return pusherInstance;
}

function triggerMessage(roomId, messageData) {
  const pusher = getPusher();
  if (!pusher) {
    console.log('Pusher not configured. Skipping real-time broadcast.');
    return Promise.resolve();
  }

  return pusher.trigger(`chat-room-${roomId}`, 'new-message', messageData);
}

function triggerMatch(userId, matchData) {
  const pusher = getPusher();
  if (!pusher) {
    return Promise.resolve();
  }

  return pusher.trigger(`user-${userId}`, 'new-match', matchData);
}

module.exports = {
  getPusher,
  triggerMessage,
  triggerMatch,
};
