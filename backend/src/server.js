"use strict";

require("dotenv").config();

const path = require("node:path");
const express = require("express");
const cors = require("cors");

const playersRouter = require("./routes/players");
const adminRouter = require("./routes/admin");

const app = express();

const allowedOrigins = (process.env.CORS_ALLOWED_ORIGINS || "*").split(",").map((s) => s.trim());
app.use(
  cors({
    origin: allowedOrigins.includes("*") ? true : allowedOrigins,
  })
);
app.use(express.json({ limit: "16kb" }));

app.get("/api/health", (_req, res) => {
  res.json({ status: "ok", service: "demonic-slots-backend", time: new Date().toISOString() });
});

app.use("/api/players", playersRouter);
app.use("/api/admin", adminRouter);

// Minimal built-in admin page (vanilla HTML/JS, no build step) so there's
// something usable at https://<your-domain>/admin immediately, even before
// a dedicated admin app exists. It only reads static files; the token you
// type into it is used purely as the Authorization header for API calls
// made directly from your own browser to this same server.
app.use("/admin", express.static(path.join(__dirname, "public", "admin")));

app.use((req, res) => {
  res.status(404).json({ error: "not_found" });
});

// eslint-disable-next-line no-unused-vars
app.use((err, req, res, next) => {
  console.error(err);
  res.status(500).json({ error: "internal_error" });
});

const PORT = Number(process.env.PORT) || 3007;
app.listen(PORT, () => {
  console.log(`Demonic Slots backend listening on port ${PORT}`);
});
