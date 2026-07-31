const jwt = require('jsonwebtoken');
const bcrypt = require('bcryptjs');
const db = require('./db');

const JWT_SECRET = process.env.JWT_SECRET || 'dev-secret-change-in-production';
const JWT_EXPIRES_IN = process.env.JWT_EXPIRES_IN || '7d';

async function hashPassword(password) {
  const saltRounds = 12;
  return await bcrypt.hash(password, saltRounds);
}

async function comparePassword(password, hash) {
  return await bcrypt.compare(password, hash);
}

function generateToken(payload) {
  return jwt.sign(payload, JWT_SECRET, { expiresIn: JWT_EXPIRES_IN });
}

function verifyToken(token) {
  return jwt.verify(token, JWT_SECRET);
}

async function authenticate(req, res, next) {
  const authHeader = req.headers.authorization;

  if (!authHeader || !authHeader.startsWith('Bearer ')) {
    return res.status(401).json({
      success: false,
      error: 'Access token missing or invalid',
    });
  }

  const token = authHeader.substring(7);

  try {
    const decoded = verifyToken(token);

    const user = await db.get(
      'SELECT id, name, email, gender, interested_in, birthday, bio, profile_pic, latitude, longitude, is_onboarded, created_at FROM users WHERE id = ?',
      [decoded.userId]
    );

    if (!user) {
      return res.status(401).json({
        success: false,
        error: 'User not found',
      });
    }

    req.user = {
      id: user.id,
      name: user.name,
      email: user.email,
      gender: user.gender,
      interested_in: user.interested_in,
      birthday: user.birthday,
      bio: user.bio,
      profile_pic: user.profile_pic,
      latitude: user.latitude,
      longitude: user.longitude,
      is_onboarded: user.is_onboarded,
      created_at: user.created_at,
    };

    next();
  } catch (error) {
    if (error.name === 'TokenExpiredError') {
      return res.status(401).json({
        success: false,
        error: 'Token expired',
      });
    }
    return res.status(401).json({
      success: false,
      error: 'Invalid token',
    });
  }
}

async function requireOnboarded(req, res, next) {
  if (!req.user || !req.user.is_onboarded) {
    return res.status(403).json({
      success: false,
      error: 'Profile not completed. Please complete onboarding.',
    });
  }
  next();
}

module.exports = {
  hashPassword,
  comparePassword,
  generateToken,
  verifyToken,
  authenticate,
  requireOnboarded,
};
