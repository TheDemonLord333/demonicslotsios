"use strict";

const express = require("express");
const { findByUsername, updatePlayerFields, listAllPlayers } = require("../db");
const { requireAdminToken } = require("../middleware/adminAuth");

const router = express.Router();

router.use(requireAdminToken);

// Player-progression bounds, enforced here (not just on the iOS client -
// the whole point of a server-authoritative value is that the server
// itself never stores or serves something nonsensical, regardless of what
// a future admin app happens to send). Keep these in sync with
// PlayerProgressionService's clamping on the iOS side - same numbers,
// same reasoning, see that file's comments.
const MIN_LEVEL = 1;
const MAX_LEVEL = 100;
const MIN_WIN_CHANCE_MULTIPLIER = 0.1;
const MAX_WIN_CHANCE_MULTIPLIER = 2.0;

function serializePlayer(player) {
  return {
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

/** GET /api/admin/players - list every registered player. */
router.get("/players", (_req, res) => {
  res.json(listAllPlayers().map(serializePlayer));
});

/** GET /api/admin/players/:username - look up one player. */
router.get("/players/:username", (req, res) => {
  const player = findByUsername(req.params.username);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }
  res.json(serializePlayer(player));
});

/**
 * PATCH /api/admin/players/:username
 * body: any non-empty subset of { balance, level, winChanceMultiplier }
 *
 * This is the endpoint your admin tool calls to override a player's Soul
 * Coin balance and/or their level/win-chance multiplier - send only the
 * field(s) you're actually changing. Setting `balance` always increments
 * admin_revision, which is what makes the app treat that change as
 * authoritative over anything that happened offline on the player's
 * device; `level`/`winChanceMultiplier` don't touch admin_revision at all
 * since they're never client-writable in the first place (the app only
 * ever reads them, so it just picks up the new value on its next sync).
 */
router.patch("/players/:username", (req, res) => {
  const player = findByUsername(req.params.username);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }

  const { balance, level, winChanceMultiplier } = req.body ?? {};
  if (balance === undefined && level === undefined && winChanceMultiplier === undefined) {
    return res.status(400).json({ error: "no_fields_to_update" });
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

  const updated = updatePlayerFields(req.params.username, { coinBalance: balance, level, winChanceMultiplier });
  res.json(serializePlayer(updated));
});

module.exports = router;
