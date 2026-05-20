# LAB 1: BUILD CONTACT CENTER - STEP BY STEP GUIDE
## Complete Implementation Roadmap

**Format:** Structured, detailed walkthrough  
**Time:** 120 minutes (2 hours)  
**Approach:** Build incrementally, verify each step  
**Outcome:** Production-ready architecture design

---

## 📋 PHASE 0: PROJECT INITIATION (15 minutes)

### Step 1.1: Create Project Charter
```
PROJECT: Safaricom Contact Center v1.0
├─ Objective: Launch new contact center for 1M customers
├─ Timeline: 3 months
├─ Budget: $1M/year
├─ Success Criteria:
│  ├─ 99.9% uptime (max 8.7 hrs downtime/year)
│  ├─ <3 sec call routing time
│  ├─ Support 100K calls/day initially
│  └─ Scale to 500K calls/day (6 months)
└─ Stakeholders: VP Ops, Engineering Lead, Finance
```

### Step 1.2: Requirements Kickoff Meeting (Simulate)
```
Questions to Ask & Answer:

1. SCALE QUESTIONS:
   Q: "How many calls per day initially?"
   A: "100K calls/day, peak 200K calls/hour"
   
   Q: "Growth projection?"
   A: "5x growth in 6 months (to 500K/day)"
   
   Q: "How many concurrent calls at peak?"
   A: Formula: 100K calls/day ÷ 24 hours ÷ 3600 sec × 5 min avg
      = 100,000 ÷ 86,400 × 300 = 347 concurrent (initial)
      = At 5x growth: 1,735 concurrent (future)

2. UPTIME QUESTIONS:
   Q: "What's the uptime requirement?"
   A: "99.9% = 8.7 hours downtime/year"
   
   Q: "What's the cost of downtime?"
   A: "5-6M ETB per hour (high criticality)"
   
   Q: "What's acceptable RTO/RPO?"
   A: "RTO: 30 min, RPO: 1 hour"

3. GEOGRAPHY:
   Q: "Where are customers?"
   A: "Ethiopia (Kenya secondary)"
   
   Q: "Where should we host?"
   A: "Primary: Kenya, DR: Uganda"

4. BUDGET:
   Q: "Can we go over $1M?"
   A: "No - hard budget constraint"
   
   Q: "What about ongoing costs?"
   A: "Included in $1M/year"

5. TECHNOLOGY:
   Q: "Any existing systems?"
   A: "Legacy on-prem IVR (retiring)"
   
   Q: "What's our ops skill level?"
   A: "Mid-level (can do Kubernetes, not Kafka)"
   
   Q: "Cloud or on-prem?"
   A: "Hybrid preferred (core DB on-prem, apps in cloud)"
```

### Step 1.3: Create Requirements Document
```
REQUIREMENTS SUMMARY:

Functional Requirements:
├─ IVR: Auto-answer calls, DTMF routing
├─ Call Manager: Route to agents based on skill
├─ Agent Desktop: Handle calls, access CRM
├─ CRM Integration: Show customer history
├─ Billing Integration: Check balance, deduct charges
├─ Payment: Collect payment during call
├─ Recording: Record all calls (compliance)
├─ Reporting: Real-time metrics, historical reports
└─ Monitoring: System health, alerting

Non-Functional Requirements:
├─ Performance: <3 sec to route, <100ms latency
├─ Availability: 99.9% uptime
├─ Scalability: 5x load capacity
├─ Security: Customer data protection, PCI compliance
├─ Compliance: Call recording, audit logs, data retention
├─ Capacity: 347 concurrent (initial), 1,735 (6 months)
└─ Growth: Gradual scaling, no surprises
```

---

## 🏗️ PHASE 1: ARCHITECTURE DESIGN (30 minutes)

### Step 2.1: Identify Core Components
```
Draw/describe the system:

INPUT LAYER (Calls come in)
├─ SBC (Session Border Controller)
│  └─ Handles incoming SIP calls
│  └─ Normalizes call format
│  └─ Rate limiting and security
└─ Load Balancer
   └─ Distributes calls to IVR instances

IVR LAYER (Automated answering)
├─ IVR Instance 1 (primary)
├─ IVR Instance 2 (backup)
├─ IVR Instance 3 (scale)
└─ Each can handle ~100 calls/sec

ROUTING LAYER (Skill-based routing)
├─ Call Manager (clustering)
├─ Queue Management (waiting calls)
└─ Skill Database (agent capabilities)

AGENT LAYER (Human handling)
├─ Agent Desktop (50 agents initial)
├─ Headsets (SIP/USB)
├─ CRM Integration (screen pop)
└─ Status: Available/Busy/Break

DATA LAYER (Storage)
├─ Customer Database (primary, on-prem)
├─ Database Backup (hot standby, on-prem)
├─ Call Recording Storage (cloud, S3)
├─ Call History Cache (Redis, for speed)
└─ Analytics (Elasticsearch)

BACKEND SERVICES (Integrations)
├─ CRM API (customer information)
├─ Billing API (balance, transactions)
├─ Payment API (collect payments)
├─ SMS API (send confirmations)
└─ Analytics API (metrics)

MONITORING & OPERATIONS
├─ Prometheus (metrics collection)
├─ Grafana (dashboards)
├─ ELK Stack (logs)
├─ PagerDuty (alerts)
└─ Custom monitoring scripts
```

### Step 2.2: Draw Architecture Diagram
```
                        CUSTOMERS (calls, SMS)
                              │
                              ↓
                    ┌─────────────────┐
                    │   SBC (Inbound) │
                    └────────┬────────┘
                             │
                      LOAD BALANCER
                      /      │      \
                     /       │       \
        ┌────────────────┐  ┌────────────────┐  ┌────────────────┐
        │   IVR Pod 1    │  │   IVR Pod 2    │  │   IVR Pod 3    │
        │ (Container)    │  │ (Container)    │  │ (Container)    │
        └────────────────┘  └────────────────┘  └────────────────┘
                     \       │       /
                      \      │      /
                      CALL MANAGER CLUSTER
                      /      │      \
            Agent 1-20   Agent 21-40  Agent 41-50
                          (Staffing)
                             │
                    ┌─────────┴──────────┐
                    │                    │
            ┌───────────────┐   ┌───────────────┐
            │ Customer DB   │   │ Call Recordings│
            │ (Primary)     │   │ (S3 Cloud)    │
            └───────────────┘   └───────────────┘
                    │
            ┌───────────────┐
            │ Customer DB   │
            │ (Backup)      │
            │ Replication   │
            └───────────────┘
                    
            EXTERNAL APIS
            ├─ CRM (customer info)
            ├─ Billing (balance)
            ├─ Payment (collect)
            └─ SMS (notify)
```

### Step 2.3: Identify Integration Points
```
Data Flows:

INBOUND CALL:
Call → SBC → Load Balancer → IVR
IVR: "Press 1 for billing, 2 for support"
↓
Customer presses 1 (DTMF)
↓
IVR queries: "SELECT balance FROM customers WHERE phone=...?"
↓
Database returns: 250 ETB
↓
IVR says: "Your balance is 250 ETB"
↓
IVR: "Press 1 to pay, 2 to talk to agent"
↓
If agent needed:
  ├─ Call Manager finds available agent (skill='billing')
  ├─ Call transferred to agent
  ├─ CRM shows customer history
  ├─ Agent handles call
  └─ Call recorded (PCAP/audio)
↓
Call ends
↓
Stats updated:
├─ Call history inserted
├─ Agent stats updated
├─ Recording stored in S3
└─ Metrics sent to Prometheus
```

---

## 💻 PHASE 2: TECHNOLOGY SELECTION (20 minutes)

### Step 3.1: Select IVR Platform
```
Option Analysis:

OPTION A: FreeSWITCH (Open Source)
├─ Cost: Free (OSS)
├─ Pros:
│  ├─ Full control (no vendor lock-in)
│  ├─ Highly customizable
│  ├─ Battle-tested in telecom
│  ├─ Strong community
│  └─ Can run on Kubernetes
├─ Cons:
│  ├─ Requires ops expertise
│  ├─ Limited support (community)
│  ├─ More configuration needed
│  └─ Smaller ecosystem
└─ Skill needed: Medium-High

OPTION B: Avaya (Commercial)
├─ Cost: $200K+/year license
├─ Pros:
│  ├─ Proven, enterprise-grade
│  ├─ Great support (Avaya)
│  ├─ Many features built-in
│  ├─ Easier implementation
│  └─ Integrations included
├─ Cons:
│  ├─ Expensive (eats budget)
│  ├─ Vendor lock-in
│  ├─ Less flexibility
│  └─ Slower innovation
└─ Skill needed: Medium

OPTION C: Genesys (Premium)
├─ Cost: $500K+/year license
├─ Pros:
│  ├─ Most feature-complete
│  ├─ Enterprise integrations
│  ├─ Best support
│  ├─ Cloud-native
│  └─ Advanced AI/analytics
├─ Cons:
│  ├─ Way over budget
│  ├─ Overkill for our needs
│  ├─ Heavy vendor lock-in
│  └─ Expensive ongoing
└─ Skill needed: Medium

RECOMMENDATION: FreeSWITCH
Rationale:
├─ Budget constraint ($1M/year total)
├─ Team has Kubernetes skills
├─ Flexibility important for customization
├─ Cost savings allow more infrastructure investment
└─ Open source better for Ethiopia market
```

### Step 3.2: Select Call Manager Platform
```
OPTION A: NICE inContact (Cloud)
├─ Cost: $150K/year
├─ Pros: Enterprise, scalable, cloud-native
├─ Cons: Expensive, vendor lock-in

OPTION B: Freshdesk (SMB)
├─ Cost: $50K/year
├─ Pros: Affordable, easy to use, integrations
├─ Cons: Limited for scale, less control

OPTION C: Custom (Build our own)
├─ Cost: $100K development + $50K/year ops
├─ Pros: Full control, customizable, learning
├─ Cons: Takes longer, needs expertise

RECOMMENDATION: Freshdesk + Custom Layer
Rationale:
├─ Freshdesk handles basic routing ($50K)
├─ Custom layer for advanced features
├─ Total ~$100K (fits budget)
├─ Can migrate to custom if needed
└─ Proven approach in telecom
```

### Step 3.3: Select Database
```
OPTION A: MySQL (Open Source)
├─ Cost: Free
├─ Pros: Reliable, standard, good performance
├─ Cons: Manual replication, limited clustering

OPTION B: PostgreSQL (Open Source)
├─ Cost: Free
├─ Pros: Better replication, JSONB, advanced features
├─ Cons: Slightly more complex than MySQL

OPTION C: Managed AWS RDS
├─ Cost: $20K/year
├─ Pros: AWS handles backups, replication, patching
├─ Cons: Less control, cloud vendor lock-in

RECOMMENDATION: PostgreSQL (Self-Managed)
Rationale:
├─ Better replication (built-in)
├─ Advanced features (if needed)
├─ Free (cost critical)
├─ Team familiar with PostgreSQL
└─ Can handle our scale
```

### Step 3.4: Hosting Decision
```
OPTION A: Pure On-Premises
├─ Cost: $500K infra + $300K ops = $800K
├─ Pros: Full control, low latency, compliance
├─ Cons: High capex, scaling difficult

OPTION B: Pure Cloud (AWS)
├─ Cost: $400K/year
├─ Pros: Easy scaling, managed services
├─ Cons: Latency for Kenya, data residency

OPTION C: Hybrid (Recommended)
├─ On-Prem:
│  ├─ Primary Database (Kenya DC)
│  ├─ Backup Database (Kenya DC)
│  └─ Local storage
│  └─ Cost: $300K
├─ Cloud (AWS):
│  ├─ IVR containers
│  ├─ Call Manager
│  ├─ Call recordings (S3)
│  ├─ Backups/DR
│  └─ Cost: $400K
├─ Network:
│  ├─ Fiber to AWS
│  └─ Cost: $300K
└─ Total: ~$1M/year ✓

RECOMMENDATION: Hybrid
Rationale:
├─ Low latency (DB on-prem in Kenya)
├─ Scalability (apps in cloud)
├─ Disaster recovery (backup in cloud)
├─ Cost effective (fits $1M budget)
└─ Best of both worlds
```

---

## 📊 PHASE 3: CAPACITY PLANNING (15 minutes)

### Step 4.1: Calculate Concurrent Load
```
INITIAL (Month 1):
├─ Daily calls: 100,000
├─ Average call duration: 5 minutes
├─ Peak hour: 2x average = 200,000 calls/hour
├─ Concurrent calls formula:
│  = (calls_per_hour ÷ 3600 sec) × call_duration_sec
│  = (200,000 ÷ 3600) × 300
│  = 55.55 × 300
│  = 16,667... WAIT, let me recalculate
│
│  Better formula:
│  = calls_per_day × call_duration_minutes ÷ 1440 min
│  = 100,000 × 5 ÷ 1440
│  = 500,000 ÷ 1440
│  = 347 concurrent calls (initial)
│
│  Peak hour (2x):
│  = 347 × 2 = 694 concurrent (peak)

FUTURE (Month 6, 5x growth):
├─ Daily calls: 500,000
├─ Concurrent: 347 × 5 = 1,735 concurrent (normal)
├─ Peak: 1,735 × 2 = 3,470 concurrent (peak)

BUFFER (20%):
├─ Initial: 694 × 1.2 = 833 concurrent
├─ Future: 3,470 × 1.2 = 4,164 concurrent
```

### Step 4.2: Size Each Component
```
IVR SERVERS:
├─ Throughput per server: ~100 calls/sec
├─ Initial load: 347 concurrent / 5 sec (avg duration) = 70 calls/sec
├─ Servers needed: 70 ÷ 100 = 0.7 → minimum 2 servers
├─ With buffer: 4 IVR servers (for reliability)
├─ Add growth capacity: 8 IVR servers for future

CALL MANAGER:
├─ Sessions per server: ~200 concurrent
├─ Initial: 347 concurrent ÷ 200 = 1.7 → 3 servers
├─ With buffer: 5 call manager servers
├─ Add growth: 10 servers future

DATABASE:
├─ Connections per server: ~100
├─ Initial: ~50 concurrent connections ÷ 100 = 0.5 → 1 primary
├─ Plus backup: 1 secondary (replication)
├─ With buffer: 2 database servers (1 primary, 1 backup)
├─ Storage: Call history grows ~100GB/month
│  └─ Need 1TB for 1 year + backups

AGENTS:
├─ Concurrent calls handled: 1 call per agent
├─ Initial: 347 concurrent ÷ occupancy(0.8) = 434 agents needed
│  Wait, that's wrong. Let me recalculate:
│  If 347 calls concurrent, and each call goes to 1 agent:
│  we need 347 agents... but that's if 100% go to agents
│
│  More realistic:
│  IVR handles 80% of calls (no agent needed)
│  Only 20% transferred to agents
│  So: 347 × 0.2 = 69 concurrent agent calls
│  With occupancy 0.8 (20% break time): 69 ÷ 0.8 = 86 agents needed
├─ Plan for initial: 50 agents (ramp up as needed)
├─ Staffing model: 3 shifts, 20 agents per shift
└─ Future: 400+ agents

STORAGE:
├─ Calls per day: 100,000
├─ Recording size per call: ~1MB average
├─ Daily storage: 100,000 × 1MB = 100GB/day
├─ Monthly: 3TB
├─ Yearly: 36TB + backups = 50TB needed
└─ S3 allocation: 100TB (with growth buffer)

NETWORK:
├─ Codec bandwidth per call: ~40Kbps (Opus codec)
├─ Peak concurrent: 694 calls
├─ Bandwidth needed: 694 × 40Kbps = 27.76 Mbps
├─ With overhead (50%): 40 Mbps
├─ Plan for: 100 Mbps fiber (allows growth)
└─ Backup: Secondary ISP (10Mbps)
```

### Step 4.3: Server List
```
PRODUCTION INFRASTRUCTURE:

Kenya Data Center (Primary):
├─ SBC Server: 1 × 4CPU, 8GB RAM
├─ Load Balancer: 1 × 2CPU, 4GB RAM
├─ IVR Servers: 4 × 4CPU, 8GB RAM each = 16CPU, 32GB
├─ Call Manager: 3 × 4CPU, 8GB RAM each = 12CPU, 24GB
├─ Primary Database: 1 × 8CPU, 32GB RAM
├─ Database Backup: 1 × 8CPU, 32GB RAM
├─ Monitoring: 1 × 4CPU, 8GB RAM
└─ Total Kenya: 48CPU, 132GB RAM, 7 servers

AWS Cloud (App layer):
├─ IVR Containers: 4 × 2CPU, 4GB each = 8CPU, 16GB
├─ Call Manager: 2 × 2CPU, 4GB each = 4CPU, 8GB
├─ Monitoring (Prometheus): 1 × 2CPU, 4GB
├─ Storage (S3): 100TB
└─ Total AWS: 14 EC2 instances

Uganda DC (DR Standby):
├─ Same as Kenya (cold standby)
└─ Activated only if Kenya fails

TOTAL SERVERS: 7 (Kenya) + 14 (AWS) + 7 (Uganda) = 28 servers
TOTAL CAPACITY: 48 + 14 + 48 = 110 CPUs, 264GB RAM
```

---

## 🏗️ PHASE 4: HA/DR STRATEGY (15 minutes)

### Step 5.1: Identify Single Points of Failure
```
Component Analysis:

SBC (Single Point?)
├─ RISK: If down, no calls accepted
├─ SOLUTION: Redundant SBCs (2 active-active)
├─ Cost: +1 server ($5K/year)

Load Balancer:
├─ RISK: If down, calls not routed
├─ SOLUTION: HA load balancer (AWS ALB, managed)
├─ Cost: Included in AWS

IVR Servers:
├─ RISK: If all 4 fail, no IVR
├─ SOLUTION: Auto-restart + health checks
├─ Also: Distributed (if 1 fails, others handle)
├─ Cost: Included in container platform

Call Manager:
├─ RISK: If cluster fails, no routing
├─ SOLUTION: Clustering (active-active)
├─ Cost: Already in design

Database (PRIMARY FAILURE):
├─ RISK: If primary fails, cannot write data
├─ SOLUTION: Master-slave replication
│  ├─ Primary (writable)
│  ├─ Secondary (read-only, auto-failover)
│  └─ Manual: Promote secondary to primary
├─ RTO: 5-10 minutes (manual)
├─ Cost: 1 extra server ($8K/year)

Network:
├─ RISK: Single ISP fails
├─ SOLUTION: Dual ISP + failover
├─ Cost: Secondary ISP ($24K/year)

Data Center (WHOLE DC FAILURE):
├─ RISK: Kenya DC destroyed
├─ SOLUTION: DR in Uganda
│  ├─ Database replicated (read-only)
│  ├─ App servers in standby
│  ├─ Manual failover: 30 minutes
│  └─ RPO: 1 hour (data loss acceptable)
├─ RTO: 30 min
└─ Cost: Uganda servers ($50K/year)
```

### Step 5.2: HA Architecture
```
                    CUSTOMERS (calls)
                          │
                    ┌─────┴─────┐
                    │           │
              ┌──────────┐  ┌──────────┐
              │ SBC #1   │  │ SBC #2   │
              └──────────┘  └──────────┘
                    │           │
                    └─────┬─────┘
                    LOAD BALANCER (AWS)
                    /      │       \
        ┌────────────┐ ┌────────────┐ ┌────────────┐
        │ IVR Pod 1  │ │ IVR Pod 2  │ │ IVR Pod 3  │
        └────────────┘ └────────────┘ └────────────┘
              │
        CALL MANAGER CLUSTER
        /         │         \
    Agent      Agent      Agent
    Group1     Group2     Group3

DATABASE HA:
┌─────────────────┐    Replication    ┌──────────────────┐
│ Primary DB      │ ─────────────→   │ Secondary DB     │
│ (Writable)      │                  │ (Read-only)      │
│ Kenya DC        │                  │ Kenya DC         │
└─────────────────┘                  └──────────────────┘
        ▲
        │ Failover (manual, 5-10 min)
        │ Promote secondary to primary
        └─ If primary dies

DR LAYER:
┌─────────────────┐
│ Uganda DC       │
│ Cold Standby    │
│ (Manual activation)
│ 30-min failover │
└─────────────────┘
```

### Step 5.3: Failover Procedures
```
SCENARIO 1: IVR Server Fails
├─ Detection: Health check fails (10 sec)
├─ Action: Auto-restart pod on another node
├─ Time to recovery: <30 seconds
├─ Impact: Minimal (other IVRs handle load)

SCENARIO 2: Primary Database Fails
├─ Detection: Connection fails, monitoring alert
├─ Action: Manual:
│  ├─ Stop primary (ensure it's really dead)
│  ├─ Promote secondary: PROMOTE SLAVE TO PRIMARY
│  ├─ Update connection strings
│  ├─ Verify replication halted
│  └─ Alert team
├─ Time to recovery: 5-10 minutes
├─ Impact: Customers may see brief delays
├─ Data loss: None (already replicated)

SCENARIO 3: Entire Kenya DC Fails
├─ Detection: Multiple services down
├─ Decision: Activate DR
├─ Action:
│  ├─ Verify Kenya is really down (not network issue)
│  ├─ Spin up Uganda cluster:
│  │  ├─ Activate IVR containers
│  │  ├─ Activate call manager
│  │  ├─ Activate monitoring
│  │  └─ Estimated time: 20 minutes
│  ├─ Promote Uganda database to primary
│  ├─ Update DNS to Uganda
│  ├─ Update calls routing to Uganda
│  └─ Resume operations
├─ Time to recovery: 30 minutes
├─ Impact: Brief service interruption
├─ Data loss: Up to 1 hour (last backup)

COMMUNICATION:
├─ Incident declared: All stakeholders notified
├─ Updates: Every 5 minutes
├─ Resolution: When service restored
└─ RCA: Within 24 hours
```

---

## 💰 PHASE 5: COST BREAKDOWN (10 minutes)

### Step 6.1: Infrastructure Costs
```
ANNUAL COST BREAKDOWN:

KENYA DATA CENTER (On-Prem):
├─ Servers (7 × $30K): $210K
├─ Network equipment: $20K
├─ Datacenter power: $30K
├─ Cooling: $10K
├─ Rack space: $20K
├─ Network (fiber): $100K
└─ Subtotal Kenya: $390K

AWS (Cloud):
├─ EC2 (14 instances × $300/month): $50K
├─ S3 Storage (100TB × $0.02/GB): $20K
├─ Data transfer (inter-region): $10K
├─ Monitoring tools (CloudWatch): $5K
└─ Subtotal AWS: $85K

Uganda DR (Cold Standby):
├─ Servers (similar to Kenya): $300K/year (inactive)
│  └─ Estimated (shared cost)
├─ Network: $50K
└─ Subtotal Uganda: $350K (shared, not fully allocated)

TOTAL INFRASTRUCTURE: ~$500K/year
```

### Step 6.2: Software Costs
```
SOFTWARE LICENSES:

FreeSWITCH: Free (open source)
Freshdesk: $50K/year (call center)
PostgreSQL: Free (open source)
Linux: Free (CentOS)
Kubernetes: Free (open source)
Prometheus/Grafana: Free (open source)
ELK Stack: Free (open source)

Additional:
├─ SSL Certificates: $2K
├─ Monitoring tools (cloud): $5K
├─ Backup software: $3K
└─ Subtotal Software: $60K
```

### Step 6.3: Personnel Costs
```
OPERATIONS TEAM:

Full-time:
├─ Lead DevOps Engineer: $80K/year
├─ 2 × SRE Engineers: $120K/year
├─ 1 × Database Admin: $60K/year
├─ 1 × Network Engineer: $70K/year
└─ Subtotal FTE: $330K

Contract/Part-time:
├─ On-call rotation: $40K/year
├─ Security consultant: $30K/year
└─ Subtotal Contract: $70K

TOTAL PERSONNEL: $400K/year
```

### Step 6.4: Final Budget
```
TOTAL ANNUAL COST BREAKDOWN:

Infrastructure:     $500K
├─ Kenya DC: $390K
├─ AWS: $85K
└─ Network/shared: $25K

Software:           $60K
├─ Freshdesk: $50K
└─ Tools/licenses: $10K

Personnel:          $400K
├─ FTE: $330K
└─ Contract: $70K

Reserve (5%):       $48K
└─ Contingency, tools, training

TOTAL:              $1,008K (~$1M) ✓

Within Budget!
```

---

## 📅 PHASE 6: IMPLEMENTATION TIMELINE (10 minutes)

### Step 7.1: Project Phases
```
MONTH 1: PROCUREMENT & SETUP
├─ Week 1: Infrastructure procurement
│  ├─ Order 7 Kenya servers
│  ├─ Order AWS instances
│  ├─ Order network equipment
│  └─ Order SBC hardware
├─ Week 2: Datacenter setup
│  ├─ Rack servers in Kenya DC
│  ├─ Install network cabling
│  ├─ Configure power/cooling
│  └─ Initial health checks
├─ Week 3: OS installation
│  ├─ Install Linux (CentOS 8)
│  ├─ Configure networking
│  ├─ Install Kubernetes
│  └─ Set up monitoring infrastructure
├─ Week 4: Database setup
│  ├─ Install PostgreSQL (primary)
│  ├─ Install PostgreSQL (backup)
│  ├─ Configure replication
│  └─ Test failover
└─ Milestone: Infrastructure ready

MONTH 2: APPLICATION DEPLOYMENT
├─ Week 1: FreeSWITCH setup
│  ├─ Install FreeSWITCH (4 instances)
│  ├─ Configure dial plan
│  ├─ Configure DTMF routing
│  └─ Load test: 100 concurrent calls
├─ Week 2: Call Manager setup
│  ├─ Deploy Freshdesk
│  ├─ Configure call routing
│  ├─ Set up skill-based routing
│  └─ Test: 50 concurrent calls
├─ Week 3: Integration
│  ├─ Connect IVR to Database
│  ├─ Connect to CRM API
│  ├─ Connect to Billing API
│  ├─ Connect to Payment API
│  └─ Integration testing
├─ Week 4: Agent desktop
│  ├─ Set up 50 agent workstations
│  ├─ Configure SIP endpoints
│  ├─ Install agent software
│  └─ User acceptance testing
└─ Milestone: Applications deployed

MONTH 3: TESTING & OPTIMIZATION
├─ Week 1: Load testing
│  ├─ Run load tests: 347 concurrent calls
│  ├─ Run tests: 694 concurrent (peak)
│  ├─ Stress test: 1000 concurrent
│  ├─ Identify bottlenecks
│  └─ Optimize
├─ Week 2: Reliability testing
│  ├─ Failover testing (servers)
│  ├─ Database failover test
│  ├─ Network failure simulation
│  └─ Disaster recovery drill
├─ Week 3: Security & compliance
│  ├─ Penetration testing
│  ├─ Vulnerability scan
│  ├─ Data protection review
│  └─ Audit log verification
├─ Week 4: Production launch
│  ├─ Migration from legacy IVR
│  ├─ Parallel run (both systems)
│  ├─ Cutover to new system
│  ├─ 24/7 monitoring
│  └─ Post-launch support
└─ Milestone: Go live!

MONTH 4-6: OPTIMIZATION & GROWTH
├─ Scale IVR: 4 → 8 servers
├─ Scale Call Manager: 3 → 6 servers
├─ Scale Agents: 50 → 200+
├─ Grow storage: 100TB → 500TB
└─ Achieve 500K calls/day capacity
```

### Step 7.2: Gantt Chart (Text)
```
Task                    M1  M2  M3  M4  M5  M6
────────────────────────────────────────────────
Procurement             ███
Infrastructure          ███ ██
OS Installation             ██
Database Setup              ██ █
FreeSWITCH              ────██
Call Manager            ────██
Integration             ────██
Agent Setup             ────███
Load Testing                ───███
Failover Testing            ───██
Security Testing            ───██
Launch                      ──███
Growth Phase                    ███████
```

---

## 📊 PHASE 7: MONITORING & OPERATIONS (10 minutes)

### Step 8.1: Key Metrics
```
OPERATIONAL METRICS:

Call Metrics:
├─ Calls per day: 100K → 500K
├─ Concurrent calls: 347 → 1,735
├─ Average handle time (AHT): 5 min
├─ Speed to answer (ASA): <30 sec
├─ First call resolution (FCR): >80%
└─ Customer satisfaction (NPS): >50

System Metrics:
├─ IVR availability: >99.9%
├─ Call Manager uptime: >99.9%
├─ Database availability: >99.99%
├─ Network latency: <100ms
└─ Call setup time: <3 sec

Infrastructure Metrics:
├─ CPU utilization: <70% (normal), <80% (alert)
├─ Memory usage: <80%
├─ Disk usage: <80%
├─ Network utilization: <60%
└─ Storage growth: Monitor monthly
```

### Step 8.2: Alerting Rules
```
ALERT THRESHOLDS:

Page Engineer Immediately:
├─ Any service down: 0 min
├─ Error rate > 5%: 2 min
├─ Database not responding: 1 min
├─ IVR latency > 5 sec: 1 min
├─ Call queue > 100: 5 min
└─ Disk full < 10%: 5 min

Send to Ops (non-urgent):
├─ CPU > 80%: 10 min
├─ Memory > 85%: 10 min
├─ Network latency > 200ms: 10 min
├─ Slow database query: 1 min
└─ Agent occupancy > 90%: 10 min

Dashboard Alerts (visibility):
├─ Calls/sec graph
├─ Agent availability
├─ Queue depth
├─ System health
└─ Revenue running total
```

### Step 8.3: On-Call Procedures
```
ON-CALL ROTATION:

Team:
├─ Primary on-call: 1 person (full week)
├─ Secondary on-call: 1 person (backup)
├─ Management escalation: Available 24/7
└─ Rotation: Every week, Monday 9am

Response Times:
├─ Severity 1 (outage): 15 min
├─ Severity 2 (degraded): 30 min
├─ Severity 3 (minor): 2 hours
└─ Severity 4 (cosmetic): Next business day

Escalation:
├─ On-call not responding: 10 min → escalate to manager
├─ Manager can't fix: 30 min → escalate to VP Ops
├─ Still broken: 60 min → declare major incident
└─ Post-incident: RCA within 24 hours
```

---

## ✅ FINAL CHECKLIST

**Architecture Complete:**
- [ ] All components identified
- [ ] Integration points defined
- [ ] Data flows documented
- [ ] Diagram created

**Technology Selected:**
- [ ] IVR: FreeSWITCH ✓
- [ ] Call Manager: Freshdesk ✓
- [ ] Database: PostgreSQL ✓
- [ ] Hosting: Hybrid (on-prem + AWS) ✓

**Capacity Verified:**
- [ ] Concurrent load calculated: 347 → 1,735 ✓
- [ ] Servers sized: 28 servers total ✓
- [ ] Storage planned: 100TB + growth ✓
- [ ] Network planned: 100Mbps ✓

**HA/DR Designed:**
- [ ] Single points of failure identified ✓
- [ ] Redundancy strategy defined ✓
- [ ] RTO/RPO targets set (30 min / 1 hour) ✓
- [ ] Failover procedures documented ✓

**Budget Approved:**
- [ ] Total cost: $1,008K/year ✓
- [ ] Breakdown: Infra ($500K) + SW ($60K) + Personnel ($400K) ✓
- [ ] Contingency included (5%) ✓
- [ ] Within budget constraint ✓

**Timeline Created:**
- [ ] Month 1: Procurement ✓
- [ ] Month 2: Deployment ✓
- [ ] Month 3: Testing ✓
- [ ] Month 4-6: Growth ✓

**Monitoring Planned:**
- [ ] Key metrics defined ✓
- [ ] Alert thresholds set ✓
- [ ] On-call procedures documented ✓
- [ ] Dashboard planned ✓

---

## 🎯 NEXT STEPS

**This architecture is:**
- ✅ Production-ready
- ✅ Scalable to 500K calls/day
- ✅ Highly available (99.9%+)
- ✅ Disaster resilient (30-min failover)
- ✅ Cost-effective ($1M/year budget)
- ✅ Operationally sound

**To implement:**
1. Present to stakeholders (VP Ops, Finance)
2. Get approval & budget
3. Form implementation team
4. Follow 3-month timeline
5. Go live!

---

**Congratulations! You've designed a production contact center from scratch.** 🚀

This is exactly what senior architects do. Well done!
