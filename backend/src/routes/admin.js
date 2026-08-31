"use strict";

const express = require("express");
const { findById, findByUsername, setBalanceFromAdmin, renamePlayerByAdmin, canonicalUsername, listAllPlayers } = require("../db");
const { requireAdminToken } = require("../middleware/adminAuth");

const router = express.Router();

router.use(requireAdminToken);

// Same format the app itself enforces at registration (routes/players.js) -
// kept in sync deliberately since a renamed player still has to be usable
// as a normal username everywhere else.
const USERNAME_PATTERN = /^[A-Za-z0-9_]{3,20}$/;

function serializePlayer(player) {
  return {
    id: player.id,
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

/** GET /api/admin/players - list every registered player. Each entry now
 * carries its stable `id` - use that (not `username`) to address a specific
 * player in the endpoints below, since username is just a mutable label. */
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
 * PATCH /api/admin/players/:id/balance
 * body: { balance }
 *
 * This is the endpoint your admin tool calls to override a player's Soul
 * Coin balance. It always increments admin_revision, which is what makes
 * the app treat this change as authoritative over anything that happened
 * offline on the player's device.
 */
router.patch("/players/:id/balance", (req, res) => {
  const player = findById(req.params.id);
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }

  const { balance } = req.body ?? {};
  if (!isValidBalance(balance)) {
    return res.status(400).json({ error: "invalid_balance" });
  }

  const updated = setBalanceFromAdmin(player.id, balance);
  res.json(serializePlayer(updated));
});

/**
 * PATCH /api/admin/players/:id/username
 * body: { username }
 *
 * Renames a player, addressed by their stable id - not by their current
 * username, which is exactly the point: the id never changes, so a rename
 * can't race or collide with itself the way keying off the mutable
 * username could. Leaves coin_balance/admin_revision/device_token
 * untouched - a rename is a separate concern from a balance override, and
 * the player's device stays linked to the same account either way.
 */
router.patch("/players/:id/username", (req, res) => {
  const player = findById(req.params.id);
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
    if (existing && existing.id !== player.id) {
      return res.status(409).json({ error: "username_taken" });
    }
  }

  const updated = renamePlayerByAdmin(player.id, newUsername);
  res.json(serializePlayer(updated));
});

module.exports = router;
