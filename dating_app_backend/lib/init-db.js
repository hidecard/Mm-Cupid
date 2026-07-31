require('dotenv').config();
const db = require('./db');
const fs = require('fs');
const path = require('path');

function parseStatements(schema) {
  const cleaned = schema
    .split('\n')
    .filter(line => !line.trim().startsWith('--'))
    .join('\n');

  return cleaned
    .split(';')
    .map(s => s.trim())
    .filter(s => s.length > 0 && !s.startsWith('PRAGMA'));
}

async function initDb() {
  try {
    await db.init();

    const schemaPath = path.join(
      __dirname,
      '..',
      db.type === 'mysql' ? 'schema_mysql.sql' : 'schema_turso.sql'
    );

    const schema = fs.readFileSync(schemaPath, 'utf8');
    const statements = parseStatements(schema);

    for (const stmt of statements) {
      await db.exec(stmt);
    }

    console.log(`Database initialized successfully using ${db.type === 'mysql' ? 'MySQL' : 'Turso/SQLite'}`);

    const result = await db.get(
      db.type === 'mysql'
        ? "SELECT COUNT(*) as count FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = DATABASE()"
        : "SELECT COUNT(*) as count FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'"
    );

    console.log(`Total tables: ${result.count}`);

    await db.close();
    process.exit(0);
  } catch (error) {
    console.error('Database initialization failed:', error.message);
    process.exit(1);
  }
}

initDb();
