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
> 3. **`systemctl start` fails with `Result: resources`** has two possible
>    causes, in order of likelihood:
>    1. A path in `ReadWritePaths=` doesn't exist yet - `mkdir` it (as
>       `demonicslots`) before starting the service; step 3 below does
>       this.
>    2. The host itself won't grant the service a new mount namespace at
>       all, which `PrivateTmp`/`ProtectSystem=strict`/`ReadWritePaths`
>       all need - common on virtualized/restricted "root servers"
>       (OpenVZ, some LXC setups). If restarting after (1) still fails
>       identically, this is almost certainly it: run
>       `journalctl -xeu demonicslots-backend.service --no-pager | tail -30`
>       to confirm (look for `namespace`/`mount` in the error), then drop
>       those three directives from `deploy/demonicslots-backend.service`
>       (keep `NoNewPrivileges=true` - that one's a plain syscall, not a
>       namespace, and works everywhere) and
>       `sudo cp deploy/demonicslots-backend.service /etc/systemd/system/ && sudo systemctl daemon-reload && sudo systemctl restart demonicslots-backend`.
>       The already-current version of that file in the repo has this
>       pre-applied.

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
write access to `.git/` anyway):

```bash
sudo systemctl stop demonicslots-backend
sudo git -C /srv/nodeapps/demonicslotsios pull
sudo chown -R demonicslots:demonicslots /srv/nodeapps/demonicslotsios   # pull re-creates files as root - fix ownership again
sudo -u demonicslots npm install --omit=dev --prefix /srv/nodeapps/demonicslotsios/backend
sudo systemctl start demonicslots-backend
```

### Backups

Everything lives in one file: `/srv/nodeapps/demonicslotsios/backend/data/demonicslots.sqlite`
(plus WAL sidecar files while the process is running). Stop the service or
use `sqlite3 data/demonicslots.sqlite ".backup backup.sqlite"` (run from
that `backend/` directory) for a consistent snapshot without downtime.
