-- SAFARICOM CONTACT CENTER - DATABASE SCHEMA
-- PostgreSQL 15+

-- ============================================
-- CUSTOMERS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id SERIAL PRIMARY KEY,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100),
    balance_etb DECIMAL(10,2) DEFAULT 0,
    data_plan VARCHAR(50),
    account_status VARCHAR(20) DEFAULT 'active', -- active, suspended, closed
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_call_date TIMESTAMP
);

-- Create indexes for fast lookup
CREATE INDEX idx_customers_phone ON customers(phone_number);
CREATE INDEX idx_customers_status ON customers(account_status);
CREATE INDEX idx_customers_created ON customers(created_at);

-- ============================================
-- AGENTS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS agents (
    agent_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    phone_extension VARCHAR(10),
    skill VARCHAR(50) NOT NULL, -- billing, technical, sales, support
    status VARCHAR(20) DEFAULT 'offline', -- available, busy, break, offline
    occupancy DECIMAL(3,2) DEFAULT 0, -- 0.0 to 1.0
    shift VARCHAR(20), -- morning, afternoon, night
    hire_date DATE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_agents_skill ON agents(skill);
CREATE INDEX idx_agents_status ON agents(status);
CREATE INDEX idx_agents_email ON agents(email);

-- ============================================
-- CALLS TABLE (grows rapidly)
-- ============================================

CREATE TABLE IF NOT EXISTS calls (
    call_id BIGSERIAL PRIMARY KEY,
    customer_id INTEGER REFERENCES customers(customer_id),
    agent_id INTEGER REFERENCES agents(agent_id),
    call_start TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    call_end TIMESTAMP,
    duration_seconds INTEGER,
    recording_url VARCHAR(500),
    recording_storage_path VARCHAR(500),
    call_outcome VARCHAR(50), -- resolved, transferred, callback, abandoned
    dtmf_input VARCHAR(100), -- keypresses from customer
    notes TEXT,
    satisfaction_score INTEGER, -- 1-5
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Important indexes for call queries
CREATE INDEX idx_calls_customer ON calls(customer_id);
CREATE INDEX idx_calls_agent ON calls(agent_id);
CREATE INDEX idx_calls_start ON calls(call_start);
CREATE INDEX idx_calls_date ON calls(DATE(call_start));

-- Partition by date (for large datasets)
-- This allows faster queries and easier archival
-- CREATE TABLE calls_2024_01 PARTITION OF calls
--     FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- ============================================
-- CALL RECORDINGS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS call_recordings (
    recording_id BIGSERIAL PRIMARY KEY,
    call_id BIGINT REFERENCES calls(call_id),
    storage_path VARCHAR(500) NOT NULL,
    bucket_name VARCHAR(100), -- S3 bucket
    file_size_mb DECIMAL(10,2),
    duration_seconds INTEGER,
    codec VARCHAR(20), -- opus, pcmu, etc
    bitrate_kbps INTEGER,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    deleted_at TIMESTAMP -- for soft deletes
);

CREATE INDEX idx_recordings_call ON call_recordings(call_id);
CREATE INDEX idx_recordings_created ON call_recordings(created_at);

-- ============================================
-- CALL HISTORY (customer context)
-- ============================================

CREATE TABLE IF NOT EXISTS call_history (
    history_id SERIAL PRIMARY KEY,
    customer_id INTEGER UNIQUE REFERENCES customers(customer_id),
    total_calls_lifetime INTEGER DEFAULT 0,
    total_calls_month INTEGER DEFAULT 0,
    total_calls_week INTEGER DEFAULT 0,
    avg_handle_time_seconds INTEGER,
    avg_satisfaction_score DECIMAL(3,2),
    last_call_date TIMESTAMP,
    last_agent_id INTEGER REFERENCES agents(agent_id),
    notes TEXT, -- agent notes about customer
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_history_customer ON call_history(customer_id);

-- ============================================
-- AGENT PERFORMANCE TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS agent_performance (
    performance_id SERIAL PRIMARY KEY,
    agent_id INTEGER REFERENCES agents(agent_id),
    date DATE NOT NULL DEFAULT CURRENT_DATE,
    calls_handled INTEGER DEFAULT 0,
    total_handle_time_seconds INTEGER DEFAULT 0,
    avg_handle_time_seconds DECIMAL(8,2),
    customer_satisfaction_avg DECIMAL(3,2),
    first_call_resolution_percent DECIMAL(5,2),
    occupancy_percent DECIMAL(5,2),
    break_time_seconds INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_performance_agent ON agent_performance(agent_id);
CREATE INDEX idx_performance_date ON agent_performance(date);
CREATE UNIQUE INDEX idx_performance_agent_date ON agent_performance(agent_id, date);

-- ============================================
-- IVR METRICS TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS ivr_metrics (
    metric_id BIGSERIAL PRIMARY KEY,
    timestamp TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    calls_received INTEGER DEFAULT 0,
    calls_completed INTEGER DEFAULT 0,
    calls_transferred INTEGER DEFAULT 0,
    calls_abandoned INTEGER DEFAULT 0,
    avg_speed_to_answer_seconds DECIMAL(6,2),
    avg_handle_time_seconds DECIMAL(6,2),
    queue_depth INTEGER DEFAULT 0,
    ivr_errors INTEGER DEFAULT 0,
    database_errors INTEGER DEFAULT 0
);

CREATE INDEX idx_metrics_timestamp ON ivr_metrics(timestamp);
CREATE INDEX idx_metrics_date ON ivr_metrics(DATE(timestamp));

-- ============================================
-- SYSTEM EVENTS TABLE (for auditing)
-- ============================================

CREATE TABLE IF NOT EXISTS system_events (
    event_id BIGSERIAL PRIMARY KEY,
    event_type VARCHAR(50), -- call_received, call_completed, error, alert, etc
    severity VARCHAR(20), -- info, warning, error, critical
    component VARCHAR(100), -- ivr, call_manager, database, etc
    message TEXT,
    details JSONB, -- flexible metadata
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX idx_events_type ON system_events(event_type);
CREATE INDEX idx_events_severity ON system_events(severity);
CREATE INDEX idx_events_timestamp ON system_events(created_at);
CREATE INDEX idx_events_component ON system_events(component);

-- ============================================
-- CONFIGURATION TABLE
-- ============================================

CREATE TABLE IF NOT EXISTS configuration (
    config_id SERIAL PRIMARY KEY,
    key VARCHAR(100) UNIQUE NOT NULL,
    value TEXT NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sample configurations
INSERT INTO configuration (key, value, description) VALUES
    ('ivr_timeout_seconds', '30', 'How long IVR waits for DTMF input'),
    ('max_queue_depth', '1000', 'Maximum calls in queue'),
    ('agent_occupancy_warning', '0.85', 'Alert if occupancy above this'),
    ('call_recording_retention_days', '365', 'How long to keep recordings'),
    ('database_connection_timeout', '10', 'DB connection timeout in seconds');

-- ============================================
-- VIEWS FOR EASY QUERYING
-- ============================================

-- Current system status
CREATE OR REPLACE VIEW v_system_status AS
SELECT
    (SELECT COUNT(*) FROM agents WHERE status = 'available') as available_agents,
    (SELECT COUNT(*) FROM agents WHERE status = 'busy') as busy_agents,
    (SELECT COUNT(*) FROM calls WHERE call_end IS NULL) as active_calls,
    (SELECT COUNT(*) FROM calls WHERE call_start > NOW() - INTERVAL '1 hour' AND call_end IS NOT NULL) as calls_last_hour,
    (SELECT AVG(duration_seconds) FROM calls WHERE call_start > NOW() - INTERVAL '1 hour') as avg_call_duration,
    (SELECT COUNT(*) FROM call_history) as total_customers;

-- Today's metrics
CREATE OR REPLACE VIEW v_daily_metrics AS
SELECT
    DATE(call_start) as call_date,
    COUNT(*) as total_calls,
    COUNT(CASE WHEN call_outcome = 'resolved' THEN 1 END) as resolved_calls,
    COUNT(CASE WHEN agent_id IS NOT NULL THEN 1 END) as agent_calls,
    AVG(EXTRACT(EPOCH FROM (call_end - call_start))) as avg_duration,
    AVG(satisfaction_score) as avg_satisfaction
FROM calls
GROUP BY DATE(call_start)
ORDER BY call_date DESC;

-- ============================================
-- FUNCTIONS
-- ============================================

-- Update customer last_call_date
CREATE OR REPLACE FUNCTION update_customer_last_call()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE customers
    SET last_call_date = NEW.call_end
    WHERE customer_id = NEW.customer_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger
DROP TRIGGER IF EXISTS trigger_update_customer_last_call ON calls;
CREATE TRIGGER trigger_update_customer_last_call
AFTER UPDATE OF call_end ON calls
FOR EACH ROW
EXECUTE FUNCTION update_customer_last_call();

-- ============================================
-- SAMPLE DATA
-- ============================================

-- Sample customers
INSERT INTO customers (phone_number, name, email, balance_etb, data_plan, account_status)
VALUES
    ('254722333001', 'Abebe Kebede', 'abebe@example.com', 250.00, '10GB/month', 'active'),
    ('254722333002', 'Fatima Ahmed', 'fatima@example.com', 150.50, '5GB/month', 'active'),
    ('254722333003', 'Samuel Tekle', 'samuel@example.com', 500.00, '20GB/month', 'active'),
    ('254722333004', 'Almaz Girma', 'almaz@example.com', 75.25, '2GB/month', 'active'),
    ('254722333005', 'Dawit Haile', 'dawit@example.com', 300.00, '15GB/month', 'active')
ON CONFLICT (phone_number) DO NOTHING;

-- Sample agents
INSERT INTO agents (name, email, phone_extension, skill, status, shift)
VALUES
    ('Agent Yohannes', 'yohannes@safaricom.local', '1001', 'billing', 'available', 'morning'),
    ('Agent Marta', 'marta@safaricom.local', '1002', 'technical', 'available', 'morning'),
    ('Agent Tewodros', 'tewodros@safaricom.local', '1003', 'support', 'break', 'afternoon'),
    ('Agent Selam', 'selam@safaricom.local', '1004', 'sales', 'busy', 'afternoon'),
    ('Agent Brhane', 'brhane@safaricom.local', '1005', 'billing', 'available', 'night')
ON CONFLICT (email) DO NOTHING;

-- ============================================
-- GRANTS (For security)
-- ============================================

-- User: cc_user (application user - read/write)
GRANT USAGE ON SCHEMA public TO cc_user;
GRANT ALL ON ALL TABLES IN SCHEMA public TO cc_user;
GRANT ALL ON ALL SEQUENCES IN SCHEMA public TO cc_user;

-- Create read-only user for reporting
CREATE USER cc_reporting WITH PASSWORD 'report_pass_secure';
GRANT USAGE ON SCHEMA public TO cc_reporting;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO cc_reporting;
GRANT SELECT ON ALL VIEWS IN SCHEMA public TO cc_reporting;

-- ============================================
-- READY TO USE
-- ============================================

-- Check installation
SELECT 'Tables created:' as status;
SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = 'public';
SELECT 'Sample data inserted' as status;
SELECT COUNT(*) as customer_count FROM customers;
SELECT COUNT(*) as agent_count FROM agents;
