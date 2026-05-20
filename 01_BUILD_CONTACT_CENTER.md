# LAB 1: BUILD A CONTACT CENTER FROM SCRATCH
## End-to-End Architecture Design

**Difficulty:** Hard (Expert level)  
**Time:** 60 minutes  
**Format:** Design exercise (whiteboard or paper)

---

## 📋 SCENARIO

You're joining Safaricom as Senior Architect. Your assignment:

> "Build a new Contact Center to serve our Ethiopian customers. Requirements in 1 week. Implementation in 3 months. Budget: $1 million per year."

---

## 📊 REQUIREMENTS (Given)

**Business:**
- Expected users: 1 million customers (Ethiopia)
- Call volume: 100K calls per day initially, growing to 500K/day in 6 months
- Uptime requirement: 99.9% (8.7 hours downtime/year max)
- Revenue impact: 5-6M ETB per hour of downtime
- Budget: $1M per year (infrastructure only)

**Functional:**
- IVR (automated answering)
- Agent desktop (manual support)
- CRM integration (customer history)
- Billing integration (check balance, payments)
- Call recording (compliance)
- Reporting (metrics, analytics)

**Non-Functional:**
- Response time: <3 seconds to route to agent
- Concurrent calls: Assume 5% of daily volume at peak hour
  - 100K calls/day → 5,000 calls = ~416 concurrent
  - 500K calls/day → 25,000 calls = ~2,083 concurrent
- Scalability: Must handle 5x load surge (promotions, events)
- Security: Customer data protection, PCI compliance
- Compliance: Call recording, audit logs

---

## 🎯 YOUR TASK

Design a complete Contact Center system covering:

### 1. ARCHITECTURE DIAGRAM (What components?)
Draw/describe:
- Inbound call handling
- IVR system
- Call routing
- Agent desktop
- Backend systems (CRM, Billing, etc.)
- Data storage
- HA/DR components

### 2. TECHNOLOGY CHOICES (What products?)
Decide on:
- IVR platform (commercial? open source?)
- Call Manager (what software?)
- Agent desktop (web-based? desktop?)
- Database (MySQL? PostgreSQL?)
- Hosting (on-premises? cloud? hybrid?)
- Deployment (Kubernetes? VMs?)

### 3. CAPACITY PLANNING (How many servers?)
Calculate:
- IVR servers needed
- Call Manager servers
- Database sizing
- Storage for recordings
- Network bandwidth

### 4. HA/DR STRATEGY (How to prevent downtime?)
Plan for:
- Single points of failure
- Redundancy strategy
- Failover mechanism
- Disaster recovery
- RTO/RPO targets

### 5. COST ESTIMATION (Budget breakdown?)
Estimate:
- Infrastructure costs (servers, storage, network)
- Software licenses (IVR, call center platform)
- Personnel (ops, development)
- Network bandwidth
- Backup and DR

### 6. IMPLEMENTATION PLAN (How to build?)
Timeline:
- Week 1: Requirements gathering (DONE)
- Week 2-3: Architecture finalization
- Week 4-8: Infrastructure setup
- Week 9-12: Software installation and configuration
- Month 4-6: Testing, optimization, launch

### 7. MONITORING STRATEGY (How to know if it works?)
Define:
- Key metrics (ASA, AHT, FCR, error rate)
- Alerts (what triggers page to engineer?)
- Dashboard (what to visualize?)
- On-call procedures

---

## 📝 YOUR DESIGN PROCESS

**Time: 60 minutes**

### Phase 1: Gather & Clarify (10 min)
```
Questions to ask (out loud):
- Do we have existing infrastructure?
- What's the skill level of ops team?
- Is there budget flexibility?
- What's the timeline to MVP?
- How geographically distributed are customers?
- What's the capacity growth curve?
```

### Phase 2: Architecture Sketch (20 min)
```
Draw on paper/whiteboard:
- Customers → SBC → Load Balancer → [IVR1, IVR2, IVR3]
- Call Manager → [Agent1, Agent2, ..., Agent50]
- Database (Primary) ← Replication → Database (Backup)
- External APIs (CRM, Billing, Payment)
- Storage (Call recordings, logs)
- Monitoring (Prometheus, Grafana)
```

### Phase 3: Technology Selection (10 min)
```
Choose (with justification):
- IVR: FreeSWITCH or Avaya or Genesys?
  → FreeSWITCH: Open source (low cost), but need ops skills
  → Avaya: Proven, expensive, but reliable
  → Genesys: Most feature-rich, highest cost
- Call Manager: NICE inContact or Freshdesk?
- Database: MySQL or PostgreSQL?
- Hosting: AWS or on-premises?

Rationale: "Choose FreeSWITCH because cost is critical in budget-constrained Kenya market, 
we have ops expertise, and it's battle-tested in telecom"
```

### Phase 4: Capacity Estimation (10 min)
```
Calculate:
- Concurrent calls at peak: 416 → 2,083
- IVR throughput: ~100 calls/sec per server
  → Need at least 20-25 IVR servers for peak
- Database: ~50 concurrent connections per server
  → Need 3-4 database servers
- Call Manager: ~100 concurrent sessions per server
  → Need 20-25 call managers

Servers needed: ~50-60 for peak (add buffer for redundancy)
```

### Phase 5: HA/DR Planning (5 min)
```
Single points of failure:
- SBC down → 2x redundancy, load balancer failover
- IVR down → Distributed, 20+ servers (one fails, others handle)
- Call Manager down → Clustering, failover
- Database down → Master-slave replication, manual failover
- Network down → Dual ISP, failover

Disaster recovery:
- Kenya primary datacenter
- Uganda backup (cold standby)
- Daily backups to cloud (Amazon S3)
- RTO: 30 min (manual failover)
- RPO: 1 hour (up to 1 hour data loss)
```

### Phase 6: Cost Breakdown (3 min)
```
Annual budget: $1,000,000

Infrastructure:
├─ 60 servers @ $5K each/year: $300K
├─ Storage (recordings): $50K
├─ Network bandwidth: $100K
└─ Backup/cloud storage: $50K
Subtotal: $500K

Software:
├─ FreeSWITCH: Free (open source)
├─ Call center licenses: $150K
├─ Monitoring tools: $30K
└─ Database licenses: Free (PostgreSQL)
Subtotal: $180K

People:
├─ 2 ops engineers: $200K
├─ 1 database admin: $100K
└─ 1 development engineer: $20K (part-time)
Subtotal: $320K

TOTAL: ~$1,000K (fits budget!)
```

### Phase 7: Presentation (2 min)
```
"Here's my design:

ARCHITECTURE:
- SBC handles inbound, distributes to 25 IVR servers
- Each IVR can handle 100 calls/sec
- Call Manager clusters coordinate routing
- 50 agents across 3 zones
- Master-slave database (Kenya primary, Uganda backup)

TECH STACK:
- FreeSWITCH (IVR) - open source, proven
- Avaya / Genesys (Call Manager) - enterprise features
- PostgreSQL (database) - reliable, free
- AWS (backup/DR) - redundancy without capital

HA/DR:
- No single point of failure
- Multi-zone redundancy
- 30-minute failover to Uganda
- Daily backup to cloud

COST: $1M/year
- Infrastructure: $500K
- Software: $180K
- People: $320K

TIMELINE: 3 months
- Month 1: Procurement + setup
- Month 2: Configuration + integration
- Month 3: Testing + tuning + go-live
"
```

---

## ✅ DESIGN CHECKLIST

After completing your design, verify:

**Architecture:**
- [ ] All components identified
- [ ] Data flows are clear
- [ ] Integration points defined
- [ ] External APIs integrated (CRM, billing)

**HA/DR:**
- [ ] No single point of failure
- [ ] Redundancy strategy clear
- [ ] Failover procedures defined
- [ ] RTO/RPO targets set

**Capacity:**
- [ ] Peak load calculation correct
- [ ] Server count justified
- [ ] Database sizing reasonable
- [ ] Network bandwidth adequate

**Cost:**
- [ ] Within $1M budget
- [ ] Breakdown makes sense
- [ ] Includes redundancy costs
- [ ] Personnel costs realistic

**Scalability:**
- [ ] Handles 5x surge
- [ ] Auto-scaling planned
- [ ] Growth path defined
- [ ] No unexpected bottlenecks

**Monitoring:**
- [ ] Key metrics defined
- [ ] Alerts configured
- [ ] Dashboard designed
- [ ] On-call procedure clear

---

## 📚 MODEL DESIGN

See `01_BUILD_CONTACT_CENTER_SOLUTION.md` for detailed model answer including:
- Recommended architecture
- Technology justification
- Capacity calculations
- Cost breakdown
- Implementation timeline
- Monitoring strategy

---

## 🎯 SCORING RUBRIC

| Aspect | 1-3 (Weak) | 4-6 (Good) | 7-9 (Excellent) | 10 (Perfect) |
|--------|-----------|-----------|-----------------|--------------|
| **Architecture** | Missing components | Most components | All components, clear flow | Clear, detailed, justified |
| **Tech Choices** | No justification | Some reasoning | Good reasoning | Clear trade-offs analyzed |
| **Capacity** | Wrong calculations | Rough estimates | Good math | Detailed with growth plan |
| **HA/DR** | Missing | Basic redundancy | Comprehensive plan | Multi-zone, DRP tested |
| **Cost** | Way over/under | Rough estimate | Detailed breakdown | Justified, realistic |
| **Scalability** | Not addressed | Addressed | Plan included | Handles 10x with buffer |

**Total: __/60**

**Target: 45+ (75%) = Good design**  
**Target: 50+ (83%) = Excellent design**

---

## 💡 TIPS FOR SUCCESS

✅ **DO:**
- Ask clarifying questions (even if only in your head)
- Draw architecture diagrams (visual thinking)
- Write down assumptions
- Consider failure modes
- Think about costs and trade-offs
- Explain your reasoning

❌ **DON'T:**
- Skip HA/DR (it's critical)
- Over-engineer (you have budget constraints)
- Forget about operations (who runs this?)
- Ignore growth (must scale to 500K calls/day)
- Choose expensive when simple works
- Miss single points of failure

---

## 🚀 NEXT STEPS

1. **Complete this lab** (60 min of focused design)
2. **Compare with model answer** (15 min)
3. **Identify gaps** in your thinking
4. **Do Lab 4 (Incident Response)** - to handle crises
5. **Do Lab 10 (Disaster Recovery)** - to test what you built

---

**Ready? Grab paper, set timer for 60 min, and start designing!** 💪

This exercise alone is worth 1 hour of interview prep.
When you're done, you'll be thinking like a senior architect.
