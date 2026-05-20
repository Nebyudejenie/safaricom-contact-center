# SETUP GUIDE - BUILD THE CONTACT CENTER

**Time to Deploy:** 30 minutes  
**Complexity:** Medium  
**Requirements:** Docker or Kubernetes

---

## 🚀 QUICK START (5 minutes)

### Option A: Docker Compose (Local - Easiest)

```bash
# Navigate to project
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/BUILD_PROJECT

# Make script executable
chmod +x deploy.sh

# Deploy locally
./deploy.sh local

# Wait 10 seconds for services to start

# Check status
docker-compose ps

# Access the system
curl http://localhost/health
```

**Services Running:**
- ✅ PostgreSQL Database (port 5432)
- ✅ FreeSWITCH IVR x2 (ports 5060, 5061)
- ✅ Load Balancer (port 80)
- ✅ Prometheus (port 9090)
- ✅ Grafana (port 3000)
- ✅ Redis Cache (port 6379)

---

## 📋 DETAILED SETUP

### Step 1: Verify Prerequisites

```bash
# Check Docker
docker --version
# Expected: Docker version 20.10+

# Check Docker Compose
docker-compose --version
# Expected: Docker Compose version 1.29+

# Check if ports are available
netstat -tulpn | grep LISTEN | grep -E "5432|5060|3000"
# Should be empty (ports not in use)
```

### Step 2: Navigate to Project

```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/BUILD_PROJECT

# Verify structure
ls -la

# You should see:
# ├── docker-compose.yml
# ├── deploy.sh
# ├── 01_INFRASTRUCTURE/
# ├── 02_IVR/
# ├── 03_DATABASE/
# ├── 04_MONITORING/
# ├── 05_DEPLOYMENT/
# ├── 06_TESTING/
# └── kubernetes/
```

### Step 3: Make Deploy Script Executable

```bash
chmod +x deploy.sh

# Verify
ls -l deploy.sh
# Should show: -rwxr-xr-x
```

### Step 4: Deploy System

```bash
# Start all services
./deploy.sh local

# Expected output:
# [INFO] Checking prerequisites...
# [SUCCESS] Docker and Docker Compose found
# [INFO] Starting Docker Compose services...
# [INFO] Waiting for services to be ready...
# [INFO] Checking database connectivity...
# [SUCCESS] Contact Center deployed locally!
```

### Step 5: Verify Deployment

```bash
# Check all containers running
docker-compose ps

# Expected: All containers UP

# Check database
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c "SELECT COUNT(*) FROM customers;"
# Expected: 5 (sample customers)

# Check IVR
curl -s http://localhost:8021 | head -20

# Check Grafana
curl -s http://localhost:3000/api/health | grep -o "ok"
# Expected: ok

# Check Redis
docker-compose exec redis redis-cli ping
# Expected: PONG
```

### Step 6: Access the System

**Database:**
```bash
# Connect directly
psql -h localhost -U cc_user -d safaricom_cc

# Or via Docker
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc

# Sample query
SELECT phone_number, name, balance_etb FROM customers LIMIT 5;
```

**Monitoring (Grafana):**
```
URL: http://localhost:3000
Username: admin
Password: admin123
```

**Prometheus Metrics:**
```
URL: http://localhost:9090
```

**IVR Admin:**
```
URL: http://localhost:8021
ESL Interface for FreeSWITCH
```

---

## 🧪 RUN TESTS

### Health Check
```bash
# Test database
docker-compose exec postgres-primary pg_isready -U cc_user

# Test IVR
docker-compose logs ivr-1 | grep -i "started"

# Test connectivity
docker network inspect $(docker-compose ps -q | head -1 | xargs docker inspect -f '{{.HostConfig.NetworkMode}}')
```

### Load Simulation
```bash
# Generate sample calls (manual)
for i in {1..10}; do
  docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c \
    "INSERT INTO calls (customer_id, agent_id, call_start, call_end, duration_seconds, call_outcome) \
     VALUES (1, 1, NOW() - INTERVAL '1 hour', NOW(), 300, 'resolved');"
done

# Verify
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c \
  "SELECT COUNT(*) as total_calls FROM calls;"
```

### View Logs
```bash
# All services
docker-compose logs -f

# Specific service
docker-compose logs -f ivr-1
docker-compose logs -f postgres-primary
docker-compose logs -f nginx-lb
```

---

## 🔧 CONFIGURATION

### IVR Configuration
Location: `02_IVR/config/freeswitch/`

Edit dial plans:
```bash
# View current configuration
cat 02_IVR/config/freeswitch/dialplan/default.xml

# Restart IVR after changes
docker-compose restart ivr-1 ivr-2
```

### Database Configuration
Edit connection settings:
```bash
# In docker-compose.yml, update:
POSTGRES_USER: cc_user
POSTGRES_PASSWORD: cc_password_secure
POSTGRES_DB: safaricom_cc
```

### Monitoring Configuration
Edit metrics:
```bash
# Prometheus config
cat 04_MONITORING/prometheus.yml

# Restart Prometheus
docker-compose restart prometheus
```

---

## 🚨 TROUBLESHOOTING

### Issue: Port Already in Use

```bash
# Find what's using port 5432
lsof -i :5432

# Kill the process
kill -9 <PID>

# Or use different port in docker-compose.yml
# Change "5432:5432" to "5434:5432"
```

### Issue: Database Connection Failed

```bash
# Check database logs
docker-compose logs postgres-primary

# Verify database is running
docker-compose ps postgres-primary

# Restart database
docker-compose restart postgres-primary

# Wait for health check
docker-compose ps postgres-primary
# Should show "Up" and healthy
```

### Issue: IVR Not Responding

```bash
# Check IVR logs
docker-compose logs ivr-1

# Verify FreeSWITCH is running
docker-compose exec ivr-1 fs_cli -x "status"

# Restart IVR
docker-compose restart ivr-1
```

### Issue: No Metrics in Prometheus

```bash
# Check Prometheus scrape targets
curl -s http://localhost:9090/api/v1/targets | python -m json.tool

# Verify metric exporters are running
docker-compose logs prometheus
```

---

## 🛑 STOPPING THE SYSTEM

### Stop (Keep Data)
```bash
docker-compose stop
# Services stop but volumes persist
```

### Restart
```bash
docker-compose start
# Services restart with existing data
```

### Full Cleanup
```bash
./deploy.sh cleanup local
# All containers and volumes deleted
```

---

## 📊 USEFUL COMMANDS

### Database Operations

```bash
# Backup database
docker-compose exec postgres-primary pg_dump -U cc_user -d safaricom_cc > backup.sql

# Restore database
docker-compose exec -T postgres-primary psql -U cc_user -d safaricom_cc < backup.sql

# Get database stats
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c \
  "SELECT schemaname, tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) \
   FROM pg_tables WHERE schemaname NOT IN ('pg_catalog', 'information_schema') \
   ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;"
```

### View Metrics

```bash
# Get CPU usage
docker stats --no-stream

# Get memory usage
docker-compose exec postgres-primary free -h

# Get disk usage
docker-compose exec postgres-primary df -h
```

### Monitoring

```bash
# View all available metrics
curl -s http://localhost:9090/api/v1/labels

# Query specific metric
curl -s 'http://localhost:9090/api/v1/query?query=up'

# View Grafana dashboards
curl -s http://localhost:3000/api/search
```

---

## ✅ VERIFICATION CHECKLIST

After deployment, verify:

- [ ] All 7 containers are running: `docker-compose ps`
- [ ] Database has sample data: `SELECT COUNT(*) FROM customers;`
- [ ] Grafana accessible: http://localhost:3000
- [ ] Prometheus scraping metrics: http://localhost:9090/targets
- [ ] IVR responding: `docker-compose logs ivr-1 | grep -i started`
- [ ] Redis connection: `docker-compose exec redis redis-cli ping`
- [ ] Load balancer healthy: `curl -I http://localhost`

---

## 🎓 NEXT STEPS

### Test the System
```bash
# Simulate incoming call
docker-compose exec ivr-1 fs_cli -x "originate {origination_caller_id_number=254722333001}sofia/internal/1001 &bridge(sofia/internal/1002)"

# Query call history
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c \
  "SELECT * FROM calls ORDER BY call_id DESC LIMIT 5;"
```

### Scale for Load Testing
```bash
# View current IVR replicas
docker-compose ps | grep ivr

# Scale to 5 IVR instances
docker-compose up -d --scale ivr=5
```

### Monitor Performance
1. Open Grafana: http://localhost:3000
2. Go to Dashboards → Contact Center
3. View real-time metrics
4. Create custom alerts

---

## 🚀 YOU'RE READY!

Your Contact Center system is now running!

**Next:** 
- Read `OPERATIONS.md` for day-to-day operations
- Read `TROUBLESHOOTING.md` for common issues
- Practice with real call simulations
- Learn from the actual deployed system

---

**Deployment Complete!** 🎉
