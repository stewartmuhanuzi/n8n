# Deployment Guide

## Overview

This guide covers the complete deployment process for the n8n Shopify Integration Library, from initial setup to production deployment and multi-tenant scaling.

## Prerequisites

### Required Systems
- **n8n Platform** (Self-hosted or Cloud)
- **PostgreSQL Database** (Supabase recommended)
- **Redis** (Optional, for caching and session management)
- **SSL Certificate** (For webhook security)

### Required Access
- **Shopify Admin API** access token
- **Database administration** permissions
- **n8n workflow administration** access
- **Domain management** (for webhooks)

## Phase 1: Database Setup

### 1.1 Database Schema Deployment

**Option A: Using Supabase Dashboard**
```bash
# 1. Create new Supabase project
# 2. Go to SQL Editor
# 3. Run each migration file in order:
```

Migration order:
1. `0001_shopify_products.sql` ✅ (existing)
2. `0002_shopify_product_variants.sql` ✅ (existing)
3. `0003_orders.sql` 🆕
4. `0004_order_lines.sql` 🆕
5. `0005_sync_log.sql` 🆕
6. `0006_shopify_orders_raw.sql` 🆕
7. `0007_shopify_products_raw.sql` 🆕
8. `0008_integration_logs.sql` 🆕

**Option B: Using Supabase CLI**
```bash
# Install Supabase CLI
brew install supabase/tap/supabase

# Initialize project
supabase init

# Link to your project
supabase link --project-ref your-project-ref

# Apply all migrations
supabase db push
```

### 1.2 Verify Database Setup

```sql
-- Check all tables exist
SELECT table_name, table_schema
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name LIKE '%shopify%'
  OR table_name LIKE '%order%'
  OR table_name LIKE '%sync%'
  OR table_name LIKE '%integration%'
ORDER BY table_name;

-- Verify indexes
SELECT indexname, indexdef
FROM pg_indexes
WHERE schemaname = 'public'
  AND tablename IN ('shopify_orders_raw', 'shopify_products_raw', 'integration_logs');
```

## Phase 2: Environment Configuration

### 2.1 Environment Variables Setup

**Step 1: Copy the template**
```bash
# For local development
cp config/env.template .env

# For production deployment
cp config/env.template /etc/environment.d/n8n-shopify.conf
```

**Step 2: Configure required variables**

```bash
# Core Configuration
MERCHANT_ID=your-merchant-identifier
SHOP_IDENTIFIER=your-shop-name
SHOPIFY_ADMIN=your-shop-name
SHOPIFY_ACCESS_TOKEN=shpat_your_token_here

# Database Configuration
SUPABASE_HOST=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key

# Monitoring & Notifications
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/your/webhook

# Sync Configuration
SYNC_INTERVAL_MINUTES=15
SYNC_LOOKBACK_HOURS=1
SYNC_BUSINESS_HOURS_START=8
SYNC_BUSINESS_HOURS_END=18
API_BATCH_SIZE=250

# Security
SHOPIFY_WEBHOOK_SECRET=your_webhook_secret
ENABLE_WEBHOOK_VERIFICATION=true
```

### 2.2 Shopify App Setup

**1. Create Shopify App**
```bash
# In Shopify Admin:
# 1. Go to Apps → Develop apps
# 2. Create new app
# 3. Configure Admin API access scopes:
#    - read_orders
#    - read_products
#    - read_inventory
#    - read_customers
#    - read_fulfillments
#    - read_checkouts
```

**2. Configure Webhooks**
```bash
# Webhook endpoints (if using webhooks):
https://your-n8n-domain.com/webhook/shopify/orders
https://your-n8n-domain.com/webhook/shopify/products

# Events to subscribe to:
# - orders/create
# - orders/updated
# - orders/cancelled
# - products/create
# - products/update
```

## Phase 3: n8n Workflow Deployment

### 3.1 Import Workflows

**Option A: n8n UI Import**
```bash
# 1. Open n8n interface
# 2. Click "Import from file" or "Import from URL"
# 3. Import each workflow in dependency order:

# Import Order:
1. flows/shopify/shared/sync-orchestrator.json
2. flows/shopify/orders/shopify-orders-fetch.json
3. flows/shopify/orders/orders-transform.json

# Import Products:
4. flows/shopify/products/shopify-products-fetch.json
5. flows/shopify/products/products-transform.json
```

**Option B: n8n CLI Import**
```bash
# Install n8n CLI
npm install n8n -g

# Import workflows
n8n import:file --file=flows/shopify/shared/sync-orchestrator.json
n8n import:file --file=flows/shopify/orders/shopify-orders-fetch.json
n8n import:file --file=flows/shopify/orders/orders-transform.json
n8n import:file --file=flows/shopify/products/shopify-products-fetch.json
n8n import:file --file=flows/shopify/products/products-transform.json
```

### 3.2 Configure n8n Credentials

**1. Shopify API Credential**
```json
{
  "name": "Shopify API - Production",
  "type": "headerAuth",
  "data": {
    "name": "X-Shopify-Access-Token",
    "value": "{{ $vars.SHOPIFY_ACCESS_TOKEN }}"
  }
}
```

**2. Supabase Credential**
```json
{
  "name": "Supabase Service Role",
  "type": "headerAuth",
  "data": {
    "name": "apikey",
    "value": "{{ $vars.SUPABASE_SERVICE_ROLE_KEY }}"
  }
}
```

**3. Slack Webhook Credential**
```json
{
  "name": "Slack Notifications",
  "type": "headerAuth",
  "data": {
    "name": "Content-Type",
    "value": "application/json"
  }
}
```

### 3.3 Workflow Configuration

**For each workflow:**
1. **Set environment variables** in workflow settings
2. **Configure credentials** for HTTP Request nodes
3. **Set webhook URLs** (if using webhooks)
4. **Configure triggers** (cron schedules)
5. **Set error handling** preferences

## Phase 4: Testing & Validation

### 4.1 Component Testing

**Test 1: Orders Fetch**
```bash
# 1. Open shopify-orders-fetch workflow
# 2. Use Manual Trigger node
# 3. Execute and check:
#    - No errors in execution log
#    - Data appears in shopify_orders_raw table
#    - Records marked as unprocessed

-- Verify in database
SELECT COUNT(*) as raw_orders,
       COUNT(CASE WHEN processed = true THEN 1 END) as processed
FROM shopify_orders_raw
WHERE received_at > NOW() - INTERVAL '1 hour';
```

**Test 2: Orders Transform**
```bash
# 1. Open orders-transform workflow
# 2. Use Manual Trigger node
# 3. Execute and check:
#    - Raw records get processed flag set to true
#    - Data appears in orders table
#    - Data appears in order_lines table
#    - integration_logs show success

-- Verify in database
SELECT COUNT(*) as orders,
       COUNT(CASE WHEN processed = true THEN 1 END) as processed_orders
FROM shopify_orders_raw
WHERE received_at > NOW() - INTERVAL '1 hour';

SELECT COUNT(*) as normalized_orders
FROM orders
WHERE created_at > NOW() - INTERVAL '1 hour';
```

**Test 3: Full Orchestrated Sync**
```bash
# 1. Open sync-orchestrator workflow
# 2. Use Manual Sync Trigger
# 3. Monitor execution:
#    - All components execute in order
#    - No critical errors
#    - Slack notification received
#    - integration_logs show complete success
```

### 4.2 Integration Testing

**API Connection Test**
```bash
# Test Shopify API access
curl -X GET "https://{{SHOP_IDENTIFIER}}.myshopify.com/admin/api/2023-10/orders.json?limit=1" \
  -H "X-Shopify-Access-Token: {{SHOPIFY_ACCESS_TOKEN}}"
```

**Database Connection Test**
```bash
# Test Supabase connection
curl -X GET "{{SUPABASE_HOST}}/rest/v1/orders?limit=1" \
  -H "apikey: {{SUPABASE_SERVICE_ROLE_KEY}}" \
  -H "Authorization: Bearer {{SUPABASE_SERVICE_ROLE_KEY}}"
```

### 4.3 Performance Testing

**Load Test**
```bash
# Configure test with larger dataset
API_BATCH_SIZE=50
SYNC_LOOKBACK_HOURS=24

# Monitor execution time
# Target: < 5 minutes for 1000 orders
# Target: < 2 minutes for 500 products
```

## Phase 5: Production Deployment

### 5.1 Pre-Production Checklist

- [ ] All database migrations applied successfully
- [ ] Environment variables configured and validated
- [ ] n8n credentials set up correctly
- [ ] Individual workflow components tested
- [ ] Full orchestrated sync tested
- [ ] Error handling verified
- [ ] Monitoring and alerts configured
- [ ] Backup procedures in place
- [ ] Rollback plan documented

### 5.2 Go Live Procedure

**Step 1: Deactivate Legacy System**
```bash
# If you have the original monolithic workflow:
# 1. Open original n8n.json workflow
# 2. Deactivate all triggers
# 3. Keep for rollback if needed
```

**Step 2: Activate New System**
```bash
# 1. Open sync-orchestrator workflow
# 2. Enable cron trigger
# 3. Set schedule: "*/15 * * * *" (every 15 minutes)
# 4. Activate workflow
```

**Step 3: Monitor Initial Runs**
```bash
# Monitor first few automated runs:
# 1. Check execution logs
# 2. Verify database records
# 3. Confirm notifications working
# 4. Watch for error patterns

-- Monitor sync status
SELECT
  flow_name,
  status,
  COUNT(*) as executions,
  MAX(created_at) as last_execution
FROM integration_logs
WHERE created_at > NOW() - INTERVAL '2 hours'
GROUP BY flow_name, status
ORDER BY last_execution DESC;
```

### 5.3 Production Monitoring

**Key Metrics to Monitor**
```sql
-- Sync Health Dashboard
SELECT
  DATE_TRUNC('hour', created_at) as hour,
  COUNT(*) as total_executions,
  COUNT(CASE WHEN status = 'success' THEN 1 END) as successful,
  COUNT(CASE WHEN status = 'failed' THEN 1 END) as failed,
  AVG(duration_ms) as avg_duration_ms,
  SUM(records_total) as total_records_processed
FROM integration_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY DATE_TRUNC('hour', created_at)
ORDER BY hour DESC;

-- Data Volume Check
SELECT
  'raw_orders' as table_name, COUNT(*) as record_count, MAX(received_at) as latest
FROM shopify_orders_raw
UNION ALL
SELECT
  'orders' as table_name, COUNT(*) as record_count, MAX(created_at) as latest
FROM orders
UNION ALL
SELECT
  'raw_products' as table_name, COUNT(*) as record_count, MAX(received_at) as latest
FROM shopify_products_raw
UNION ALL
SELECT
  'products' as table_name, COUNT(*) as record_count, MAX(created_at) as latest
FROM products;
```

## Phase 6: Multi-Tenant Deployment

### 6.1 Schema-per-Tenant Setup

**Create Tenant Schemas**
```sql
-- Create schema for each tenant
CREATE SCHEMA tenant_001;
CREATE SCHEMA tenant_002;

-- Create tables in tenant schemas
CREATE TABLE tenant_001.shopify_orders (
    LIKE public.shopify_orders INCLUDING ALL
);

-- Grant permissions
CREATE USER tenant_001_user WITH PASSWORD 'secure_password';
GRANT USAGE ON SCHEMA tenant_001 TO tenant_001_user;
GRANT ALL ON ALL TABLES IN SCHEMA tenant_001 TO tenant_001_user;
```

### 6.2 Multi-Tenant Configuration

**Environment Variables per Tenant**
```bash
# Tenant 001
TENANT_001_ID=merchant-abc
TENANT_001_SHOPIFY_ADMIN=store-abc
TENANT_001_SHOPIFY_TOKEN=token-abc
TENANT_001_DATABASE_SCHEMA=tenant_001

# Tenant 002
TENANT_002_ID=merchant-xyz
TENANT_002_SHOPIFY_ADMIN=store-xyz
TENANT_002_SHOPIFY_TOKEN=token-xyz
TENANT_002_DATABASE_SCHEMA=tenant_002
```

**Tenant-Specific Workflows**
```bash
# Duplicate workflows for each tenant:
# - sync-orchestrator-tenant-001.json
# - shopify-orders-fetch-tenant-001.json
# - etc.

# Or use parameterized workflows with tenant routing
```

## Phase 7: Webhook Deployment (Optional)

### 7.1 Webhook Configuration

**Set up Webhook Endpoints**
```bash
# n8n webhook endpoints:
https://your-n8n-domain.com/webhook/shopify/orders/create
https://your-n8n-domain.com/webhook/shopify/orders/update
https://your-n8n-domain.com/webhook/shopify/products/create
```

**Configure Shopify Webhooks**
```bash
# In Shopify Admin → Apps → Your App → Webhooks:
# 1. Add webhook for each event type
# 2. Set endpoint URL
# 3. Set Webhook API version: 2023-10
# 4. Configure delivery settings
```

### 7.2 Webhook Security

**HMAC Verification**
```javascript
// In webhook processing workflow:
function verifyShopifyWebhook(body, hmacHeader) {
    const crypto = require('crypto');
    const secret = $vars.SHOPIFY_WEBHOOK_SECRET;

    const calculatedHmac = crypto
        .createHmac('sha256', secret)
        .update(body, 'utf8')
        .digest('base64');

    return crypto.timingSafeEqual(
        Buffer.from(calculatedHmac),
        Buffer.from(hmacHeader)
    );
}
```

## Troubleshooting Guide

### Common Issues & Solutions

**Issue 1: Database Connection Failed**
```bash
# Symptoms: "Connection refused" or "Authentication failed"
# Solutions:
# 1. Verify SUPABASE_HOST and SUPABASE_SERVICE_ROLE_KEY
# 2. Check network connectivity
# 3. Verify database is running
# 4. Check IP whitelist in Supabase
```

**Issue 2: Shopify API Rate Limits**
```bash
# Symptoms: "429 Too Many Requests"
# Solutions:
# 1. Reduce API_BATCH_SIZE
# 2. Increase SYNC_INTERVAL_MINUTES
# 3. Check for duplicate workflows running
# 4. Implement better rate limiting
```

**Issue 3: Missing Database Tables**
```bash
# Symptoms: "relation does not exist" errors
# Solutions:
# 1. Run all database migrations in order
# 2. Check migration logs for errors
# 3. Verify database permissions
# 4. Check for naming conflicts
```

**Issue 4: Environment Variables Not Loading**
```bash
# Symptoms: "undefined" values in workflows
# Solutions:
# 1. Verify .env file location and format
# 2. Check n8n restart required
# 3. Verify variable names match exactly
# 4. Check for special characters in values
```

**Issue 5: Webhook Not Triggering**
```bash
# Symptoms: No data from webhooks
# Solutions:
# 1. Verify webhook URL is accessible
# 2. Check SSL certificate validity
# 3. Verify webhook secret matches
# 4. Check Shopify webhook delivery logs
```

## Maintenance & Operations

### Regular Maintenance Tasks

**Daily**
- [ ] Check sync logs for errors
- [ ] Monitor key metrics
- [ ] Verify data freshness
- [ ] Check error notifications

**Weekly**
- [ ] Review performance trends
- [ ] Check database size and growth
- [ ] Update API rate limits if needed
- [ ] Review and rotate secrets

**Monthly**
- [ ] Database maintenance (vacuum, analyze)
- [ ] Update workflow versions
- [ ] Review and update documentation
- [ ] Security audit of credentials

### Backup & Recovery

**Database Backup**
```bash
# Supabase automated backups are enabled by default
# For additional backup control:
pg_dump -h your-project.supabase.co -U postgres -d postgres > backup.sql

# Raw data export for specific tenant
COPY shopify_orders_raw TO 'tenant_orders_backup.csv' WITH CSV HEADER;
```

**Workflow Backup**
```bash
# Export all workflows
n8n export:all --filename=workflows-backup.json

# Individual workflow export
n8n export:workflow --id=workflow-id --filename=specific-workflow.json
```

This deployment guide provides a comprehensive roadmap for deploying the n8n Shopify Integration Library from development to production, including scaling to multi-tenant environments and maintaining the system over time.