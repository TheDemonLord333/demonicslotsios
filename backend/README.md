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
`https://your-domain/admin`) - paste your `ADMIN_TOKEN` in, list players,
edit balances. It's there so you have something usable immediately; swap
it for (or add to it) a dedicated admin app any time by calling the same
`/api/admin/*` endpoints - nothing about the protocol is tied to that page.

## Deploying on Debian 12

```bash
# 1. System packages (build tools only needed if better-sqlite3 can't use
#    its prebuilt binary for your architecture - try without first)
sudo apt update
sudo apt install -y nodejs npm nginx certbot python3-certbot-nginx

# 2. Get the code onto the server and install dependencies
sudo mkdir -p /opt/demonicslots
sudo git clone <your-repo-url> /opt/demonicslots-src   # or `git pull` if already cloned
sudo cp -r /opt/demonicslots-src/backend /opt/demonicslots/backend
cd /opt/demonicslots/backend
sudo cp .env.example .env
sudo nano .env    # set ADMIN_TOKEN to a real secret (openssl rand -hex 32)
sudo useradd --system --home /opt/demonicslots/backend --shell /usr/sbin/nologin demonicslots
sudo chown -R demonicslots:demonicslots /opt/demonicslots/backend
sudo -u demonicslots npm install --omit=dev --prefix /opt/demonicslots/backend

# 3. systemd service
sudo cp deploy/demonicslots-backend.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now demonicslots-backend
sudo systemctl status demonicslots-backend

# 4. Firewall: only nginx (80/443) needs to be reachable from the internet;
#    3007 stays internal to the box, nginx proxies to it over localhost.
sudo ufw allow 80,443/tcp
sudo ufw deny 3007

# 5. nginx + TLS (reverse proxy, per the HTTPS setup chosen for this app)
sudo cp deploy/nginx.conf.example /etc/nginx/sites-available/demonicslots
sudo nano /etc/nginx/sites-available/demonicslots   # replace YOUR_DOMAIN
sudo ln -s /etc/nginx/sites-available/demonicslots /etc/nginx/sites-enabled/
sudo nginx -t && sudo systemctl reload nginx
sudo certbot --nginx -d YOUR_DOMAIN   # issues the cert and rewrites the
                                        # nginx config to serve HTTPS + redirect
```

After that, `https://YOUR_DOMAIN/api/health` should return `{"status":"ok",...}`
and the app talks to `https://YOUR_DOMAIN` (not directly to port 3007 -
nginx/certbot terminate TLS and forward internally).

### Updating after a `git pull`

```bash
sudo systemctl stop demonicslots-backend
sudo -u demonicslots git -C /opt/demonicslots-src pull
sudo cp -r /opt/demonicslots-src/backend/. /opt/demonicslots/backend/  # keep your existing .env and data/
sudo -u demonicslots npm install --omit=dev --prefix /opt/demonicslots/backend
sudo systemctl start demonicslots-backend
```

### Backups

Everything lives in one file: `data/demonicslots.sqlite` (plus WAL
sidecar files while the process is running). Stop the service or use
`sqlite3 data/demonicslots.sqlite ".backup backup.sqlite"` for a
consistent snapshot without downtime.
