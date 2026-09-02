# Demonic Slots — Backend

Optional online sync for the iOS app: players can claim a unique username
and their Soul Coin balance gets mirrored to this server whenever there's
an internet connection. The app itself works fully offline without this -
this backend only makes the balance portable/adjustable, it is never
required to play.

- Node.js + Express, SQLite (via `better-sqlite3`, one file, no separate
  database server to run)
- Listens on **port 3007** (plain HTTP - put a TLS-terminating reverse
  proxy in front of it for real deployments, see below)
- No third-party accounts, no payment processing - usernames and integer
  coin balances only

## Player progression: level, win-chance multiplier & guaranteed jackpot

Every player row also carries a `level` (integer, 1-100), a
`win_chance_multiplier` (real, 0.10-2.00), and a `guaranteed_jackpot` flag
(boolean), used by the app's `PlayerProgressionService` to size bet limits,
nudge win probability, and (for the jackpot flag) bypass odds entirely -
see the iOS README's "Player progression" section for how they're actually
used in-game. As far as this backend is concerned, all three are just more
server-authoritative fields on a player:

- **`win_chance_multiplier` and `guaranteed_jackpot` are admin-only**, full
  stop - there's no gameplay path that changes either, only an admin edit
  does. `guaranteed_jackpot` is the "always win" override: while `true`,
  every spin/climb attempt on that player's device lands the best possible
  outcome outright, no roll at all.
- **`level` is admin-settable, and separately app-earnable via XP.** The
  app tracks its own `totalXP` purely client-side (1 XP per Soul Coin
  wagered - see the iOS README's "XP" section) and, once that justifies a
  higher level than the server has on file, claims it via an optional
  `earnedLevel` field on `POST /api/players/sync` (see the API table
  below). The server applies `newLevel = max(currentLevel, earnedLevel)` -
  a claim can only ever raise the stored level, never lower it, so an
  admin boost above what a player has actually earned by playing is never
  walked back just by continuing to play.
- Setting `level`/`win_chance_multiplier`/`guaranteed_jackpot` - whether via
  an admin edit or a client's `earnedLevel` claim - never touches
  `admin_revision`: that counter exists purely to arbitrate a *coin
  balance* conflict between "what the device played locally" and "what an
  admin set directly", and none of these is a competing write against the
  balance - the device just picks up the new value on its very next sync
  either way.
- **Defaults for every existing player**: `level = 1`,
  `win_chance_multiplier = 1.0`, `guaranteed_jackpot = false`, added by
  automatic, idempotent migrations in `db.js` (`ALTER TABLE ... ADD
  COLUMN ... DEFAULT ...`, guarded by `PRAGMA table_info` so each only runs
  once) - no existing `username`/`coin_balance`/`admin_revision`/timestamps
  are touched.
- **Validated server-side**, not just trusted from a future admin app:
  `level` must be an integer in `1...100`, `win_chance_multiplier` a finite
  number in `0.10...2.00`, `guaranteed_jackpot` a real JSON boolean -
  anything else (including `NaN`/`Infinity`, which fail
  `Number.isFinite`, or a truthy string/number instead of `true`/`false`)
  is rejected with `400`, never silently clamped, coerced, or stored. See
  `routes/admin.js`'s `isValidLevel`/`isValidWinChanceMultiplier`/
  `isValidGuaranteedJackpot`.

## How the sync/conflict logic works

Every player row has an `admin_revision` counter that is **only**
incremented when *you* change a balance through the admin API/page below -
never by normal gameplay syncs. That single counter is enough to implement
exactly the rule that was asked for:

1. The app calls `POST /api/players/sync` after playing, sending its local
   balance plus the `adminRevision` it last saw from the server.
2. If the server's `admin_revision` has moved on since then, **you** must
   have changed the balance directly - that value wins unconditionally,
   the app overwrites its local balance with the server's, no matter what
   happened offline in the meantime.
3. Otherwise nothing admin-side has changed, so the app's local balance
   (which reflects real gameplay) is written to the server.

## Local setup

```bash
cd backend
npm install
cp .env.example .env
# edit .env: set a real ADMIN_TOKEN (openssl rand -hex 32), review PORT/DB_PATH
npm start
```

Health check: `curl http://localhost:3007/api/health`

Smoke test (registration, uniqueness, both sync-conflict outcomes, device-token
and admin-token auth) against a running instance:

```bash
BASE_URL=http://localhost:3007 ADMIN_TOKEN=$(grep ADMIN_TOKEN .env | cut -d= -f2) ./test/smoke-test.sh
```

## API

All request/response bodies are JSON.

| Method & path | Auth | Purpose |
|---|---|---|
| `GET /api/health` | none | Liveness check |
| `POST /api/players/register` | none | Claim a username. Body: `{ "username": "TheDemonLord333", "initialBalance": 5000 }`. `409 username_taken` if already claimed (case-insensitive). Returns `{ username, coinBalance, adminRevision, level, winChanceMultiplier, guaranteedJackpot, deviceToken }` - **the app must store `deviceToken` locally**, it's the secret that authenticates every future sync call for this username (there is no password). New players start at `level: 1`, `winChanceMultiplier: 1.0`, `guaranteedJackpot: false`. |
| `POST /api/players/sync` | device token in body | Body: `{ "username", "deviceToken", "localBalance", "lastKnownAdminRevision", "earnedLevel"? }`. `earnedLevel` is optional - the app's own claim (from local XP) that it has earned a level above what the server has; ignored if missing, not an integer in `1...100`, or not actually higher than the stored level (never an error either way, just a silent no-op). Returns `{ resolution: "server_wins" \| "client_applied", username, coinBalance, adminRevision, level, winChanceMultiplier, guaranteedJackpot, updatedAt }` per the conflict rule above. `level`/`winChanceMultiplier`/`guaranteedJackpot` (reflecting any accepted `earnedLevel` claim) are always the current server values regardless of `resolution` - none of them is part of the coin-balance conflict. `403 invalid_device_token` if the token doesn't match that username. If `username` doesn't resolve to any player, falls back to a device-token lookup before giving up (`404 not_found`) - covers a device syncing under a username an admin has since renamed via the endpoint below. |
| `GET /api/admin/players` | `Authorization: Bearer <ADMIN_TOKEN>` | List every registered player. Each entry carries a stable `id` - use it, not `username`, to address a specific player in the endpoint below - plus `level`/`winChanceMultiplier`/`guaranteedJackpot`. |
| `GET /api/admin/players/:id` | same | One player's current state, looked up by their stable `id`. |
| `PATCH /api/admin/players/:id` | same | Body: any non-empty subset of `{ "username": "NewName", "balance": 12345, "level": 20, "winChanceMultiplier": 1.15, "guaranteedJackpot": true }` - send only the field(s) you're changing, addressed by the player's stable `id` (a rename never has to touch or re-find anything else, unlike keying off the mutable username). Setting `balance` **increments `admin_revision`**; setting `username`/`level`/`winChanceMultiplier`/`guaranteedJackpot` does not (see "Player progression" above for why). `404 not_found` if `:id` doesn't exist, `409 username_taken` if the new username is already claimed by a *different* player (case-insensitive), `400 invalid_username`/`invalid_level`/`invalid_win_chance_multiplier`/`invalid_guaranteed_jackpot`/`invalid_balance` for an out-of-range or wrong-typed value, `400 no_fields_to_update` for an empty body. This is the one call your admin app needs for all five fields. |

`id` is a stable identifier assigned once at registration and never
changes - it's the actual primary key now (`username` is just a mutable
label on it, which is what makes renaming safe: nothing else has to be
found, moved, or re-pointed). Player-facing endpoints (`/api/players/*`)
are unchanged and still address players by `username`/`deviceToken`, since
the app doesn't need to know about `id` for anything it currently does.

A minimal built-in admin page is served at `/admin` (e.g.
`https://demonicslots.thedemonlord333.me/admin`) - paste your `ADMIN_TOKEN`
in, list players, edit balance/level/win-multiplier. It's there so you have
something usable immediately; swap it for (or add to it) a dedicated admin
app any time by calling the same `/api/admin/*` endpoints - nothing about
the protocol is tied to that page.

## Deploying on Debian 12

This app is configured to talk to **`demonicslots.thedemonlord333.me`**
(`DemonicSlots/Core/Networking/BackendConfig.swift`) - point that domain's
DNS A/AAAA record at this server before running `certbot` below.

The whole repo is cloned directly to **`/srv/nodeapps/demonicslotsios`**,
and the backend runs out of `/srv/nodeapps/demonicslotsios/backend` -
`deploy/demonicslots-backend.service` already has that path filled in.
No separate copy/staging step, no second checkout - one clone, one place.

> **Two footguns that bite here, both about the `demonicslots` service
> user created below:**
>
> 1. **`EACCES: permission denied, mkdir ...`** on `npm install` means the
>    directory you're installing into isn't owned by whichever user is
>    running `npm`. `npm install` (especially with `--prefix`) will try to
>    create missing folders itself, but it can only do that if it already
>    has write access to their *parent* - it can't sudo itself. Fix:
>    `chown -R demonicslots:demonicslots` the whole checkout **before**
>    running `npm install` as that user, not after (steps 2-3 below, in
>    that order).
> 2. **`sudo -u demonicslots` on its own does nothing** (you'll just see
>    sudo's usage/help text) - it always needs a command after it, e.g.
>    `sudo -u demonicslots npm install ...`. It also does **not** give you
>    an interactive shell "as" that user the way `su demonicslots` would.
>    And since the account is created with `--shell /usr/sbin/nologin`
>    (deliberately, so a compromised Node process can't be used to log in
>    interactively), `su demonicslots` or `sudo -u demonicslots -s` won't
>    work either - always prefix each individual command with
>    `sudo -u demonicslots <command...>` instead.
> 3. **`systemctl start` fails with `Result: resources`** is systemd's
>    generic bucket for "couldn't even get the process running", so it
>    covers a few unrelated causes - **always check the real reason
>    first**, don't guess:
>    ```
>    journalctl -xeu demonicslots-backend.service --no-pager | tail -30
>    ```
>    Look for a `systemd[1]:` line right above `Failed with result
>    'resources'` - that's the actual cause. The two seen so far:
>    - **`Failed to load environment files: No such file or directory`**
>      - `EnvironmentFile=.../backend/.env` doesn't exist. Unlike
>        `ExecStart`, systemd treats a missing `EnvironmentFile=` as fatal
>        (there's an optional `-`-prefixed form, deliberately not used
>        here since `ADMIN_TOKEN` is required). Fix: create it - step 3
>        below does this (`cp .env.example .env` then set `ADMIN_TOKEN`).
>    - A path in `ReadWritePaths=` doesn't exist yet - `mkdir` it (as
>      `demonicslots`); step 3 below does this too.
>
>    A third possibility if the journal instead mentions `namespace` or
>    `mount`: the host won't grant the service a new mount namespace at
>    all, which `PrivateTmp`/`ProtectSystem=strict`/`ReadWritePaths` all
>    need - happens on some virtualized/restricted "root servers" (OpenVZ,
>    certain LXC setups). `deploy/demonicslots-backend.service` no longer
>    uses any of those three directives for exactly this reason (kept only
>    `NoNewPrivileges=true`, a plain syscall rather than a namespace
>    operation) - if you're on an older copy of the unit file,
>    `sudo git -C /srv/nodeapps/demonicslotsios pull` and re-install it.
>
>    If you just ran that `git pull` and the failure looks identical to
>    before (same paths in `journalctl`, `EnvironmentFile=` pointing
>    somewhere that doesn't exist) - **check that the pull actually did
>    anything**. `git status`/`git pull` run as root against a checkout
>    that's owned by `demonicslots` (step 2's `chown -R` covers the whole
>    repo, `.git/` included) fails outright since Git 2.35, with
>    `fatal: detected dubious ownership in repository at ...`, and that
>    fatal error is easy to miss if it's buried in a block of other
>    commands. When that happens the working tree is silently left exactly
>    as it was, so every later `cp .../deploy/demonicslots-backend.service
>    /etc/systemd/system/` faithfully re-installs the same stale file and
>    you get the exact same `journalctl` output as before, forever. Fix
>    once, as root:
>    ```
>    sudo git config --global --add safe.directory /srv/nodeapps/demonicslotsios
>    ```
>    then re-run `git pull` - it now needs to actually print updated file
>    names (or `Already up to date.`), not a `fatal:` line, before you
>    trust anything it changed.

```bash
# 1. System packages (build tools only needed if better-sqlite3 can't use
#    its prebuilt binary for your architecture - try without first)
sudo apt update
sudo apt install -y nodejs npm nginx certbot python3-certbot-nginx

# 2. Clone the repo where it'll actually run from, create the dedicated
#    service user, and hand it ownership of the whole checkout BEFORE
#    anything (npm install, writing .env) touches it.
sudo mkdir -p /srv/nodeapps
sudo git clone <your-repo-url> /srv/nodeapps/demonicslotsios   # or: sudo git -C /srv/nodeapps/demonicslotsios pull
sudo useradd --system --home /srv/nodeapps/demonicslotsios --shell /usr/sbin/nologin demonicslots || true
sudo chown -R demonicslots:demonicslots /srv/nodeapps/demonicslotsios

# 3. .env + dependencies, run as the demonicslots user (see footgun #2
#    above - every command needs the `sudo -u demonicslots` prefix).
#    The `mkdir -p .../data` matters - see footgun #3 above; it's a
#    no-op if that directory already exists (e.g. from git).
sudo -u demonicslots mkdir -p /srv/nodeapps/demonicslotsios/backend/data
sudo -u demonicslots cp /srv/nodeapps/demonicslotsios/backend/.env.example /srv/nodeapps/demonicslotsios/backend/.env
sudo -u demonicslots nano /srv/nodeapps/demonicslotsios/backend/.env   # set ADMIN_TOKEN (openssl rand -hex 32)
sudo -u demonicslots npm install --omit=dev --prefix /srv/nodeapps/demonicslotsios/backend

# 4. systemd service
sudo cp /srv/nodeapps/demonicslotsios/backend/deploy/demonicslots-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now demonicslots-backend
sudo systemctl status demonicslots-backend

# 5. Firewall: only nginx (80/443) needs to be reachable from the internet;
#    3007 stays internal to the box, nginx proxies to it over localhost.
sudo ufw allow 80,443/tcp
sudo ufw deny 3007

# 6. nginx + TLS (reverse proxy; deploy/nginx.conf.example already has the
#    right server_name, demonicslots.thedemonlord333.me, filled in)
sudo cp /srv/nodeapps/demonicslotsios/backend/deploy/nginx.conf.example /etc/nginx/sites-available/demonicslots
sudo ln -s /etc/nginx/sites-available/demonicslots /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d demonicslots.thedemonlord333.me   # issues the cert and
                                        # rewrites the nginx config for HTTPS + redirect
```

If you already have a partially-created `/srv/nodeapps/demonicslotsios`
from a failed attempt, just re-run step 2's `chown -R` (harmless to
repeat) before retrying `npm install` - nothing needs to be deleted first.

After that, `https://demonicslots.thedemonlord333.me/api/health` should
return `{"status":"ok",...}` and the app talks to that same URL (not
directly to port 3007 - nginx/certbot terminate TLS and forward
internally).

### Updating after a `git pull`

`git pull` always runs as root/sudo, never as `demonicslots` (that account
can't log in interactively - see footgun #2 above, and it doesn't need
write access to `.git/` anyway). The very first time you do this against a
checkout that's already been `chown -R demonicslots`'d (step 2), Git
refuses with `fatal: detected dubious ownership in repository at ...` -
run the `git config` line below once (harmless to repeat) to fix that
permanently, see footgun #3 above for why it happens:

```bash
sudo git config --global --add safe.directory /srv/nodeapps/demonicslotsios

sudo systemctl stop demonicslots-backend
sudo git -C /srv/nodeapps/demonicslotsios pull   # must print changed files or "Already up to date.", not a fatal: line
sudo chown -R demonicslots:demonicslots /srv/nodeapps/demonicslotsios   # pull re-creates files as root - fix ownership again
sudo -u demonicslots npm install --omit=dev --prefix /srv/nodeapps/demonicslotsios/backend
sudo cp /srv/nodeapps/demonicslotsios/backend/deploy/demonicslots-backend.service /etc/systemd/system/   # unit file may have changed too
sudo systemctl daemon-reload
sudo systemctl start demonicslots-backend
```

### Backups

Everything lives in one file: `/srv/nodeapps/demonicslotsios/backend/data/demonicslots.sqlite`
(plus WAL sidecar files while the process is running). Stop the service or
use `sqlite3 data/demonicslots.sqlite ".backup backup.sqlite"` (run from
that `backend/` directory) for a consistent snapshot without downtime.
