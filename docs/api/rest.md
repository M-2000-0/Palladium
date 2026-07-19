# REST API Reference

Palladium provides a REST API for remote management and multi-host orchestration.

## Base URL

```
http://<host>:8080/api/v1
```

## Authentication

All endpoints (except `/health`) require Bearer token authentication:

```bash
curl -H "Authorization: Bearer YOUR_API_KEY" http://localhost:8080/api/v1/status
```

Get your API key from the Palladium menu: `Security` → `API Server` → `Show API Key`

## Endpoints

### Health Check

```http
GET /health
```

No authentication required. Returns server status.

**Response:**
```json
{
  "status": "ok",
  "version": "1.1.0"
}
```

---

### System Status

```http
GET /api/v1/status
```

Returns system metrics and running services.

**Response:**
```json
{
  "services": [
    {"name": "n8n", "status": "Up 2 hours", "ports": "0.0.0.0:5678->5678/tcp"},
    {"name": "postgres", "status": "Up 2 hours", "ports": "0.0.0.0:5432->5432/tcp"}
  ],
  "system": {
    "cpu_percent": 12.5,
    "memory_percent": 45.2,
    "disk_usage": "65%"
  }
}
```

---

### List Services

```http
GET /api/v1/services
```

**Response:**
```json
{
  "services": [
    {"name": "n8n", "image": "n8nio/n8n:latest", "status": "Up 2 hours", "ports": "0.0.0.0:5678->5678/tcp"}
  ]
}
```

---

### Service Actions

#### Start Service
```http
POST /api/v1/services/{name}/start
```

#### Stop Service
```http
POST /api/v1/services/{name}/stop
```

#### Restart Service
```http
POST /api/v1/services/{name}/restart
```

#### Get Logs
```http
GET /api/v1/services/{name}/logs?lines=100
```

**Response:**
```json
{
  "logs": "2024-01-15 10:30:00 INFO Starting n8n...",
  "error": ""
}
```

---

### Create Service

```http
POST /api/v1/services
Content-Type: application/json

{
  "name": "my-app",
  "image": "nginx:alpine",
  "ports": ["8080:80"],
  "env": {"ENV_VAR": "value"},
  "volumes": ["/host/path:/container/path"]
}
```

**Response:**
```json
{
  "success": true,
  "container_id": "abc123...",
  "error": ""
}
```

---

### Delete Service

```http
DELETE /api/v1/services/{name}
```

---

### Stacks

#### List Available Stacks
```http
GET /api/v1/stacks
```

#### Install Stack
```http
POST /api/v1/stacks/{name}/install
```

---

### Backup

```http
POST /api/v1/backup
Content-Type: application/json

{
  "services": "all",
  "method": "tar",
  "target": "/backups"
}
```

---

### Marketplace

#### List Tools
```http
GET /api/v1/marketplace/tools
```

#### Install Tool
```http
POST /api/v1/marketplace/install/{name}
```

---

## Error Responses

All endpoints may return:

```json
{
  "error": "Error message"
}
```

Common HTTP codes:
- `200` - Success
- `401` - Unauthorized (invalid/missing API key)
- `404` - Not found
- `500` - Internal server error

---

## Example: Python Client

```python
import requests

API_BASE = "http://localhost:8080/api/v1"
API_KEY = "your-api-key"

headers = {"Authorization": f"Bearer {API_KEY}"}

# Get status
r = requests.get(f"{API_BASE}/status", headers=headers)
print(r.json())

# Start a service
r = requests.post(f"{API_BASE}/services/n8n/start", headers=headers)
print(r.json())

# Create new service
r = requests.post(f"{API_BASE}/services", headers=headers, json={
    "name": "my-redis",
    "image": "redis:alpine",
    "ports": ["6379:6379"]
})
print(r.json())
```

---

## Example: Multi-Host Management

```bash
#!/bin/bash
# manage-cluster.sh - Manage multiple Palladium hosts

HOSTS=(
    "http://server1:8080"
    "http://server2:8080"
    "http://server3:8080"
)
API_KEY="shared-cluster-key"

for host in "${HOSTS[@]}"; do
    echo "=== $host ==="
    curl -s -H "Authorization: Bearer $API_KEY" "$host/api/v1/status" | jq '.system'
done
```