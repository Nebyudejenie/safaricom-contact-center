# 🚀 START BUILDING - COMPLETE PROJECT LAB

**Status:** Ready to Deploy  
**Deployment Time:** 30 minutes  
**Complexity:** Intermediate  
**Learning Outcome:** Build and operate a real contact center system

---

## 📦 WHAT'S INCLUDED

### Complete Working System

```
A fully functional contact center with:
✅ PostgreSQL Database (Primary + Backup)
✅ FreeSWITCH IVR (2 instances)
✅ Load Balancer (Nginx)
✅ Monitoring Stack (Prometheus + Grafana)
✅ Redis Cache
✅ API Stubs (for testing)
```

### Three Deployment Options

```
1. DOCKER COMPOSE (Local) - Easiest ⭐ START HERE
   └─ Single command: ./deploy.sh local
   └─ Ready in: 5 minutes
   └─ Best for: Learning and testing

2. KUBERNETES (Cluster)
   └─ Command: ./deploy.sh kubernetes
   └─ Ready in: 15 minutes
   └─ Best for: Production-like environment

3. TERRAFORM (AWS)
   └─ Command: ./deploy.sh terraform
   └─ Ready in: 30 minutes
   └─ Best for: Real cloud infrastructure
```

---

## ⚡ QUICK START (5 MINUTES)

### Step 1: Navigate to Project
```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/BUILD_PROJECT
```

### Step 2: Make Script Executable
```bash
chmod +x deploy.sh
```

### Step 3: Deploy System
```bash
./deploy.sh local
```

### Step 4: Verify Running
```bash
docker-compose ps
# All 7 containers should show "Up"
```

### Step 5: Access System
```
Grafana (Monitoring): http://localhost:3000
  Username: admin
  Password: admin123

Database: localhost:5432
  User: cc_user
  Database: safaricom_cc

Prometheus: http://localhost:9090
```

**That's it! System is running.** 🎉

---

## 📂 PROJECT STRUCTURE

```
BUILD_PROJECT/
│
├── 📋 README.md                    ← Overview
├── 📋 SETUP.md                     ← Detailed setup guide (READ THIS!)
├── 📋 START_BUILD.md               ← You are here
├── 📋 OPERATIONS.md                ← Day-to-day operations
├── 🔧 deploy.sh                    ← Deployment script
├── 🐳 docker-compose.yml           ← Docker Compose config
│
├── 01_INFRASTRUCTURE/              ← Infrastructure as Code
│   ├── nginx.conf                  ← Load balancer config
│   └── terraform/                  ← AWS Terraform code
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
│
├── 02_IVR/                         ← FreeSWITCH Configuration
│   ├── config/
│   │   └── freeswitch/
│   │       ├── dialplan/
│   │       ├── profiles/
│   │       └── scripts/
│   └── scripts/                    ← Setup scripts
│
├── 03_DATABASE/                    ← PostgreSQL
│   ├── schema.sql                  ← Database schema (IMPORTANT!)
│   └── backup_restore.sh           ← Backup procedures
│
├── 04_MONITORING/                  ← Prometheus + Grafana
│   ├── prometheus.yml              ← Metrics config
│   ├── alertmanager.yml            ← Alerting rules
│   ├── alerts.yml                  ← Alert definitions
│   └── grafana/                    ← Dashboard definitions
│
├── 05_DEPLOYMENT/                  ← CI/CD & Deployment
│   ├── docker-compose.yml
│   ├── helm-values.yml
│   └── api-stub.js                 ← Mock API for testing
│
├── 06_TESTING/                     ← Test Suite
│   ├── load_test.sh                ← Load testing script
│   ├── failover_test.sh            ← HA testing
│   └── integration_test.sh         ← Integration tests
│
├── 07_DOCUMENTATION/               ← Additional docs
│   ├── OPERATIONS.md               ← Day-to-day operations
│   ├── TROUBLESHOOTING.md          ← Common issues
│   └── API.md                      ← API documentation
│
└── kubernetes/                     ← Kubernetes Manifests
    └── deployment.yaml             ← K8s deployment specs
```

---

## 🎯 WHAT YOU'LL LEARN

By building this system, you'll understand:

**Architecture:**
- [ ] Multi-layer system design
- [ ] Database replication
- [ ] Load balancing
- [ ] Scaling strategies

**Operations:**
- [ ] Docker and containerization
- [ ] Kubernetes deployment
- [ ] Monitoring and observability
- [ ] Infrastructure as Code

**Production Skills:**
- [ ] Database backup/restore
- [ ] Failover procedures
- [ ] Performance optimization
- [ ] Incident response

---

## 📖 DOCUMENTATION

### For Quick Start
```
Read: START_BUILD.md (this file)
Time: 5 minutes
Goal: Get system running
```

### For Complete Setup
```
Read: SETUP.md
Time: 30 minutes
Goal: Understand all components
```

### For Operations
```
Read: OPERATIONS.md
Time: 20 minutes
Goal: Run the system daily
```

### For Troubleshooting
```
Read: TROUBLESHOOTING.md
Time: As needed
Goal: Fix common issues
```

---

## 🔍 KEY FILES EXPLAINED

### docker-compose.yml
```
Defines all 7 services:
- postgres-primary (database)
- postgres-backup (HA)
- ivr-1, ivr-2 (IVR instances)
- nginx-lb (load balancer)
- prometheus (metrics)
- grafana (dashboards)
- redis (cache)

Change here if you need to:
- Adjust ports
- Change passwords
- Modify resource limits
```

### 03_DATABASE/schema.sql
```
Defines database structure:
- customers table
- calls table (main data)
- agents table
- performance metrics
- system events

This is what data looks like in production!
```

### kubernetes/deployment.yaml
```
Production-ready K8s manifests:
- StatefulSet for database
- Deployment for IVR
- HPA (auto-scaling)
- Monitoring stack
- All with proper probes and limits
```

### deploy.sh
```
Smart deployment script that:
1. Checks prerequisites
2. Validates configuration
3. Deploys system
4. Verifies health
5. Shows access information
```

---

## 🚀 DEPLOYMENT OPTIONS

### Option 1: Docker Compose (Recommended for Learning)

**Pros:**
- ✅ Simplest to get started
- ✅ Works on local machine
- ✅ Fast (5 minutes)
- ✅ All services visible

**Cons:**
- ❌ Not production-like
- ❌ No clustering
- ❌ Single host only

**Command:**
```bash
./deploy.sh local
```

**Access:**
- Grafana: http://localhost:3000
- Prometheus: http://localhost:9090
- Database: localhost:5432

---

### Option 2: Kubernetes (Production-Like)

**Pros:**
- ✅ Production environment
- ✅ Auto-scaling
- ✅ Self-healing
- ✅ High availability

**Cons:**
- ❌ Need K8s cluster
- ❌ More complex
- ❌ Takes 15 min to deploy

**Prerequisites:**
```bash
# Need kubectl configured
kubectl cluster-info

# Verify context
kubectl config current-context
```

**Command:**
```bash
./deploy.sh kubernetes
```

**Access:**
```bash
# Port forward Grafana
kubectl port-forward -n safaricom-cc svc/grafana 3000:3000

# View all resources
kubectl get all -n safaricom-cc
```

---

### Option 3: Terraform/AWS (Real Cloud)

**Pros:**
- ✅ Real AWS infrastructure
- ✅ Production-ready
- ✅ Scalable
- ✅ Professional grade

**Cons:**
- ❌ Costs money
- ❌ Most complex
- ❌ Takes 30+ minutes

**Prerequisites:**
```bash
# AWS account configured
aws sts get-caller-identity

# Terraform installed
terraform --version
```

**Command:**
```bash
./deploy.sh terraform
```

---

## 🧪 TESTING THE SYSTEM

### Health Check
```bash
# Check all containers
docker-compose ps

# Expected: All showing "Up"

# Test database
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c \
  "SELECT 'Connected!' as status;"

# Expected: Connected!
```

### Simulate Calls
```bash
# Add 100 sample calls to database
for i in {1..100}; do
  docker-compose exec -T postgres-primary psql -U cc_user -d safaricom_cc -c \
    "INSERT INTO calls (customer_id, agent_id, call_start, call_end, duration_seconds, call_outcome) \
     VALUES (FLOOR(RANDOM()*5)+1, FLOOR(RANDOM()*5)+1, NOW() - INTERVAL '${RANDOM} minutes', NOW(), 300, 'resolved');"
done

# View statistics
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc -c \
  "SELECT COUNT(*) as total_calls, AVG(duration_seconds) as avg_duration FROM calls;"
```

### Monitor Performance
```
1. Open Grafana: http://localhost:3000
2. Login: admin / admin123
3. Go to Dashboards → Contact Center
4. Watch real-time metrics
5. Create custom alerts
```

---

## 🛑 CLEANUP

### Stop System (Keep Data)
```bash
docker-compose stop
# Services stop but data persists
```

### Restart System
```bash
docker-compose start
# Services restart with same data
```

### Full Cleanup (Delete Everything)
```bash
./deploy.sh cleanup local
# All containers and volumes deleted
```

---

## 📊 SYSTEM ARCHITECTURE

```
CUSTOMERS
    │
    ↓
┌─────────────────┐
│  SBC (Inbound)  │  ← Receives calls
└────────┬────────┘
         │
    LOAD BALANCER  ← Routes to available IVR
    /      │      \
   /       │       \
IVR-1  IVR-2   IVR-3  ← Multiple instances (scaling)
  │       │       │
  └───┬───┴───┬───┘
      │       │
  DATABASE  REDIS  ← Fast data access
      │
   MONITORING  ← Prometheus + Grafana
```

---

## 💡 LEARNING PROGRESSION

**If you're new to this:**
1. Start with docker-compose (local)
2. Follow SETUP.md step by step
3. Browse the code
4. Try the operations commands
5. Simulate some failures
6. Advance to Kubernetes

**If you have K8s experience:**
1. Deploy to Kubernetes
2. Observe auto-scaling
3. Test failover
4. Deploy updates
5. Monitor metrics

**If you want to go deeper:**
1. Deploy to AWS with Terraform
2. Set up proper networking
3. Configure auto-scaling policies
4. Implement disaster recovery
5. Test real-world scenarios

---

## 🎓 EXERCISES

### Exercise 1: Basic Operations (15 min)
```
1. Deploy system locally
2. Query database (count customers)
3. Access Grafana
4. Create simple dashboard
5. Stop and restart system
```

### Exercise 2: Simulate Traffic (30 min)
```
1. Add 1,000 sample calls to database
2. Monitor Prometheus metrics
3. Watch Grafana dashboard
4. Calculate performance stats
5. Identify bottlenecks
```

### Exercise 3: Failure Scenario (20 min)
```
1. Start system normally
2. Stop database: docker-compose stop postgres-primary
3. Observe what breaks
4. Restart database
5. Verify recovery
6. Document findings
```

### Exercise 4: Kubernetes Deployment (30 min)
```
1. Deploy to K8s cluster
2. View all resources
3. Scale IVR deployment to 10 replicas
4. Monitor CPU/memory
5. Scale back down
```

---

## 📞 QUICK REFERENCE

### Essential Commands

```bash
# Check system status
docker-compose ps

# View logs
docker-compose logs -f ivr-1

# Connect to database
docker-compose exec postgres-primary psql -U cc_user -d safaricom_cc

# Check metrics
curl -s http://localhost:9090/api/v1/targets

# Cleanup
./deploy.sh cleanup local
```

### Access Points

```
Grafana:     http://localhost:3000  (admin/admin123)
Prometheus:  http://localhost:9090
Database:    localhost:5432  (cc_user/cc_password_secure)
IVR ESL:     localhost:8021
Load Bal:    http://localhost
Redis:       localhost:6379
```

---

## ✅ SUCCESS CHECKLIST

After deployment:
- [ ] All 7 containers running
- [ ] Grafana dashboard loaded
- [ ] Database accessible
- [ ] Sample data present
- [ ] Metrics collecting
- [ ] No errors in logs

---

## 🚀 NEXT STEPS

**Immediately:**
1. ✅ Deploy system locally
2. ✅ Verify all services running
3. ✅ Access Grafana dashboard

**Within 30 minutes:**
1. ✅ Read SETUP.md completely
2. ✅ Understand each component
3. ✅ Run some test commands

**Within 1 hour:**
1. ✅ Simulate call traffic
2. ✅ Monitor system performance
3. ✅ Create custom dashboard

**Extended:**
1. ✅ Deploy to Kubernetes
2. ✅ Deploy to AWS
3. ✅ Run advanced tests
4. ✅ Implement features

---

## 💪 YOU'RE READY!

This project teaches you:
- How to build real systems
- How to operate them
- How to monitor them
- How to scale them
- How to handle failures

**This is what senior engineers do.**

---

**Ready to start?**

```bash
cd /home/prophet/safaricom/CONTACT_CENTER_SPECIALIST_BOOTCAMP/LABS/BUILD_PROJECT
chmod +x deploy.sh
./deploy.sh local
```

**Let's build!** 🚀
