"use strict";

const express = require("express");
const { findByUsername, setBalanceFromAdmin, renamePlayerByAdmin, canonicalUsername, listAllPlayers } = require("../db");
const { requireAdminToken } = require("../middleware/adminAuth");

const router = express.Router();

router.use(requireAdminToken);

// Same format the app itself enforces at registration (routes/players.js) -
// kept in sync deliberately since a renamed player still has to be usable
// as a normal username everywhere else.
const USERNAME_PATTERN = /^[A-Za-z0-9_]{3,20}$/;

function serializePlayer(player) {
  return {
    username: player.display_name,
    coinBalance: player.coin_balance,
    adminRevision: player.admin_revision,
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
 * PATCH /api/admin/players/:username/balance
 * body: { balance }
 *
 * This is the endpoint your admin tool calls to override a player's Soul
 * Coin balance. It always increments admin_revision, which is what makes
 * the app treat this change as authoritative over anything that happened
 * offline on the player's device.
 */
router.patch("/players/:username/balance", (req, res) => {
  const player = findByUsername(req.params.username);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }

  const { balance } = req.body ?? {};
  if (!isValidBalance(balance)) {
    return res.status(400).json({ error: "invalid_balance" });
  }

  const updated = setBalanceFromAdmin(req.params.username, balance);
  res.json(serializePlayer(updated));
});

/**
 * PATCH /api/admin/players/:username/username
 * body: { username }
 *
 * Renames a player - changes their canonical lookup key and display name,
 * leaves coin_balance/admin_revision untouched. The device_token is also
 * untouched, so the player's app keeps working: /api/players/sync falls
 * back to a device-token lookup whenever the username it was last told
 * about no longer resolves (see routes/players.js), so a renamed player's
 * app keeps syncing balances without interruption. Its locally *displayed*
 * username only catches up the next time that build reads the username
 * back out of a sync response.
 */
router.patch("/players/:username/username", (req, res) => {
  const player = findByUsername(req.params.username);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }

  const { username: newUsername } = req.body ?? {};
  if (!isValidUsername(newUsername)) {
    return res.status(400).json({ error: "invalid_username" });
  }

  const newCanonical = canonicalUsername(newUsername);
  if (newCanonical !== player.username) {
    const existing = findByUsername(newUsername);
    if (existing) {
      return res.status(409).json({ error: "username_taken" });
    }
  }

  const updated = renamePlayerByAdmin(req.params.username, newUsername);
  res.json(serializePlayer(updated));
});

module.exports = router;
