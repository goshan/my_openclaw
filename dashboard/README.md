# Dashboard Server Setup

This directory sets up the Metabase visualization server. It assumes a MySQL server is accessible (actually is also running on this server).

## How It Works

```
Main server (OpenClaw)
  → writes expense and mail data to MySQL server

Metabase (Docker)
  → reads from MySQL server (local at the moment)
  → serves visualizations at http://<metabase-server-ip>:4000
```

## Files

| File | Description |
|------|-------------|
| `docker-compose.yml` | Runs Metabase on port 4000, connecting to local MySQL via `host.docker.internal` |

---

## Setup

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sh

systemctl start docker
systemctl enable docker

# (Optional) Allow your user to run docker without 'sudo'
sudo usermod -aG docker $USER
newgrp docker
```

Verify:

```bash
docker -v
```

### 2. Install MySQL


```bash
sudo apt update
sudo apt install -y mysql-server mysql-client
sudo systemctl enable mysql
sudo systemctl start mysql
```

### 3. Configure MySQL for remote access

Because just at the moment, mysql server also runs in this server, so need to config mysql server and user permissions

By default MySQL only listens on localhost. Open it to remote connections, also set charset to `utf8mb4`.

Edit `/etc/my.cnf` and add under `[mysqld]`:

```ini
[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4

[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
bind-address = 0.0.0.0
```

Restart MySQL:

```bash
sudo systemctl restart mysql
```

Create the databases and users:

```bash
sudo mysql
```

```sql
CREATE DATABASE mails_monitor CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE expense CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE USER '<user_for_openclaw>'@'<openclaw-server-ip>' IDENTIFIED BY '<password_for_openclaw>';
GRANT ALL PRIVILEGES ON mails_monitor.* TO '<user_for_openclaw>'@'<openclaw-server-ip>';
GRANT ALL PRIVILEGES ON expense.* TO '<user_for_openclaw>'@'<openclaw-server-ip>';

-- '%' is required because Metabase connects from inside Docker (e.g. 172.18.0.x), not localhost
CREATE USER '<user_for_dashboard>'@'172.%' IDENTIFIED BY '<password_for_dashboard>';
GRANT ALL PRIVILEGES ON mails_monitor.* TO '<user_for_dashboard>'@'172.%';
GRANT ALL PRIVILEGES ON expense.* TO '<user_for_dashboard>'@'172.%';

FLUSH PRIVILEGES;
```

Verify the OpenClaw server can connect:

```bash
# Run this from the OpenClaw server
mysql -h <mysql-server-ip> -u<user_for_openclaw> -p
```

Verify the dashboard user works:

```bash
# Run this from Dashboard server
docker run --rm -it <any_docker_image> "mysql -hhost.docker.internal -u<user_for_dashboard> -p<password_for_dashboard>"
```

### 4. Clone the repo

```bash
git clone <repo-url> <my_openclaw_path>
```

### 5. Start Metabase

```bash
cd <my_openclaw_path>/dashboard
docker compose up -d
```

Metabase will be available at `http://<metabase-server-ip>:4000`. Complete the initial setup wizard, then:

1. Go to **Settings → Admin → Databases → Add database**
2. Choose **MySQL**
3. Set host to `host.docker.internal`, port `3306`, user/password from step 3
4. Add `expense` as one database

To stop:

```bash
docker compose stop
```

---

## Updating

To update Metabase to a new version:

```bash
cd <my_openclaw_path>/dashboard
docker compose stop
docker compose pull
docker compose up -d
```
