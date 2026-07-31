const mysql = require('mysql2/promise');
const BetterSqlite = require('better-sqlite3');

class Database {
  constructor() {
    this.type = process.env.DB_TYPE || 'turso';
    this.initialized = false;
    this.pool = null;
    this.db = null;
  }

  async init() {
    if (this.initialized) return this;

    if (this.type === 'mysql') {
      this.pool = mysql.createPool({
        host: process.env.DB_HOST || 'localhost',
        port: parseInt(process.env.DB_PORT) || 3306,
        user: process.env.DB_USER || 'root',
        password: process.env.DB_PASSWORD || '',
        database: process.env.DB_NAME || 'dating_app',
        waitForConnections: true,
        connectionLimit: 10,
        queueLimit: 0,
      });

      try {
        await this.pool.getConnection();
      } catch (err) {
        console.error('MySQL connection failed:', err.message);
      }
    } else {
      const isRemote = process.env.TURSO_URL &&
          (process.env.TURSO_URL.startsWith('https://') || process.env.TURSO_URL.startsWith('libsql://'));

      if (isRemote) {
        const { createClient } = require('@libsql/client');
        this.db = createClient({
          url: process.env.TURSO_URL,
          authToken: process.env.TURSO_AUTH_TOKEN || undefined,
        });
        this._isLibsql = true;
      } else {
        const dbPath = process.env.TURSO_URL?.replace('file:', '') || 'dev.db';
        this.db = new BetterSqlite(dbPath);
        this._isLibsql = false;
        this.db.pragma('journal_mode = WAL');
        this.db.pragma('foreign_keys = ON');
      }
    }

    this.initialized = true;
    return this;
  }

  async query(sql, params = []) {
    await this.init();

    if (this.type === 'mysql') {
      const [rows] = await this.pool.execute(sql, params);
      return rows;
    } else if (this._isLibsql) {
      const result = await this.db.execute({ sql, args: params });
      return result.rows;
    } else {
      const stmt = this.db.prepare(sql);
      const converted = params.map(p => p === true ? 1 : p === false ? 0 : p);
      return converted.length > 0 ? stmt.all(...converted) : stmt.all();
    }
  }

  async run(sql, params = []) {
    await this.init();

    if (this.type === 'mysql') {
      const [result] = await this.pool.execute(sql, params);
      return {
        insertId: result.insertId,
        affectedRows: result.affectedRows,
      };
    } else if (this._isLibsql) {
      const result = await this.db.execute({ sql, args: params });
      return {
        insertId: result.lastInsertRowid !== undefined ? Number(result.lastInsertRowid) : null,
        affectedRows: result.rowsAffected,
      };
    } else {
      const stmt = this.db.prepare(sql);
      const converted = params.map(p => p === true ? 1 : p === false ? 0 : p);
      const info = converted.length > 0 ? stmt.run(...converted) : stmt.run();
      return {
        insertId: Number(info.lastInsertRowid),
        affectedRows: info.changes,
      };
    }
  }

  async get(sql, params = []) {
    await this.init();

    if (this.type === 'mysql') {
      const [rows] = await this.pool.execute(sql, params);
      return rows[0] || null;
    } else if (this._isLibsql) {
      const result = await this.db.execute({ sql, args: params });
      return result.rows[0] || null;
    } else {
      const stmt = this.db.prepare(sql);
      const converted = params.map(p => p === true ? 1 : p === false ? 0 : p);
      return converted.length > 0 ? stmt.get(...converted) : stmt.get();
    }
  }

  async exec(sql) {
    await this.init();

    if (this.type === 'mysql') {
      await this.pool.execute(sql);
    } else if (this._isLibsql) {
      await this.db.execute(sql);
    } else {
      this.db.exec(sql);
    }
  }

  async batch(statements) {
    await this.init();

    if (this.type === 'mysql') {
      const results = [];
      for (const stmt of statements) {
        const [result] = await this.pool.execute(stmt.sql, stmt.args || []);
        results.push({
          insertId: result.insertId,
          affectedRows: result.affectedRows,
        });
      }
      return results;
    } else if (this._isLibsql) {
      const batchStmts = statements.map(s => ({
        sql: s.sql,
        args: s.args || [],
      }));
      const results = await this.db.batch(batchStmts);
      return results.map(r => ({
        insertId: r.lastInsertRowid !== undefined ? Number(r.lastInsertRowid) : null,
        affectedRows: r.rowsAffected,
      }));
    } else {
      const transaction = this.db.transaction((stmts) => {
        const results = [];
        for (const stmt of stmts) {
          const s = this.db.prepare(stmt.sql);
          const args = (stmt.args || []).map(p => p === true ? 1 : p === false ? 0 : p);
          const info = args.length > 0 ? s.run(...args) : s.run();
          results.push({
            insertId: Number(info.lastInsertRowid),
            affectedRows: info.changes,
          });
        }
        return results;
      });
      return transaction(statements);
    }
  }

  async close() {
    if (this.pool) {
      await this.pool.end();
    }
    if (this.db) {
      if (this._isLibsql) {
        await this.db.close();
      } else {
        this.db.close();
      }
    }
  }
}

module.exports = new Database();
