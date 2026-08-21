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
    admin_revision  INTEGER NOT NULL DEFAULT 0,        -- bumped ONLY by an admin edit; drives conflict resolution
    created_at      TEXT NOT NULL,
    updated_at      TEXT NOT NULL
  );
`);

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
  setBalanceFromAdmin: db.prepare(`
    UPDATE players
    SET coin_balance = @coinBalance, admin_revision = admin_revision + 1, updated_at = @now
    WHERE username = @username
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

function setBalanceFromAdmin(rawUsername, coinBalance) {
  const now = new Date().toISOString();
  statements.setBalanceFromAdmin.run({ username: canonicalUsername(rawUsername), coinBalance, now });
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
  setBalanceFromAdmin,
  listAllPlayers,
};
