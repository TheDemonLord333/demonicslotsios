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

// --- Migration 1: `id` becomes the real, immutable primary key -----------
//
// The original schema used the (lowercased) `username` itself as the
// primary key, which meant renaming a player meant literally changing their
// row's identity. That's exactly backwards for an admin "rename this
// player" feature: identity should be stable, `username` should just be a
// mutable label on it. If an existing `players` table predates `id`,
// migrate it in place before the CREATE TABLE below (which only handles the
// fresh-install case via IF NOT EXISTS). The old table is kept around as
// `players_pre_id_migration` rather than dropped, as a safety net.
//
// The freshly created table already carries `level`/`win_chance_multiplier`
// (see migration 2 below) so a database that predates *both* features jumps
// straight to the final shape in one hop instead of two.
if (tableExists("players") && !columnExists("players", "id")) {
  const legacyRows = db.prepare("SELECT * FROM players").all();

  db.exec("ALTER TABLE players RENAME TO players_pre_id_migration");
  db.exec(`
    CREATE TABLE players (
      id                     TEXT PRIMARY KEY,                 -- stable identifier, assigned once, never changes
      username               TEXT NOT NULL UNIQUE,             -- lowercased, canonical uniqueness key - just a mutable label now
      display_name           TEXT NOT NULL,                    -- original casing as the player typed it
      device_token           TEXT NOT NULL UNIQUE,              -- secret issued at registration; authenticates sync calls
      coin_balance           INTEGER NOT NULL,                  -- Soul Coins (fits in SQLite's 64-bit INTEGER, matches Int64 in the app)
      admin_revision         INTEGER NOT NULL DEFAULT 0,         -- bumped ONLY by an admin edit to coin_balance; drives conflict resolution
      level                  INTEGER NOT NULL DEFAULT 1,         -- server-authoritative player progression, 1-100
      win_chance_multiplier  REAL NOT NULL DEFAULT 1.0,          -- server-authoritative, 0.10-2.00, 1.0 = no bonus/penalty
      created_at             TEXT NOT NULL,
      updated_at             TEXT NOT NULL
    );
  `);

  const insertMigratedRow = db.prepare(`
    INSERT INTO players (id, username, display_name, device_token, coin_balance, admin_revision, level, win_chance_multiplier, created_at, updated_at)
    VALUES (@id, @username, @display_name, @device_token, @coin_balance, @admin_revision, @level, @win_chance_multiplier, @created_at, @updated_at)
  `);
  const migrateAll = db.transaction((rows) => {
    for (const row of rows) {
      insertMigratedRow.run({
        ...row,
        id: crypto.randomUUID(),
        // A legacy pre-id row also predates level/win_chance_multiplier
        // (they were added after this migration originally shipped) - give
        // it the same neutral defaults a brand-new player gets.
        level: row.level ?? 1,
        win_chance_multiplier: row.win_chance_multiplier ?? 1.0,
      });
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
    id                     TEXT PRIMARY KEY,
    username               TEXT NOT NULL UNIQUE,
    display_name           TEXT NOT NULL,
    device_token           TEXT NOT NULL UNIQUE,
    coin_balance           INTEGER NOT NULL,
    admin_revision         INTEGER NOT NULL DEFAULT 0,
    level                  INTEGER NOT NULL DEFAULT 1,
    win_chance_multiplier  REAL NOT NULL DEFAULT 1.0,
    created_at             TEXT NOT NULL,
    updated_at             TEXT NOT NULL
  );
`);

// --- Migration 2: add level/win_chance_multiplier to a database that -----
// already has `id` (i.e. already went through migration 1 in an earlier
// deploy) but predates these two columns. `ALTER TABLE ... ADD COLUMN ...
// DEFAULT x` applies to every existing row immediately - existing
// id/username/display_name/device_token/coin_balance/admin_revision/
// timestamps are never touched.
if (!columnExists("players", "level")) {
  db.exec("ALTER TABLE players ADD COLUMN level INTEGER NOT NULL DEFAULT 1");
}
if (!columnExists("players", "win_chance_multiplier")) {
  db.exec("ALTER TABLE players ADD COLUMN win_chance_multiplier REAL NOT NULL DEFAULT 1.0");
}

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
  // level/win_chance_multiplier are deliberately not passed here - every
  // new player gets the column DEFAULTs (1 / 1.0), the same "no bonus yet"
  // starting point for everyone.
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

/**
 * The one write path for everything an admin is allowed to change
 * directly: username, coin balance, level, and/or win_chance_multiplier -
 * any non-empty subset, addressed by the player's stable `id` (never by
 * username, which is just a mutable label). `admin_revision` only bumps
 * when `coinBalance` is part of the update: it exists purely to tell a
 * syncing device "your pending local balance is stale, an admin changed it
 * directly" - a username/level/multiplier edit doesn't touch the balance at
 * all, so it must never trigger that conflict-resolution path (the client
 * picks up a changed username/level/multiplier on its very next `/sync`
 * regardless, no revision bump needed for those).
 */
function updatePlayerFields(id, { username, coinBalance, level, winChanceMultiplier } = {}) {
  if (username === undefined && coinBalance === undefined && level === undefined && winChanceMultiplier === undefined) {
    return findById(id);
  }

  const assignments = ["updated_at = @now"];
  const params = { id, now: new Date().toISOString() };

  if (username !== undefined) {
    assignments.push("username = @username", "display_name = @displayName");
    params.username = canonicalUsername(username);
    params.displayName = username;
  }
  if (coinBalance !== undefined) {
    assignments.push("coin_balance = @coinBalance", "admin_revision = admin_revision + 1");
    params.coinBalance = coinBalance;
  }
  if (level !== undefined) {
    assignments.push("level = @level");
    params.level = level;
  }
  if (winChanceMultiplier !== undefined) {
    assignments.push("win_chance_multiplier = @winChanceMultiplier");
    params.winChanceMultiplier = winChanceMultiplier;
  }

  db.prepare(`UPDATE players SET ${assignments.join(", ")} WHERE id = @id`).run(params);
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
  updatePlayerFields,
  listAllPlayers,
};
