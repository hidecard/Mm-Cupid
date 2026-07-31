require('dotenv').config();

const express = require('express');
const serverless = require('serverless-http');
const cors = require('cors');
const bcrypt = require('bcryptjs');
const jwt = require('jsonwebtoken');
const db = require('../lib/db');
const { authenticate, requireOnboarded, hashPassword, comparePassword, generateToken } = require('../lib/auth');
const pusher = require('../lib/pusher');

const app = express();

app.use(cors());
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Health check
app.get('/api/health', (req, res) => {
  res.json({ success: true, message: 'Server is running', timestamp: new Date().toISOString() });
});

// --- Auth Routes ---

app.post('/api/auth/register', async (req, res) => {
  try {
    const { name, email, password, gender, interested_in, birthday } = req.body;

    if (!name || !email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Name, email, and password are required',
      });
    }

    if (password.length < 6) {
      return res.status(400).json({
        success: false,
        error: 'Password must be at least 6 characters',
      });
    }

    const existingUser = await db.get(
      'SELECT id FROM users WHERE email = ?',
      [email.toLowerCase()]
    );

    if (existingUser) {
      return res.status(409).json({
        success: false,
        error: 'Email already registered',
      });
    }

    const passwordHash = await hashPassword(password);

    let isOnboarded = true;
    let genderValue = gender || null;
    let interestedValue = interested_in || null;
    let birthdayValue = birthday || null;

    if (!gender || !interested_in || !birthday) {
      isOnboarded = false;
    }

    const result = await db.run(
      'INSERT INTO users (name, email, password_hash, gender, interested_in, birthday, is_onboarded) VALUES (?, ?, ?, ?, ?, ?, ?)',
      [name, email.toLowerCase(), passwordHash, genderValue, interestedValue, birthdayValue, isOnboarded]
    );

    const token = generateToken({ userId: result.insertId });

    const user = await db.get(
      'SELECT id, name, email, gender, interested_in, birthday, bio, profile_pic, is_onboarded, created_at FROM users WHERE id = ?',
      [result.insertId]
    );

    return res.status(201).json({
      success: true,
      message: 'User registered successfully',
      token,
      user,
    });
  } catch (error) {
    console.error('Registration error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

app.post('/api/auth/login', async (req, res) => {
  try {
    const { email, password } = req.body;

    if (!email || !password) {
      return res.status(400).json({
        success: false,
        error: 'Email and password are required',
      });
    }

    const user = await db.get(
      'SELECT id, name, email, password_hash, gender, interested_in, birthday, bio, profile_pic, latitude, longitude, is_onboarded, created_at FROM users WHERE email = ?',
      [email.toLowerCase()]
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password',
      });
    }

    const passwordValid = await comparePassword(password, user.password_hash);

    if (!passwordValid) {
      return res.status(401).json({
        success: false,
        error: 'Invalid email or password',
      });
    }

    const token = generateToken({ userId: user.id });

    const { password_hash, ...userWithoutPassword } = user;

    return res.json({
      success: true,
      message: 'Login successful',
      token,
      user: userWithoutPassword,
    });
  } catch (error) {
    console.error('Login error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// --- Profile Routes ---

app.get('/api/profile', authenticate, async (req, res) => {
  try {
    return res.json({
      success: true,
      user: req.user,
    });
  } catch (error) {
    console.error('Profile fetch error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

app.put('/api/profile', authenticate, async (req, res) => {
  try {
    const { name, bio, profile_pic, gender, interested_in, birthday, latitude, longitude } = req.body;

    const updates = {};
    const params = [];

    if (name !== undefined) {
      updates.name = name;
      params.push(name);
    }
    if (bio !== undefined) {
      updates.bio = bio;
      params.push(bio);
    }
    if (profile_pic !== undefined) {
      updates.profile_pic = profile_pic;
      params.push(profile_pic);
    }
    if (gender !== undefined) {
      updates.gender = gender;
      params.push(gender);
    }
    if (interested_in !== undefined) {
      updates.interested_in = interested_in;
      params.push(interested_in);
    }
    if (birthday !== undefined) {
      updates.birthday = birthday;
      params.push(birthday);
    }
    if (latitude !== undefined) {
      updates.latitude = latitude;
      params.push(latitude);
    }
    if (longitude !== undefined) {
      updates.longitude = longitude;
      params.push(longitude);
    }

    if (params.length === 0) {
      return res.status(400).json({
        success: false,
        error: 'No fields to update',
      });
    }

    // Set is_onboarded = true if gender, interested_in, and birthday are provided
    const hasRequiredFields = gender !== undefined || interested_in !== undefined || birthday !== undefined;
    if (hasRequiredFields) {
      const hasAllRequired = gender !== undefined && interested_in !== undefined && birthday !== undefined;
      if (hasAllRequired) {
        updates.is_onboarded = 1;
        params.push(1);
      }
    }

    params.push(req.user.id);

    let setClause = Object.keys(updates).map(k => `${k} = ?`).join(', ');
    await db.run(
      `UPDATE users SET ${setClause} WHERE id = ?`,
      params
    );

    const updatedUser = await db.get(
      'SELECT id, name, email, gender, interested_in, birthday, bio, profile_pic, latitude, longitude, is_onboarded, created_at FROM users WHERE id = ?',
      [req.user.id]
    );

    // Update req.user for subsequent middleware
    req.user = { ...req.user, ...updatedUser, id: req.user.id };

    return res.json({
      success: true,
      message: 'Profile updated successfully',
      user: updatedUser,
    });
  } catch (error) {
    console.error('Profile update error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// --- Discovery Routes ---

app.get('/api/profiles', authenticate, requireOnboarded, async (req, res) => {
  try {
    const myId = req.user.id;
    const myInterestedIn = req.user.interested_in;

    // Build WHERE clause for gender filter
    let genderFilter = '';
    const params = [myId];

    if (myInterestedIn === 'both') {
      // No additional gender filter needed
    } else {
      genderFilter = 'AND gender = ?';
      params.push(myInterestedIn);
    }

    // Optional location-based filtering
    let locationFilter = '';
    if (req.query.lat && req.query.lng) {
      locationFilter = 'AND latitude IS NOT NULL AND longitude IS NOT NULL';
    }

    const sql = `
      SELECT id, name, bio, profile_pic, birthday, gender, latitude, longitude, created_at
      FROM users
      WHERE id != ?
      ${genderFilter}
      ${locationFilter}
      AND id NOT IN (
        SELECT liked_id FROM swipes WHERE liker_id = ?
      )
      AND id NOT IN (
        SELECT 
          CASE WHEN user_one_id = ? THEN user_two_id 
               WHEN user_two_id = ? THEN user_one_id 
          END
        FROM matches 
        WHERE user_one_id = ? OR user_two_id = ?
      )
      ORDER BY created_at DESC
      LIMIT 10
    `;

    params.push(myId, myId, myId, myId, myId);

    const profiles = await db.query(sql, params);

    return res.json({
      success: true,
      profiles,
    });
  } catch (error) {
    console.error('Profiles fetch error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// --- Swipe & Match Routes ---

app.post('/api/swipe', authenticate, requireOnboarded, async (req, res) => {
  try {
    const { liked_id, action } = req.body;
    const likerId = req.user.id;

    if (!liked_id || !action) {
      return res.status(400).json({
        success: false,
        error: 'liked_id and action are required',
      });
    }

    if (!['like', 'dislike'].includes(action)) {
      return res.status(400).json({
        success: false,
        error: 'Action must be "like" or "dislike"',
      });
    }

    const likedIdNum = parseInt(liked_id);

    if (likedIdNum === likerId) {
      return res.status(400).json({
        success: false,
        error: 'Cannot swipe on yourself',
      });
    }

    // Insert swipe record
    await db.run(
      'INSERT INTO swipes (liker_id, liked_id, action) VALUES (?, ?, ?)',
      [likerId, likedIdNum, action]
    );

    // Only check for match if action is 'like'
    let matchResult = null;
    let roomId = null;

    if (action === 'like') {
      // Check if the liked user has also liked the current user
      const reciprocal = await db.get(
        'SELECT * FROM swipes WHERE liker_id = ? AND liked_id = ? AND action = ?',
        [likedIdNum, likerId, 'like']
      );

      if (reciprocal) {
        // It's a match!
        const smallerId = Math.min(likerId, likedIdNum);
        const largerId = Math.max(likerId, likedIdNum);

        try {
          const matchResultData = await db.run(
            'INSERT INTO matches (user_one_id, user_two_id) VALUES (?, ?)',
            [smallerId, largerId]
          );

          const matchId = matchResultData.insertId;

          // Create chat room for this match
          const roomResult = await db.run(
            'INSERT INTO chat_rooms (match_id) VALUES (?)',
            [matchId]
          );

          roomId = roomResult.insertId;

          // Get the matched user's profile info
          const matchedUser = await db.get(
            'SELECT id, name, profile_pic FROM users WHERE id = ?',
            [likedIdNum]
          );

          // Trigger real-time match notification via Pusher
          pusher.triggerMatch(likerId, {
            match_id: matchId,
            room_id: roomId,
            user: {
              id: matchedUser.id,
              name: matchedUser.name,
              profile_pic: matchedUser.profile_pic,
            },
            created_at: new Date().toISOString(),
          });

          pusher.triggerMatch(likedIdNum, {
            match_id: matchId,
            room_id: roomId,
            user: {
              id: req.user.id,
              name: req.user.name,
              profile_pic: req.user.profile_pic,
            },
            created_at: new Date().toISOString(),
          });

          matchResult = {
            match_id: matchId,
            room_id: roomId,
            user: {
              id: matchedUser.id,
              name: matchedUser.name,
              profile_pic: matchedUser.profile_pic,
            },
          };
        } catch (matchError) {
          // If match creation fails (e.g., duplicate), it's OK - match already exists
          console.log('Match creation note:', matchError.message);
        }
      }
    }

    const response = {
      success: true,
      message: action === 'like'
        ? (matchResult ? 'It\'s a match!' : 'Profile liked')
        : 'Profile disliked',
      match: matchResult ? {
        matched: true,
        match_id: matchResult.match_id,
        room_id: matchResult.room_id,
        user: matchResult.user,
      } : {
        matched: false,
      },
    };

    return res.json(response);
  } catch (error) {
    console.error('Swipe error:', error);

    if (error.message.includes('UNIQUE') || error.message.includes('unique')) {
      return res.status(409).json({
        success: false,
        error: 'You have already swiped on this profile',
      });
    }

    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// --- Match Routes ---

app.get('/api/matches', authenticate, requireOnboarded, async (req, res) => {
  try {
    const myId = req.user.id;

    const sql = `
      SELECT m.id AS match_id, m.created_at AS matched_at,
             cr.id AS room_id,
             u1.id AS user1_id, u1.name AS user1_name, u1.profile_pic AS user1_pic,
             u2.id AS user2_id, u2.name AS user2_name, u2.profile_pic AS user2_pic
      FROM matches m
      LEFT JOIN chat_rooms cr ON m.id = cr.match_id
      JOIN users u1 ON m.user_one_id = u1.id
      JOIN users u2 ON m.user_two_id = u2.id
      WHERE m.user_one_id = ? OR m.user_two_id = ?
      ORDER BY m.created_at DESC
    `;

    const results = await db.query(sql, [myId, myId]);

    const matches = results.map(row => {
      const otherUser = row.user1_id === myId
        ? { id: row.user2_id, name: row.user2_name, profile_pic: row.user2_pic }
        : { id: row.user1_id, name: row.user1_name, profile_pic: row.user1_pic };

      return {
        match_id: row.match_id,
        matched_at: row.matched_at,
        room_id: row.room_id || null,
        user: otherUser,
      };
    });

    return res.json({
      success: true,
      matches,
    });
  } catch (error) {
    console.error('Matches fetch error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// --- Chat Routes ---

app.get('/api/messages/:room_id', authenticate, async (req, res) => {
  try {
    const roomId = parseInt(req.params.room_id);

    if (isNaN(roomId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid room_id',
      });
    }

    // Verify the user has access to this room
    const roomCheck = await db.get(
      `SELECT cr.id FROM chat_rooms cr
       JOIN matches m ON cr.match_id = m.id
       WHERE cr.id = ? AND (m.user_one_id = ? OR m.user_two_id = ?)`,
      [roomId, req.user.id, req.user.id]
    );

    if (!roomCheck) {
      return res.status(403).json({
        success: false,
        error: 'Access denied to this chat room',
      });
    }

    const messages = await db.query(
      `SELECT m.id, m.room_id, m.sender_id, m.message_text, m.created_at,
              u.name as sender_name, u.profile_pic as sender_pic
       FROM messages m
       JOIN users u ON m.sender_id = u.id
       WHERE m.room_id = ?
       ORDER BY m.created_at ASC
       LIMIT 100`,
      [roomId]
    );

    return res.json({
      success: true,
      messages,
    });
  } catch (error) {
    console.error('Messages fetch error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

app.post('/api/message', authenticate, async (req, res) => {
  try {
    const { room_id, message_text } = req.body;

    if (!room_id || !message_text) {
      return res.status(400).json({
        success: false,
        error: 'room_id and message_text are required',
      });
    }

    const roomIdNum = parseInt(room_id);

    // Verify the user has access to this room
    const roomCheck = await db.get(
      `SELECT cr.id, m.user_one_id, m.user_two_id
       FROM chat_rooms cr
       JOIN matches m ON cr.match_id = m.id
       WHERE cr.id = ?`,
      [roomIdNum]
    );

    if (!roomCheck) {
      return res.status(404).json({
        success: false,
        error: 'Chat room not found',
      });
    }

    if (req.user.id !== roomCheck.user_one_id && req.user.id !== roomCheck.user_two_id) {
      return res.status(403).json({
        success: false,
        error: 'Access denied to this chat room',
      });
    }

    // Insert message into database
    const result = await db.run(
      'INSERT INTO messages (room_id, sender_id, message_text) VALUES (?, ?, ?)',
      [roomIdNum, req.user.id, message_text]
    );

    const newMessage = {
      id: result.insertId,
      room_id: roomIdNum,
      sender_id: req.user.id,
      sender_name: req.user.name,
      sender_pic: req.user.profile_pic,
      message_text,
      created_at: new Date().toISOString(),
    };

    // Broadcast via Pusher for real-time delivery
    await pusher.triggerMessage(roomIdNum, newMessage);

    // Also send the recipient
    const recipientId = req.user.id === roomCheck.user_one_id ? roomCheck.user_two_id : roomCheck.user_one_id;

    return res.status(201).json({
      success: true,
      message: newMessage,
    });
  } catch (error) {
    console.error('Message send error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// --- Chat Room Route ---

app.get('/api/chat-room/:match_id', authenticate, async (req, res) => {
  try {
    const matchId = parseInt(req.params.match_id);

    if (isNaN(matchId)) {
      return res.status(400).json({
        success: false,
        error: 'Invalid match_id',
      });
    }

    // Verify the match belongs to the user
    const matchCheck = await db.get(
      'SELECT * FROM matches WHERE id = ? AND (user_one_id = ? OR user_two_id = ?)',
      [matchId, req.user.id, req.user.id]
    );

    if (!matchCheck) {
      return res.status(404).json({
        success: false,
        error: 'Match not found',
      });
    }

    // Get or create chat room
    let room = await db.get(
      'SELECT id, match_id, created_at FROM chat_rooms WHERE match_id = ?',
      [matchId]
    );

    if (!room) {
      const result = await db.run(
        'INSERT INTO chat_rooms (match_id) VALUES (?)',
        [matchId]
      );

      room = await db.get(
        'SELECT id, match_id, created_at FROM chat_rooms WHERE id = ?',
        [result.insertId]
      );
    }

    return res.json({
      success: true,
      room,
    });
  } catch (error) {
    console.error('Chat room fetch error:', error);
    return res.status(500).json({
      success: false,
      error: 'Internal server error',
    });
  }
});

// Error handler
app.use((err, req, res, next) => {
  console.error('Unhandled error:', err);
  res.status(500).json({
    success: false,
    error: 'Internal server error',
  });
});

// Export for Vercel serverless
module.exports = serverless(app);

// For local development
if (require.main === module) {
  const PORT = process.env.PORT || 3000;
  app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
    console.log(`Health check: http://localhost:${PORT}/api/health`);
  });
}
