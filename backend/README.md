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
| `POST /api/players/register` | none | Claim a username. Body: `{ "username": "TheDemonLord333", "initialBalance": 5000 }`. `409 username_taken` if already claimed (case-insensitive). Returns `{ username, coinBalance, adminRevision, deviceToken }` - **the app must store `deviceToken` locally**, it's the secret that authenticates every future sync call for this username (there is no password). |
| `POST /api/players/sync` | device token in body | Body: `{ "username", "deviceToken", "localBalance", "lastKnownAdminRevision" }`. Returns `{ resolution: "server_wins" \| "client_applied", username, coinBalance, adminRevision, updatedAt }` per the conflict rule above. `403 invalid_device_token` if the token doesn't match that username. |
| `GET /api/admin/players` | `Authorization: Bearer <ADMIN_TOKEN>` | List every registered player. |
| `GET /api/admin/players/:username` | same | One player's current state. |
| `PATCH /api/admin/players/:username/balance` | same | Body: `{ "balance": 12345 }`. Sets the balance **and increments `admin_revision`** - this is the call your "weitere App" makes. |

A minimal built-in admin page is served at `/admin` (e.g.
`https://demonicslots.thedemonlord333.me/admin`) - paste your `ADMIN_TOKEN`
in, list players, edit balances. It's there so you have something usable
immediately; swap it for (or add to it) a dedicated admin app any time by
calling the same `/api/admin/*` endpoints - nothing about the protocol is
tied to that page.

## Deploying on Debian 12

This app is configured to talk to **`demonicslots.thedemonlord333.me`**
(`DemonicSlots/Core/Networking/BackendConfig.swift`) - point that domain's
DNS A/AAAA record at this server before running `certbot` below.

The app lives under **`/srv/nodeapps/demonicslots`**. `deploy/demonicslots-backend.service`
already has that path filled in.

> **Why `npm install` can fail with `EACCES: permission denied, mkdir`:**
> it means the directory you're installing into either doesn't exist yet or
> isn't owned by whichever user is running `npm`. `npm install` (especially
> with `--prefix`) will try to create missing folders itself, but it can
> only do that if it has write access to their *parent* directory - it
> can't sudo itself. The fix is always the same: create the directory and
> fix its ownership (`chown -R`) for the exact user that will run `npm`
> **before** running `npm install`, not after. That's what steps 2-3 below
> do, in that order - don't reorder them.

```bash
# 1. System packages (build tools only needed if better-sqlite3 can't use
#    its prebuilt binary for your architecture - try without first)
sudo apt update
sudo apt install -y nodejs npm nginx certbot python3-certbot-nginx

# 2. Create the app directory and a dedicated, unprivileged service user
#    for it FIRST, and fix ownership BEFORE anything writes into it -
#    this is the step that avoids the EACCES error.
sudo mkdir -p /srv/nodeapps/demonicslots
sudo useradd --system --home /srv/nodeapps/demonicslots --shell /usr/sbin/nologin demonicslots || true
sudo chown -R demonicslots:demonicslots /srv/nodeapps/demonicslots

# 3. Get the code onto the server and install dependencies. Everything
#    from here on runs *as the demonicslots user* (via `sudo -u`), so
#    whatever it creates is already owned correctly - never plain
#    `npm install` as your own login user or as root against this path.
sudo git clone <your-repo-url> /srv/nodeapps/demonicslots-src   # or `git pull` if already cloned
sudo cp -r /srv/nodeapps/demonicslots-src/backend/. /srv/nodeapps/demonicslots/backend/
sudo chown -R demonicslots:demonicslots /srv/nodeapps/demonicslots/backend
sudo -u demonicslots cp /srv/nodeapps/demonicslots/backend/.env.example /srv/nodeapps/demonicslots/backend/.env
sudo -u demonicslots nano /srv/nodeapps/demonicslots/backend/.env   # set ADMIN_TOKEN (openssl rand -hex 32)
sudo -u demonicslots npm install --omit=dev --prefix /srv/nodeapps/demonicslots/backend

# 4. systemd service
sudo cp deploy/demonicslots-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now demonicslots-backend
sudo systemctl status demonicslots-backend

# 5. Firewall: only nginx (80/443) needs to be reachable from the internet;
#    3007 stays internal to the box, nginx proxies to it over localhost.
sudo ufw allow 80,443/tcp
sudo ufw deny 3007

# 6. nginx + TLS (reverse proxy; deploy/nginx.conf.example already has the
#    right server_name, demonicslots.thedemonlord333.me, filled in)
sudo cp deploy/nginx.conf.example /etc/nginx/sites-available/demonicslots
sudo ln -s /etc/nginx/sites-available/demonicslots /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d demonicslots.thedemonlord333.me   # issues the cert and
                                        # rewrites the nginx config for HTTPS + redirect
```

If you already have a partially-created `/srv/nodeapps/demonicslots` from a
failed attempt, just re-run step 2's `chown -R` (harmless to repeat) before
retrying `npm install` - you don't need to delete anything first.

After that, `https://demonicslots.thedemonlord333.me/api/health` should
return `{"status":"ok",...}` and the app talks to that same URL (not
directly to port 3007 - nginx/certbot terminate TLS and forward
internally).

### Updating after a `git pull`

The `-src` checkout stays root-owned throughout (only the deployed
`backend/` copy is handed to the `demonicslots` user), so `git clone`/`pull`
against it always run as root/sudo, never as `demonicslots`:

```bash
sudo systemctl stop demonicslots-backend
sudo git -C /srv/nodeapps/demonicslots-src pull
sudo cp -r /srv/nodeapps/demonicslots-src/backend/. /srv/nodeapps/demonicslots/backend/  # keep your existing .env and data/
sudo chown -R demonicslots:demonicslots /srv/nodeapps/demonicslots/backend
sudo -u demonicslots npm install --omit=dev --prefix /srv/nodeapps/demonicslots/backend
sudo systemctl start demonicslots-backend
```

### Backups

Everything lives in one file: `/srv/nodeapps/demonicslots/backend/data/demonicslots.sqlite`
(plus WAL sidecar files while the process is running). Stop the service or
use `sqlite3 data/demonicslots.sqlite ".backup backup.sqlite"` (run from
that `backend/` directory) for a consistent snapshot without downtime.
