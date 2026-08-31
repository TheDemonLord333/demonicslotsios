"use strict";

const path = require("node:path");
const fs = require("node:fs");
const crypto = require("node:crypto");
const Database = require("better-sqlite3");

const DB_PATH = process.env.DB_PATH || "./data/demonicslots.sqlite";

// Make sure the directory for the database file exists before opening it.
const resolvedPath = path.resolve(DB_PATH);
fs.mkdirSync(path.dirname(resolvedPath), { recursive: true });

const db = new Database(resolvedPath);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

function columnExists(table, column) {
  return db.prepare(`PRAGMA table_info(${table})`).all().some((c) => c.name === column);
}

function tableExists(table) {
  return !!db.prepare("SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?").get(table);
}

// --- One-time migration: `id` becomes the real, immutable primary key -----
//
// The original schema used the (lowercased) `username` itself as the
// primary key, which meant renaming a player meant literally changing their
// row's identity. That's exactly backwards for an admin "rename this
// player" feature: identity should be stable, `username` should just be a
// mutable label on it. If an existing `players` table predates `id`,
// migrate it in place before the CREATE TABLE below (which only handles the
// fresh-install case via IF NOT EXISTS). The old table is kept around as
// `players_pre_id_migration` rather than dropped, as a safety net.
if (tableExists("players") && !columnExists("players", "id")) {
  const legacyRows = db.prepare("SELECT * FROM players").all();

  db.exec("ALTER TABLE players RENAME TO players_pre_id_migration");
  db.exec(`
    CREATE TABLE players (
      id              TEXT PRIMARY KEY,                 -- stable identifier, assigned once, never changes
      username        TEXT NOT NULL UNIQUE,             -- lowercased, canonical uniqueness key - just a mutable label now
      display_name    TEXT NOT NULL,                    -- original casing as the player typed it
      device_token    TEXT NOT NULL UNIQUE,              -- secret issued at registration; authenticates sync calls
      coin_balance    INTEGER NOT NULL,                  -- Soul Coins (fits in SQLite's 64-bit INTEGER, matches Int64 in the app)
      admin_revision  INTEGER NOT NULL DEFAULT 0,         -- bumped ONLY by an admin edit; drives conflict resolution
      created_at      TEXT NOT NULL,
      updated_at      TEXT NOT NULL
    );
  `);

  const insertMigratedRow = db.prepare(`
    INSERT INTO players (id, username, display_name, device_token, coin_balance, admin_revision, created_at, updated_at)
    VALUES (@id, @username, @display_name, @device_token, @coin_balance, @admin_revision, @created_at, @updated_at)
  `);
  const migrateAll = db.transaction((rows) => {
    for (const row of rows) {
      insertMigratedRow.run({ ...row, id: crypto.randomUUID() });
    }
  });
  migrateAll(legacyRows);

  console.log(
    `[db migration] players table moved to id-based schema (${legacyRows.length} row(s) migrated); ` +
      "previous table kept as players_pre_id_migration."
  );
}

db.exec(`
  CREATE TABLE IF NOT EXISTS players (
    id              TEXT PRIMARY KEY,
    username        TEXT NOT NULL UNIQUE,
    display_name    TEXT NOT NULL,
    device_token    TEXT NOT NULL UNIQUE,
    coin_balance    INTEGER NOT NULL,
    admin_revision  INTEGER NOT NULL DEFAULT 0,
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
  );
`);

/** Canonical uniqueness key: usernames only collide case-insensitively. */
function canonicalUsername(rawUsername) {
  return rawUsername.trim().toLowerCase();
}

const statements = {
  getById: db.prepare("SELECT * FROM players WHERE id = ?"),
  getByUsername: db.prepare("SELECT * FROM players WHERE username = ?"),
  getByDeviceToken: db.prepare("SELECT * FROM players WHERE device_token = ?"),
  insertPlayer: db.prepare(`
    INSERT INTO players (id, username, display_name, device_token, coin_balance, admin_revision, created_at, updated_at)
    VALUES (@id, @username, @displayName, @deviceToken, @coinBalance, 0, @now, @now)
  `),
  setBalanceFromClient: db.prepare(`
    UPDATE players SET coin_balance = @coinBalance, updated_at = @now WHERE id = @id
  `),
  setBalanceFromAdmin: db.prepare(`
    UPDATE players
    SET coin_balance = @coinBalance, admin_revision = admin_revision + 1, updated_at = @now
    WHERE id = @id
  `),
  renameByAdmin: db.prepare(`
    UPDATE players
    SET username = @newUsername, display_name = @newDisplayName, updated_at = @now
    WHERE id = @id
  `),
  listAll: db.prepare("SELECT * FROM players ORDER BY updated_at DESC"),
};

function findById(id) {
  return statements.getById.get(id);
}

function findByUsername(rawUsername) {
  return statements.getByUsername.get(canonicalUsername(rawUsername));
}

function findByDeviceToken(deviceToken) {
  return statements.getByDeviceToken.get(deviceToken);
}

function createPlayer({ username, displayName, deviceToken, coinBalance }) {
  const id = crypto.randomUUID();
  const now = new Date().toISOString();
  statements.insertPlayer.run({
    id,
    username: canonicalUsername(username),
    displayName,
    deviceToken,
    coinBalance,
    now,
  });
  return findById(id);
}

function setBalanceFromClient(id, coinBalance) {
  const now = new Date().toISOString();
  statements.setBalanceFromClient.run({ id, coinBalance, now });
  return findById(id);
}

function setBalanceFromAdmin(id, coinBalance) {
  const now = new Date().toISOString();
  statements.setBalanceFromAdmin.run({ id, coinBalance, now });
  return findById(id);
}

/**
 * Renames a player, addressed by their stable `id` - the whole point of
 * that column is that a rename never has to touch (or even look up by) the
 * thing that's actually changing. Updates both the canonical (lowercased)
 * lookup key and the display name. Deliberately does NOT touch
 * coin_balance or admin_revision - those are a separate concern (see
 * setBalanceFromAdmin). device_token is also untouched, so the same device
 * stays linked to the account.
 */
function renamePlayerByAdmin(id, rawNewUsername) {
  const now = new Date().toISOString();
  statements.renameByAdmin.run({
    id,
    newUsername: canonicalUsername(rawNewUsername),
    newDisplayName: rawNewUsername,
    now,
  });
  return findById(id);
}

function listAllPlayers() {
  return statements.listAll.all();
}

module.exports = {
  db,
  canonicalUsername,
  findById,
  findByUsername,
  findByDeviceToken,
  createPlayer,
  setBalanceFromClient,
  setBalanceFromAdmin,
  renamePlayerByAdmin,
  listAllPlayers,
};
