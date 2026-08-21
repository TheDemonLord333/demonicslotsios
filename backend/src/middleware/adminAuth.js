"use strict";

/**
 * Requires `Authorization: Bearer <ADMIN_TOKEN>` on every /api/admin/* and
 * /admin/* request. This is the only thing standing between "anyone who
 * finds the URL" and "can rewrite any player's balance", so ADMIN_TOKEN
 * must be a long random secret set in .env - see .env.example.
 */
function requireAdminToken(req, res, next) {
  const configuredToken = process.env.ADMIN_TOKEN;
  if (!configuredToken || configuredToken === "change-me-to-a-long-random-secret") {
    return res.status(500).json({
      error: "server_misconfigured",
      message: "ADMIN_TOKEN is not set (or still the placeholder) in the server's .env file.",
    });
  }

  const header = req.get("authorization") || "";
  const [scheme, token] = header.split(" ");
  if (scheme !== "Bearer" || token !== configuredToken) {
    return res.status(401).json({ error: "unauthorized" });
  }

  next();
}

module.exports = { requireAdminToken };
