"use strict";

const express = require("express");
const { findById, findByUsername, updatePlayerFields, canonicalUsername, listAllPlayers } = require("../db");
const { requireAdminToken } = require("../middleware/adminAuth");

const router = express.Router();

router.use(requireAdminToken);

// Same format the app itself enforces at registration (routes/players.js) -
// kept in sync deliberately since a renamed player still has to be usable
// as a normal username everywhere else.
const USERNAME_PATTERN = /^[A-Za-z0-9_]{3,20}$/;

// Player-progression bounds, enforced here (not just on the iOS client -
// the whole point of a server-authoritative value is that the server
// itself never stores or serves something nonsensical, regardless of what
// the admin app happens to send). Keep these in sync with
// PlayerProgressionService's clamping on the iOS side - same numbers, same
// reasoning, see that file's comments.
const MIN_LEVEL = 1;
const MAX_LEVEL = 100;
const MIN_WIN_CHANCE_MULTIPLIER = 0.1;
const MAX_WIN_CHANCE_MULTIPLIER = 2.0;

function serializePlayer(player) {
  return {
    id: player.id,
    username: player.display_name,
    coinBalance: player.coin_balance,
    adminRevision: player.admin_revision,
    level: player.level,
    winChanceMultiplier: player.win_chance_multiplier,
    createdAt: player.created_at,
    updatedAt: player.updated_at,
  };
}

function isValidBalance(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && Number.isSafeInteger(value);
}

function isValidUsername(value) {
  return typeof value === "string" && USERNAME_PATTERN.test(value);
}

function isValidLevel(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= MIN_LEVEL && value <= MAX_LEVEL;
}

function isValidWinChanceMultiplier(value) {
  return (
    typeof value === "number" &&
    Number.isFinite(value) &&
    value >= MIN_WIN_CHANCE_MULTIPLIER &&
    value <= MAX_WIN_CHANCE_MULTIPLIER
  );
}

/** GET /api/admin/players - list every registered player. Each entry
 * carries its stable `id` - use that (not `username`) to address a
 * specific player in the endpoint below, since username is just a mutable
 * label. Also carries `level`/`winChanceMultiplier`. */
router.get("/players", (_req, res) => {
  res.json(listAllPlayers().map(serializePlayer));
});

/** GET /api/admin/players/:id - look up one player by their stable id. */
router.get("/players/:id", (req, res) => {
  const player = findById(req.params.id);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }
  res.json(serializePlayer(player));
});

/**
 * PATCH /api/admin/players/:id
 * body: any non-empty subset of { username, balance, level, winChanceMultiplier }
 *
 * The one endpoint your admin tool needs for every direct override: send
 * only the field(s) you're actually changing, addressed by the player's
 * stable id (never by username, which is just a mutable label - so a
 * rename in the same request never races the rest of the update).
 * Everything is validated up front; if any provided field fails
 * validation, nothing is written at all. Setting `balance` always
 * increments `admin_revision`, which is what makes the app treat that
 * change as authoritative over anything that happened offline on the
 * player's device; `username`/`level`/`winChanceMultiplier` don't touch
 * admin_revision at all - the app only ever reads them, so it just picks
 * up the new value on its next sync, no conflict to resolve.
 */
router.patch("/players/:id", (req, res) => {
  const player = findById(req.params.id);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }

  const { username, balance, level, winChanceMultiplier } = req.body ?? {};
  if (username === undefined && balance === undefined && level === undefined && winChanceMultiplier === undefined) {
    return res.status(400).json({ error: "no_fields_to_update" });
  }

  if (username !== undefined) {
    if (!isValidUsername(username)) {
      return res.status(400).json({ error: "invalid_username" });
    }
    const newCanonical = canonicalUsername(username);
    if (newCanonical !== player.username) {
      const existing = findByUsername(username);
      if (existing && existing.id !== player.id) {
        return res.status(409).json({ error: "username_taken" });
      }
    }
  }
  if (balance !== undefined && !isValidBalance(balance)) {
    return res.status(400).json({ error: "invalid_balance" });
  }
  if (level !== undefined && !isValidLevel(level)) {
    return res.status(400).json({ error: "invalid_level", allowedRange: [MIN_LEVEL, MAX_LEVEL] });
  }
  if (winChanceMultiplier !== undefined && !isValidWinChanceMultiplier(winChanceMultiplier)) {
    return res.status(400).json({
      error: "invalid_win_chance_multiplier",
      allowedRange: [MIN_WIN_CHANCE_MULTIPLIER, MAX_WIN_CHANCE_MULTIPLIER],
    });
  }

  const updated = updatePlayerFields(player.id, { username, coinBalance: balance, level, winChanceMultiplier });
  res.json(serializePlayer(updated));
});

module.exports = router;
