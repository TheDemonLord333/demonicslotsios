"use strict";

const express = require("express");
const crypto = require("node:crypto");
const {
  findByUsername,
  findByDeviceToken,
  createPlayer,
  setBalanceFromClient,
  updatePlayerFields,
} = require("../db");

const router = express.Router();

const USERNAME_PATTERN = /^[A-Za-z0-9_]{3,20}$/;

// Same bounds as routes/admin.js's isValidLevel - kept in sync deliberately,
// see that file's comment on why the server enforces this itself rather
// than trusting whatever a client (admin app or the game) sends.
const MIN_LEVEL = 1;
const MAX_LEVEL = 100;

function isValidUsername(value) {
  return typeof value === "string" && USERNAME_PATTERN.test(value);
}

function isValidLevel(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= MIN_LEVEL && value <= MAX_LEVEL;
}

/** Must be a non-negative integer that fits safely in a JS number (the app
 * sends Int64 balances, but realistic Soul Coin balances never get close to
 * Number.MAX_SAFE_INTEGER, so this is a safe, simple bound check). */
function isValidBalance(value) {
  return typeof value === "number" && Number.isInteger(value) && value >= 0 && Number.isSafeInteger(value);
}

function serializePlayer(player) {
  return {
    username: player.display_name,
    coinBalance: player.coin_balance,
    adminRevision: player.admin_revision,
    // Server-authoritative player progression/admin overrides: the app
    // only ever reads these (register/sync), it never writes them - only
    // the admin API (see routes/admin.js) can change them. Always sent so
    // a syncing device stays current even when nothing about the coin
    // balance changed (no admin_revision bump needed for a level/
    // multiplier/guaranteedJackpot edit).
    level: player.level,
    winChanceMultiplier: player.win_chance_multiplier,
    guaranteedJackpot: !!player.guaranteed_jackpot,
    updatedAt: player.updated_at,
  };
}

/**
 * POST /api/players/register
 * body: { username, initialBalance }
 *
 * Claims a username (case-insensitively unique) and issues a secret device
 * token the client must present on every future /sync call. There is no
 * password - the token, stored locally by the app, is what proves "this
 * device owns this username" on subsequent requests.
 */
router.post("/register", (req, res) => {
  const { username, initialBalance } = req.body ?? {};

  if (!isValidUsername(username)) {
    return res.status(400).json({
      error: "invalid_username",
      message: "Username must be 3-20 characters: letters, digits or underscore.",
    });
  }
  if (!isValidBalance(initialBalance)) {
    return res.status(400).json({ error: "invalid_balance" });
  }

  if (findByUsername(username)) {
    return res.status(409).json({ error: "username_taken" });
  }

  const deviceToken = crypto.randomBytes(32).toString("hex");
  const player = createPlayer({
    username,
    displayName: username,
    deviceToken,
    coinBalance: initialBalance,
  });

  return res.status(201).json({
    ...serializePlayer(player),
    deviceToken,
  });
});

/**
 * POST /api/players/sync
 * body: { username, deviceToken, localBalance, lastKnownAdminRevision, earnedLevel? }
 *
 * The full bidirectional conflict-resolution round trip in one call:
 *
 *  - If the server's admin_revision has moved since this device last saw
 *    it, an admin changed the balance directly - that always wins,
 *    regardless of what happened locally in the meantime. The server
 *    balance is returned and the client is expected to overwrite its
 *    local value with it.
 *  - Otherwise nothing admin-side has changed, so the client's local
 *    balance (which reflects actual gameplay) is written to the server.
 *
 * `earnedLevel` (optional) is the app's own claim, from
 * PlayerProgressionService.level(forTotalXP:), that local play has earned
 * a higher level than the server currently has on file. Applied to *both*
 * branches above (it isn't part of the balance conflict at all - see
 * applyEarnedLevel below) and only ever raises the stored level, never
 * lowers it, so an admin-set level above the player's own XP pace is never
 * walked back just by playing.
 */
router.post("/sync", (req, res) => {
  const { username, deviceToken, localBalance, lastKnownAdminRevision, earnedLevel } = req.body ?? {};

  if (!isValidUsername(username) || typeof deviceToken !== "string" || !deviceToken) {
    return res.status(400).json({ error: "invalid_request" });
  }
  if (!isValidBalance(localBalance) || !Number.isInteger(lastKnownAdminRevision) || lastKnownAdminRevision < 0) {
    return res.status(400).json({ error: "invalid_request" });
  }

  let player = findByUsername(username);
  if (!player) {
    // The username this device last knew about doesn't resolve anymore -
    // most likely an admin renamed this player since the last sync (see
    // routes/admin.js's PATCH .../:id, which never changes device_token
    // even when the request includes a new username). Fall back to
    // looking the player up by their device token so a rename doesn't lock
    // the app out of syncing; the response below already reports the
    // player's current (new) username.
    player = findByDeviceToken(deviceToken);
  }
  if (!player) {
    return res.status(404).json({ error: "not_found" });
  }
  if (player.device_token !== deviceToken) {
    return res.status(403).json({ error: "invalid_device_token" });
  }

  if (player.admin_revision !== lastKnownAdminRevision) {
    // An admin edit happened since this device last synced - it wins,
    // unconditionally. Don't touch the stored balance at all.
    return res.status(200).json({
      resolution: "server_wins",
      ...serializePlayer(applyEarnedLevel(player, earnedLevel)),
    });
  }

  // Write keyed by the player's immutable id, never by username - matters
  // exactly when the fallback above kicked in after a rename, where the
  // username the device sent no longer names this row at all.
  const updated = setBalanceFromClient(player.id, localBalance);
  return res.status(200).json({
    resolution: "client_applied",
    ...serializePlayer(applyEarnedLevel(updated, earnedLevel)),
  });
});

/** Applies a client's XP-earned level claim, if it's valid and actually
 * higher than what's already stored - silently ignored otherwise (a
 * missing/malformed/lower claim is not an error, just a no-op: most sync
 * calls carry no claim at all). Never bumps admin_revision - a level-up
 * isn't a competing write against the coin balance, see the /sync doc
 * comment above. */
function applyEarnedLevel(player, earnedLevel) {
  if (!isValidLevel(earnedLevel) || earnedLevel <= player.level) {
    return player;
  }
  return updatePlayerFields(player.id, { level: earnedLevel });
}

module.exports = router;
