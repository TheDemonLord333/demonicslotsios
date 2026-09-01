"use strict";

const path = require("node:path");
const fs = require("node:fs");
const Database = require("better-sqlite3");

const DB_PATH = process.env.DB_PATH || "./data/demonicslots.sqlite";

// Make sure the directory for the database file exists before opening it.
const resolvedPath = path.resolve(DB_PATH);
fs.mkdirSync(path.dirname(resolvedPath), { recursive: true });

const db = new Database(resolvedPath);
db.pragma("journal_mode = WAL");
db.pragma("foreign_keys = ON");

db.exec(`
  CREATE TABLE IF NOT EXISTS players (
    username        TEXT PRIMARY KEY,               -- lowercased, canonical uniqueness key
    display_name    TEXT NOT NULL,                   -- original casing as the player typed it
    device_token    TEXT NOT NULL UNIQUE,             -- secret issued at registration; authenticates sync calls
    coin_balance    INTEGER NOT NULL,                 -- Soul Coins (fits in SQLite's 64-bit INTEGER, matches Int64 in the app)
    admin_revision  INTEGER NOT NULL DEFAULT 0,        -- bumped ONLY by an admin edit to coin_balance; drives conflict resolution
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
  );
`);

// Migration: add the player-progression columns to a database created
// before they existed, without touching any existing row's username,
// display_name, device_token, coin_balance, admin_revision or timestamps.
// `CREATE TABLE IF NOT EXISTS` above only handles a brand-new database - an
// existing `players` table needs its own `ALTER TABLE` here, run once and
// guarded by `PRAGMA table_info` so it's a no-op on every later startup.
// SQLite applies an `ALTER TABLE ... ADD COLUMN ... DEFAULT x` to every
// existing row immediately, so this is exactly the "existing users get
// level = 1 / win_chance_multiplier = 1.0, nothing else changes" migration.
const existingColumns = new Set(db.prepare("PRAGMA table_info(players)").all().map((col) => col.name));
if (!existingColumns.has("level")) {
  db.exec("ALTER TABLE players ADD COLUMN level INTEGER NOT NULL DEFAULT 1");
}
if (!existingColumns.has("win_chance_multiplier")) {
  db.exec("ALTER TABLE players ADD COLUMN win_chance_multiplier REAL NOT NULL DEFAULT 1.0");
}

/** Canonical uniqueness key: usernames only collide case-insensitively. */
function canonicalUsername(rawUsername) {
  return rawUsername.trim().toLowerCase();
}

const statements = {
  getByUsername: db.prepare("SELECT * FROM players WHERE username = ?"),
  getByDeviceToken: db.prepare("SELECT * FROM players WHERE device_token = ?"),
  insertPlayer: db.prepare(`
    INSERT INTO players (username, display_name, device_token, coin_balance, admin_revision, created_at, updated_at)
    VALUES (@username, @displayName, @deviceToken, @coinBalance, 0, @now, @now)
  `),
  setBalanceFromClient: db.prepare(`
    UPDATE players SET coin_balance = @coinBalance, updated_at = @now WHERE username = @username
  `),
  listAll: db.prepare("SELECT * FROM players ORDER BY updated_at DESC"),
};

function findByUsername(rawUsername) {
  return statements.getByUsername.get(canonicalUsername(rawUsername));
}

function findByDeviceToken(deviceToken) {
  return statements.getByDeviceToken.get(deviceToken);
}

function createPlayer({ username, displayName, deviceToken, coinBalance }) {
  const now = new Date().toISOString();
  statements.insertPlayer.run({
    username: canonicalUsername(username),
    displayName,
    deviceToken,
    coinBalance,
    now,
  });
  return findByUsername(username);
}

function setBalanceFromClient(rawUsername, coinBalance) {
  const now = new Date().toISOString();
  statements.setBalanceFromClient.run({ username: canonicalUsername(rawUsername), coinBalance, now });
  return findByUsername(rawUsername);
}

/**
 * The one write path for everything an admin (eventually the separate admin
 * app) is allowed to change directly: coin balance, level, and/or
 * win_chance_multiplier - any subset, since a PATCH only sends the fields
 * being changed. `admin_revision` only bumps when `coinBalance` is part of
 * the update: it exists purely to tell a syncing device "your pending local
 * balance is stale, an admin changed it directly" - a level or multiplier
 * edit doesn't touch the balance at all, so it must never trigger that
 * conflict-resolution path (the client picks up a changed level/multiplier
 * on its very next `/sync` regardless, no revision needed for those).
 */
function updatePlayerFields(rawUsername, { coinBalance, level, winChanceMultiplier } = {}) {
  if (coinBalance === undefined && level === undefined && winChanceMultiplier === undefined) {
    return findByUsername(rawUsername);
  }

  const assignments = ["updated_at = @now"];
  const params = { username: canonicalUsername(rawUsername), now: new Date().toISOString() };

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

  db.prepare(`UPDATE players SET ${assignments.join(", ")} WHERE username = @username`).run(params);
  return findByUsername(rawUsername);
}

function listAllPlayers() {
  return statements.listAll.all();
}

module.exports = {
  db,
  canonicalUsername,
  findByUsername,
  findByDeviceToken,
  createPlayer,
  setBalanceFromClient,
  updatePlayerFields,
  listAllPlayers,
};
