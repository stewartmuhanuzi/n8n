# Edge Functions Guide

## Overview

Supabase Edge Functions provide a serverless solution for extending the n8n Shopify Integration Library with custom logic, database operations, and API endpoints. This guide covers the setup, usage, and best practices for Edge Functions in our integration library.

## 🚀 Why Edge Functions?

### Benefits over Traditional Approaches

**vs CLI (`supabase db push`)**
- ✅ **No connection pool limits** - Dedicated DB connections
- ✅ **Better error handling** - Built-in retry logic
- ✅ **HTTP-based** - Call from anywhere with proper auth
- ✅ **Scalable** - Auto-scaling serverless architecture

**vs Dashboard SQL Editor**
- ✅ **Programmatic** - Automate database operations
- ✅ **Version controlled** - Code in repository
- ✅ **Reusable** - Call multiple times safely
- ✅ **Parameterized** - Dynamic execution

**vs n8n Database Nodes**
- ✅ **Faster execution** - Direct database access
- ✅ **Complex operations** - Multi-step procedures
- ✅ **Transaction safety** - ACID compliance
- ✅ **Error recovery** - Sophisticated error handling

## 📁 Edge Functions Structure

```
supabase/functions/
├── setup-database/
│   ├── index.ts           # Main function code
│   └── sql.sql           # SQL helper function
└── README.md             # Edge functions documentation
```

## 🔧 Setup Database Function

### Purpose

The `setup-database` Edge Function provides a robust alternative to CLI-based database setup, solving connection pool issues and providing programmatic database management.

### Features

- **Database schema creation** with all required tables
- **Table verification** to ensure setup completion
- **Error handling** with detailed logging
- **Idempotent operations** - safe to run multiple times
- **Multi-operation support** in a single function call

### API Reference

#### Endpoint
```
POST https://[PROJECT_REF].supabase.co/functions/v1/setup-database
```

#### Authentication
```bash
Authorization: Bearer [SUPABASE_SERVICE_ROLE_KEY]
Content-Type: application/json
```

#### Operations

**1. Verify Tables**
```json
{
  "operation": "verify_tables"
}
```

**Response:**
```json
{
  "success": true,
  "operation": "verify_tables",
  "result": {
    "tables": ["orders", "order_lines", "products", "product_variants", "sync_log", "shopify_orders_raw", "shopify_products_raw", "integration_logs"],
    "count": 8
  },
  "timestamp": "2024-12-08T20:15:30.123Z"
}
```

**2. Create Integration Logs Table**
```json
{
  "operation": "create_integration_logs"
}
```

**Response:**
```json
{
  "success": true,
  "operation": "create_integration_logs",
  "result": "Table created successfully",
  "timestamp": "2024-12-08T20:15:30.123Z"
}
```

**3. Complete Setup**
```json
{
  "operation": "setup"
}
```

**Response:**
```json
{
  "success": true,
  "operation": "setup",
  "result": {
    "message": "Setup completed successfully",
    "tables": ["orders", "order_lines", "products", "product_variants", "sync_log", "shopify_orders_raw", "shopify_products_raw", "integration_logs"],
    "count": 8
  },
  "timestamp": "2024-12-08T20:15:30.123Z"
}
```

## 🛠️ Development & Deployment

### Prerequisites

- **Supabase CLI** installed
- **Docker** running (required for Edge Functions)
- **Project linked** to local development environment

### Local Development

```bash
# Start local development environment
supabase start

# Run edge function locally
supabase functions serve setup-database

# Test locally
curl -X POST "http://localhost:54321/functions/v1/setup-database" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"operation": "setup"}'
```

### Deployment

```bash
# Deploy to production
supabase functions deploy setup-database

# Deploy without JWT verification (for setup)
supabase functions deploy setup-database --no-verify-jwt
```

### Environment Variables

```bash
# Required environment variables
SUPABASE_URL=https://[PROJECT_REF].supabase.co
SUPABASE_SERVICE_ROLE_KEY=[SERVICE_ROLE_KEY]

# Set in Supabase Dashboard → Settings → Edge Functions
supabase secrets set SUPABASE_URL="https://[PROJECT_REF].supabase.co"
supabase secrets set SUPABASE_SERVICE_ROLE_KEY="[SERVICE_ROLE_KEY]"
```

## 📝 Usage Examples

### 1. Quick Database Setup

```bash
# One-command complete setup
curl -X POST "https://[PROJECT_REF].supabase.co/functions/v1/setup-database" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"operation": "setup"}'
```

### 2. Browser Console Setup

```javascript
// Run directly in browser console
const response = await fetch('https://[PROJECT_REF].supabase.co/functions/v1/setup-database', {
  method: 'POST',
  headers: {
    'Authorization': 'Bearer [SERVICE_ROLE_KEY]',
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({ operation: 'setup' })
});

const result = await response.json();
console.log('Database setup result:', result);
```

### 3. Node.js Integration

```javascript
const { createClient } = require('@supabase/supabase-js');

const supabase = createClient(
  'https://[PROJECT_REF].supabase.co',
  '[SERVICE_ROLE_KEY]'
);

async function setupDatabase() {
  const { data, error } = await supabase.functions.invoke('setup-database', {
    body: { operation: 'setup' }
  });

  if (error) {
    console.error('Setup failed:', error);
    return;
  }

  console.log('Setup successful:', data);
}
```

## 🔒 Security Considerations

### Authentication

- **Service Role Key Required**: Only service role keys can execute database operations
- **No JWT Verification**: Setup function uses `--no-verify-jwt` flag for initial deployment
- **HTTPS Only**: All communications encrypted

### Authorization

```typescript
// Function includes authorization check
const authHeader = req.headers.get('Authorization')
if (!authHeader || !authHeader.startsWith('Bearer ')) {
  return new Response(
    JSON.stringify({ error: 'Missing or invalid authorization header' }),
    { status: 401 }
  )
}
```

### SQL Injection Prevention

```typescript
// Using parameterized queries
const sql = 'SELECT * FROM table WHERE id = $1';
// Not using string concatenation
```

## 📊 Monitoring & Logging

### Function Logs

```bash
# View function logs
supabase functions logs setup-database

# Real-time log streaming
supabase functions logs setup-database --follow
```

### Database Operations

```sql
-- Monitor Edge Function operations
SELECT
  request_method,
  request_url,
  response_status_code,
  execution_time_ms,
  created_at
FROM supabase_functions.edge_runtime_logs
WHERE function_name = 'setup-database'
ORDER BY created_at DESC;
```

### Error Tracking

```typescript
// Function includes comprehensive error handling
try {
  // Database operations
  result = await supabase.rpc('exec_sql', { sql: CREATE_INTEGRATION_LOGS_TABLE })
} catch (error) {
  console.error('Database operation failed:', error)
  return new Response(
    JSON.stringify({
      success: false,
      error: error.message,
      timestamp: new Date().toISOString()
    }),
    { status: 500 }
  )
}
```

## 🔄 Advanced Usage

### Custom Database Operations

You can extend the Edge Function pattern for other database operations:

```typescript
// Example: Custom data validation function
export default async function (req: Request) => {
  const { operation, table, data } = await req.json()

  switch (operation) {
    case 'validate_data':
      // Custom validation logic
      const validation = validateTableData(table, data)
      return new Response(JSON.stringify(validation))

    case 'cleanup_duplicates':
      // Duplicate cleanup logic
      const cleanup = await cleanupDuplicateRecords(table)
      return new Response(JSON.stringify(cleanup))
  }
}
```

### Multi-Operation Transactions

```typescript
// Execute multiple operations in a single transaction
async function createTablesTransaction() {
  const operations = [
    'CREATE TABLE IF NOT EXISTS table1 (...)',
    'CREATE TABLE IF NOT EXISTS table2 (...)',
    'CREATE INDEX IF NOT EXISTS idx_table1_field ON table1(field)'
  ]

  for (const sql of operations) {
    await supabase.rpc('exec_sql', { sql })
  }
}
```

## 🧪 Testing

### Unit Testing

```typescript
// tests/setup-database.test.ts
import { serve } from '../setup-database/index.ts'

Deno.test('setup-database function', async () => {
  const req = new Request('http://localhost', {
    method: 'POST',
    headers: { 'Authorization': 'Bearer test-key' },
    body: JSON.stringify({ operation: 'verify_tables' })
  })

  const res = await serve(req)
  const data = await res.json()

  assertEquals(data.success, true)
  assertEquals(data.operation, 'verify_tables')
})
```

### Integration Testing

```bash
# Test with real database
curl -X POST "https://[PROJECT_REF].supabase.co/functions/v1/setup-database" \
  -H "Authorization: Bearer $SUPABASE_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{"operation": "verify_tables"}' | jq
```

## 🚀 Performance Optimization

### Cold Start Reduction

```typescript
// Keep functions warm (if needed)
// Note: Supabase Edge Functions have good cold start performance
```

### Connection Management

```typescript
// Reuse Supabase client connections
const supabase = createClient(
  Deno.env.get('SUPABASE_URL')!,
  Deno.env.get('SUPABASE_SERVICE_ROLE_KEY)!
)
```

### Response Optimization

```typescript
// Use appropriate HTTP headers
return new Response(JSON.stringify(result), {
  status: 200,
  headers: {
    'Content-Type': 'application/json',
    'Cache-Control': 'no-cache',
    'Access-Control-Allow-Origin': '*'
  }
})
```

## 🔧 Troubleshooting

### Common Issues

**1. Docker Not Running**
```bash
# Start Docker
open -a Docker

# Verify Docker status
docker --version
```

**2. Permission Denied**
```bash
# Check function permissions
supabase functions list

# Re-deploy with correct permissions
supabase functions deploy setup-database --no-verify-jwt
```

**3. Environment Variables Missing**
```bash
# Check environment variables
supabase secrets list

# Set missing variables
supabase secrets set SUPABASE_URL="https://[PROJECT_REF].supabase.co"
```

### Debug Mode

```typescript
// Add debug logging
console.log('=== SETUP DATABASE FUNCTION ===')
console.log('Headers:', Object.fromEntries(req.headers.entries()))
console.log('Body:', await req.json())
console.log('Environment:', {
  SUPABASE_URL: Deno.env.get('SUPABASE_URL')?.substring(0, 20) + '...'
})
```

## 📚 Best Practices

### 1. Function Design
- **Single Responsibility**: Each function should do one thing well
- **Idempotent**: Safe to call multiple times
- **Error Handling**: Comprehensive error reporting
- **Logging**: Detailed logs for debugging

### 2. Security
- **Authentication**: Always validate authorization
- **Input Validation**: Validate all input parameters
- **SQL Prevention**: Use parameterized queries
- **Environment Variables**: Never expose secrets

### 3. Performance
- **Keep Functions Small**: Smaller functions cold start faster
- **Reuse Connections**: Don't create new database connections per request
- **Appropriate Caching**: Use HTTP headers for caching responses
- **Monitor Performance**: Track execution times and errors

### 4. Development
- **Local Testing**: Test functions locally before deployment
- **Version Control**: Keep function code in repository
- **Documentation**: Document all parameters and responses
- **Error Messages**: Provide clear, actionable error messages

## 🔮 Future Enhancements

### Planned Edge Functions

1. **Data Validation Function**
   - Validate data integrity across tables
   - Check foreign key relationships
   - Generate data quality reports

2. **Migration Helper Function**
   - Handle schema migrations
   - Backup data before migrations
   - Rollback capabilities

3. **Analytics Function**
   - Generate business reports
   - Calculate KPIs and metrics
   - Export data for external tools

4. **Health Check Function**
   - Monitor system health
   - Check data sync status
   - Performance metrics

### Integration with n8n

Edge Functions can be called from n8n workflows:
```json
{
  "node": "Edge Function",
  "parameters": {
    "url": "{{ $vars.SUPABASE_HOST }}/functions/v1/validate-data",
    "method": "POST",
    "authentication": "GenericCredential",
    "genericAuth": "supabase-service-role",
    "jsonBody": {
      "operation": "validate_orders",
      "date_range": "{{ $json.date_range }}"
    }
  }
}
```

This Edge Functions approach provides a robust, scalable foundation for database operations and custom business logic in your n8n Shopify Integration Library.