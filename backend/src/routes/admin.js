"use strict";

const express = require("express");
const { findByUsername, setBalanceFromAdmin, listAllPlayers } = require("../db");
const { requireAdminToken } = require("../middleware/adminAuth");

const router = express.Router();

router.use(requireAdminToken);

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

module.exports = router;
