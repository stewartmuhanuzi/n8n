# Troubleshooting Guide & FAQ

## Overview

This comprehensive guide covers common issues, troubleshooting steps, and frequently asked questions for the n8n Shopify Integration Library.

## 🔧 Quick Diagnostic Checklist

Before diving into specific issues, run this quick diagnostic:

```sql
-- Check database connection and table status
SELECT
  'Database Connection' as test,
  CASE
    WHEN COUNT(*) > 0 THEN '✅ Connected'
    ELSE '❌ Failed'
  END as status
FROM information_schema.tables
WHERE table_schema = 'public'
LIMIT 1;

-- Check required tables exist
SELECT
  table_name,
  '✅ Exists' as status
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('orders', 'order_lines', 'products', 'product_variants', 'shopify_orders_raw', 'shopify_products_raw', 'integration_logs')
ORDER BY table_name;

-- Check recent sync activity
SELECT
  flow_name,
  status,
  COUNT(*) as executions,
  MAX(created_at) as last_execution
FROM integration_logs
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY flow_name, status
ORDER BY last_execution DESC NULLS LAST;
```

## 🚨 Common Issues & Solutions

### Database Connection Issues

#### Issue: "Connection refused" or "Authentication failed"

**Symptoms:**
- `supabase db push` fails with connection errors
- n8n workflows show database connection errors
- Edge functions return connection timeouts

**Diagnosis:**
```bash
# Test basic connectivity
curl -I https://your-project.supabase.co

# Test database connection with psql
psql "postgresql://postgres:[PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres"

# Check Supabase service status
supabase status
```

**Solutions:**

1. **Verify Project Reference**
   ```bash
   # Check your project reference
   supabase projects list

   # Relink if necessary
   supabase link --project-ref YOUR_CORRECT_REF
   ```

2. **Check API Keys**
   ```bash
   # Verify service role key in environment
   echo $SUPABASE_SERVICE_ROLE_KEY | cut -c1-20
   ```

3. **Network Issues**
   ```bash
   # Check firewall/proxy settings
   # Ensure outbound HTTPS on port 443 is allowed
   # Check corporate VPN/firewall restrictions
   ```

#### Issue: "SSL connection is required"

**Symptoms:**
- Database connection fails with SSL errors
- n8n HTTP requests to Supabase fail

**Solutions:**
```bash
# Force SSL in connection string
DATABASE_URL="postgresql://postgres:password@db.project-ref.supabase.co:5432/postgres?sslmode=require"

# Update n8n database configuration
# In n8n settings: DB_SSL_MODE=require
```

### Shopify API Issues

#### Issue: "401 Unauthorized" from Shopify

**Symptoms:**
- Orders fetch returns 401 errors
- Products fetch fails with authentication errors

**Diagnosis:**
```bash
# Test Shopify API connection
curl -X GET "https://YOUR_SHOP.myshopify.com/admin/api/2023-10/shop.json" \
  -H "X-Shopify-Access-Token: YOUR_TOKEN"
```

**Solutions:**

1. **Verify Access Token**
   ```bash
   # Check token format (should start with 'shpat_')
   echo $SHOPIFY_ACCESS_TOKEN | cut -c1-10

   # Test with minimal scope
   curl -X GET "https://YOUR_SHOP.myshopify.com/admin/api/2023-10/shop.json" \
     -H "X-Shopify-Access-Token: $SHOPIFY_ACCESS_TOKEN"
   ```

2. **Check App Permissions**
   - In Shopify Admin → Apps → Your App → Configure Admin API access scopes
   - Required scopes: `read_orders`, `read_products`, `read_customers`

3. **App Status**
   - Ensure app is not suspended
   - Check app installation status
   - Verify webhooks are configured if used

#### Issue: "429 Too Many Requests"

**Symptoms:**
- Sync fails with rate limit errors
- Intermittent API failures

**Solutions:**

1. **Adjust API Rate Limits**
   ```bash
   # Reduce batch size
   API_BATCH_SIZE=100  # Was 250

   # Increase sync interval
   SYNC_INTERVAL_MINUTES=30  # Was 15

   # Add longer lookback window
   SYNC_LOOKBACK_HOURS=2  # Was 1
   ```

2. **Implement Rate Limiting**
   ```javascript
   // In fetch workflows, add delays between batches
   await new Promise(resolve => setTimeout(resolve, 1000));
   ```

### n8n Workflow Issues

#### Issue: Workflows Not Triggering

**Symptoms:**
- Cron triggers not executing
- Manual triggers work but automated don't
- No error messages in logs

**Solutions:**

1. **Check n8n Configuration**
   ```bash
   # Verify n8n is running
   ps aux | grep n8n

   # Check cron configuration
   # In workflow: Cron expression should be "*/15 * * * *"
   ```

2. **Verify Time Zone Settings**
   ```bash
   # Check n8n time zone
   # In n8n settings: Time zone should match business hours
   ```

3. **Business Hours Filter**
   ```bash
   # Temporarily disable business hours for testing
   SYNC_BUSINESS_HOURS_START=0
   SYNC_BUSINESS_HOURS_END=24
   ```

#### Issue: "Environment variable not found"

**Symptoms:**
- Workflows show undefined values
- HTTP requests fail with missing credentials

**Solutions:**

1. **Check Environment Variables**
   ```bash
   # Verify all required variables are set
   env | grep -E "(SHOPIFY_|SUPABASE_|SYNC_)"

   # Check n8n environment
   # In n8n: Settings → Environment variables
   ```

2. **Variable Naming**
   ```bash
   # Common naming mistakes:
   # ❌ SHOPIFY_TOKEN
   # ✅ SHOPIFY_ACCESS_TOKEN

   # ❌ SUPABASE_URL
   # ✅ SUPABASE_HOST
   ```

#### Issue: Large Dataset Processing

**Symptoms:**
- Workflows timeout on large datasets
- Memory issues during processing
- Partial syncs

**Solutions:**

1. **Optimize Batch Processing**
   ```javascript
   // In transform workflows, process in smaller chunks
   const batchSize = 50;
   for (let i = 0; i < records.length; i += batchSize) {
     const chunk = records.slice(i, i + batchSize);
     await processBatch(chunk);
     // Add small delay between batches
     await new Promise(resolve => setTimeout(resolve, 500));
   }
   ```

2. **Increase Timeouts**
   ```bash
   # In n8n: Settings → Execution timeout
   # Set to 300 seconds for large datasets
   ```

### Data Synchronization Issues

#### Issue: Missing Data in Normalized Tables

**Symptoms:**
- Raw tables have data but normalized tables don't
- Transform workflows not processing records

**Diagnosis:**
```sql
-- Check for unprocessed raw records
SELECT
  'shopify_orders_raw' as table_name,
  COUNT(*) as total_records,
  COUNT(CASE WHEN processed = FALSE THEN 1 END) as unprocessed,
  COUNT(CASE WHEN error_message IS NOT NULL THEN 1 END) as errors
FROM shopify_orders_raw

UNION ALL

SELECT
  'shopify_products_raw' as table_name,
  COUNT(*) as total_records,
  COUNT(CASE WHEN processed = FALSE THEN 1 END) as unprocessed,
  COUNT(CASE WHEN error_message IS NOT NULL THEN 1 END) as errors
FROM shopify_products_raw;
```

**Solutions:**

1. **Manual Trigger Transform Workflows**
   - Open `orders-transform.json` workflow
   - Use manual trigger
   - Monitor for errors

2. **Check Processing Errors**
   ```sql
   -- Review specific errors
   SELECT external_id, error_message, retry_count, next_retry_at
   FROM shopify_orders_raw
   WHERE processed = FALSE
     AND error_message IS NOT NULL
   ORDER BY received_at DESC
   LIMIT 10;
   ```

3. **Reset Failed Records**
   ```sql
   -- Reset records for reprocessing
   UPDATE shopify_orders_raw
   SET processed = FALSE,
       processed_at = NULL,
       error_message = NULL,
       retry_count = 0
   WHERE processed = TRUE
     AND created_at > NOW() - INTERVAL '1 day';
   ```

#### Issue: Duplicate Records

**Symptoms:**
- Same order appearing multiple times
- Duplicate product entries

**Solutions:**

1. **Check Unique Constraints**
   ```sql
   -- Verify unique constraints are enforced
   SELECT conname, contype, pg_get_constraintdef(oid)
   FROM pg_constraint
   WHERE conrelid = 'public.orders'::regclass;
   ```

2. **Clean Up Duplicates**
   ```sql
   -- Remove duplicate orders (keep latest)
   WITH duplicates AS (
     SELECT external_id, source_system, MAX(id) as keep_id
     FROM orders
     GROUP BY external_id, source_system
     HAVING COUNT(*) > 1
   )
   DELETE FROM orders
   WHERE (external_id, source_system) IN (
     SELECT external_id, source_system FROM duplicates
   )
   AND id NOT IN (SELECT keep_id FROM duplicates);
   ```

### Edge Function Issues

#### Issue: "Function deployment failed"

**Symptoms:**
- `supabase functions deploy` fails
- Edge function returns 500 errors

**Solutions:**

1. **Check Docker**
   ```bash
   # Edge functions need Docker
   docker --version

   # Start Docker if not running
   open -a Docker
   ```

2. **Function Logs**
   ```bash
   # Check function logs
   supabase functions logs setup-database
   ```

3. **Environment Variables**
   ```bash
   # Verify function environment
   supabase secrets list
   ```

## 🔍 Debugging Tools & Techniques

### n8n Workflow Debugging

1. **Add Debug Nodes**
   ```json
   {
     "parameters": {
       "options": {}
     },
     "name": "Debug Output",
     "type": "n8n-nodes-base.debug"
   }
   ```

2. **Console Logging**
   ```javascript
   // In Function nodes
   console.log('=== DEBUG ===');
   console.log('Input items:', $input.all());
   console.log('Environment vars:', {
     SHOP_IDENTIFIER: $vars.SHOP_IDENTIFIER,
     API_BATCH_SIZE: $vars.API_BATCH_SIZE
   });
   ```

3. **Error Handling**
   ```javascript
   // Wrap operations in try-catch
   try {
     // Your processing logic
     const result = processOrder(orderData);
     return [{ json: result }];
   } catch (error) {
     console.error('Processing failed:', error);
     return [{ json: { error: error.message, order: orderData } }];
   }
   ```

### Database Debugging

1. **Query Performance**
   ```sql
   -- Analyze slow queries
   EXPLAIN ANALYZE SELECT * FROM orders WHERE created_at > NOW() - INTERVAL '7 days';

   -- Check query plans
   EXPLAIN (FORMAT JSON) SELECT * FROM order_lines WHERE order_id = 12345;
   ```

2. **Connection Monitoring**
   ```sql
   -- Active connections
   SELECT state, count(*) FROM pg_stat_activity GROUP BY state;

   -- Long-running queries
   SELECT pid, now() - pg_stat_activity.query_start AS duration, query
   FROM pg_stat_activity
   WHERE (now() - pg_stat_activity.query_start) > interval '5 minutes';
   ```

### API Debugging

1. **Shopify API Testing**
   ```bash
   # Test with curl
   curl -v -X GET "https://YOUR_SHOP.myshopify.com/admin/api/2023-10/orders.json?limit=1" \
     -H "X-Shopify-Access-Token: YOUR_TOKEN" \
     -H "Content-Type: application/json"
   ```

2. **Supabase API Testing**
   ```bash
   # Test REST API
   curl -v -X GET "$SUPABASE_HOST/rest/v1/orders?limit=1" \
     -H "apikey: $SUPABASE_SERVICE_ROLE_KEY" \
     -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY"
   ```

## 📚 Performance Tuning

### Database Optimization

1. **Index Analysis**
   ```sql
   -- Unused indexes
   SELECT schemaname, tablename, indexname, idx_scan, idx_tup_read, idx_tup_fetch
   FROM pg_stat_user_indexes
   WHERE idx_scan < 10
   ORDER BY idx_scan;

   -- Missing indexes suggestions
   SELECT schemaname, tablename, attname, n_distinct, correlation
   FROM pg_stats
   WHERE schemaname = 'public'
     AND tablename IN ('orders', 'order_lines', 'products');
   ```

2. **Table Statistics**
   ```sql
   -- Update table statistics
   ANALYZE orders;
   ANALYZE order_lines;
   ANALYZE products;
   ANALYZE product_variants;
   ```

### n8n Workflow Optimization

1. **Batch Processing**
   ```javascript
   // Process records in efficient batch sizes
   const OPTIMAL_BATCH_SIZE = 100;
   const DELAY_BETWEEN_BATCHES = 1000; // 1 second
   ```

2. **Memory Management**
   ```javascript
   // Clear large objects from memory
   delete largeObject;
   if (global.gc) global.gc(); // Force garbage collection
   ```

## 🛠️ Recovery Procedures

### Data Recovery

1. **Restore from Raw Tables**
   ```sql
   -- Reprocess raw data
   UPDATE shopify_orders_raw
   SET processed = FALSE,
       processed_at = NULL,
       error_message = NULL
   WHERE external_id IN ('ORDER_ID_1', 'ORDER_ID_2');
   ```

2. **Point-in-Time Recovery**
   ```sql
   -- Using Supabase point-in-time recovery
   -- Contact Supabase support for specific time recovery
   ```

### System Recovery

1. **Workflow Recovery**
   ```bash
   # Export workflows
   n8n export:all --filename=backup-$(date +%Y%m%d).json

   # Import workflows
   n8n import:all --filename=backup-20241208.json
   ```

2. **Database Recovery**
   ```bash
   # Create backup
   pg_dump -h $SUPABASE_HOST -U postgres -d postgres > backup.sql

   # Restore backup
   psql -h $SUPABASE_HOST -U postgres -d postgres < backup.sql
   ```

## ❓ Frequently Asked Questions

### General Questions

**Q: How do I add a new merchant to the system?**
A:
1. Create new environment variables with merchant prefix
2. Duplicate workflows with merchant-specific configuration
3. Create new database schema or use multi-tenant design
4. Test with manual trigger before automation

**Q: What's the difference between raw and normalized tables?**
A:
- **Raw tables**: Complete, unmodified Shopify API responses (audit trail)
- **Normalized tables**: Clean, structured data optimized for queries and business logic

**Q: How often should I run the sync?**
A:
- **Small stores**: Every 15-30 minutes
- **Medium stores**: Every 10-15 minutes
- **Large stores**: Every 5-10 minutes
- **Real-time needs**: Consider webhooks instead of polling

### Technical Questions

**Q: Why do I need to install Docker for Edge Functions?**
A: Edge Functions run in Docker containers during development and deployment. Docker handles the isolation and execution environment.

**Q: Can I use MySQL instead of PostgreSQL?**
A: The library is designed specifically for PostgreSQL/Supabase. MySQL would require significant schema and query modifications.

**Q: How do I handle Shopify API rate limits?**
A:
1. Implement exponential backoff retry logic
2. Use appropriate batch sizes (100-250 records)
3. Monitor X-Shopify-Shop-Api-Call-Limit headers
4. Consider webhooks for real-time updates

**Q: What happens if a sync fails midway?**
A: The library implements idempotent processing:
- Failed records are marked with error messages
- Successful records are preserved
- Retry logic handles transient failures
- Manual recovery options available

### Performance Questions

**Q: How many orders can the system handle?**
A: The system can handle enterprise volumes:
- **Small**: < 100 orders/day (single instance)
- **Medium**: 100-1,000 orders/day (with optimization)
- **Large**: 1,000+ orders/day (requires scaling strategy)

**Q: Should I use cron triggers or webhooks?**
A:
- **Cron**: Good for reliability, simpler setup
- **Webhooks**: Better for real-time, more complex setup
- **Hybrid**: Use both for maximum reliability

### Security Questions

**Q: How do I secure sensitive data?**
A:
- Use environment variables for all credentials
- Enable Row Level Security (RLS) in Supabase
- Use SSL/TLS for all connections
- Regularly rotate API keys and tokens
- Implement audit logging

**Q: Is customer data GDPR compliant?**
A: The library provides GDPR compliance features:
- Raw data retention policies
- Customer data deletion capabilities
- Audit trails for data access
- Data export functionality

## 📞 Getting Help

### Self-Service Resources

1. **Documentation**
   - [Architecture Guide](./ARCHITECTURE.md)
   - [Deployment Guide](./DEPLOYMENT.md)
   - [API Reference](./API-REFERENCE.md)

2. **Diagnostic Tools**
   - Integration logs table
   - n8n execution logs
   - Database query analysis

3. **Community Resources**
   - n8n community forums
   - Supabase documentation
   - Shopify API documentation

### When to Contact Support

Contact support when:
- Multiple critical failures in 24 hours
- Data corruption suspected
- Performance degradation > 50%
- Security incidents

### Support Request Template

```
Issue Description: [Brief description]
Environment: [Production/Staging/Development]
Last Working: [Date when it last worked]
Error Messages: [Exact error messages]
Steps Taken: [What you've tried]
Impact: [Business impact]
```

## 🔄 Maintenance Checklist

### Daily
- [ ] Check integration_logs for errors
- [ ] Monitor sync completion rates
- [ ] Verify data freshness
- [ ] Check Slack notifications

### Weekly
- [ ] Review performance metrics
- [ ] Check database growth
- [ ] Update API rate limits if needed
- [ ] Review error patterns

### Monthly
- [ ] Database maintenance (vacuum, analyze)
- [ ] Update workflow versions
- [ ] Review and rotate secrets
- [ ] Security audit

### Quarterly
- [ ] Performance optimization review
- [ ] Capacity planning
- [ ] Documentation updates
- [ ] Disaster recovery testing

This comprehensive troubleshooting guide should help you diagnose and resolve most issues with the n8n Shopify Integration Library. Remember to start with the Quick Diagnostic Checklist and work through issues systematically.