# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a **professional, multi-tenant n8n library** for integrating Shopify with Supabase. The project has evolved from a monolithic workflow into a modular, reusable library that supports unlimited merchants. The system follows a **Raw → Normalized** data pattern, storing exact Shopify API responses for audit trails while also providing clean, business-ready normalized data.

## Core Architecture

### Evolution from Monolithic to Modular

The project has been completely refactored from a single 527-line workflow into 5 modular, reusable components:

**Original (n8n.json):**
- Single monolithic workflow
- Hard-coded configurations
- Direct API → Database flow

**New Modular System (flows/ directory):**
- 5 independent workflows
- Environment-driven configuration
- API → Raw Tables → Transformation → Normalized Tables

### Modular Workflow Components

#### 1. Sync Orchestrator (`flows/shopify/shared/sync-orchestrator.json`)
- **Purpose**: Main coordinator that orchestrates the entire sync process
- **Features**: Business hours enforcement, session tracking, Slack notifications, comprehensive monitoring
- **Triggers**: Cron (default 15 min) + Manual trigger for testing

#### 2. Orders Fetch (`flows/shopify/orders/shopify-orders-fetch.json`)
- **Purpose**: Fetches orders from Shopify Admin API to `shopify_orders_raw` table
- **Features**: Configurable intervals, retry logic, rate limiting

#### 3. Products Fetch (`flows/shopify/products/shopify-products-fetch.json`)
- **Purpose**: Fetches products from Shopify Admin API to `shopify_products_raw` table
- **Features**: Same architecture as orders fetch

#### 4. Orders Transform (`flows/shopify/orders/orders-transform.json`)
- **Purpose**: Transforms raw orders to normalized `orders` and `order_lines` tables
- **Features**: Batch processing, validation, error tracking

#### 5. Products Transform (`flows/shopify/products/products-transform.json`)
- **Purpose**: Transforms raw products to normalized `products` and `product_variants` tables
- **Features**: Handles complex product-variant relationships

### Data Flow Pattern

```
Triggers → Business Hours → Orchestrator
                              ↓
                    ┌─────────────────┐
                    │  Parallel Fetch │
                    │  Orders & Prods │
                    └─────────────────┘
                              ↓
                    ┌─────────────────┐
                    │   Raw Tables    │
                    │ (Audit Trail)   │
                    └─────────────────┘
                              ↓
                    ┌─────────────────┐
                    │  Transform      │
                    │   Workflows     │
                    └─────────────────┘
                              ↓
                    ┌─────────────────┐
                    │ Normalized Tabs │
                    │ (Business Ready)│
                    └─────────────────┘
```

## Database Schema

### Raw Tables (Audit Trail)
- **`shopify_orders_raw`** - Exact Shopify API order responses
- **`shopify_products_raw`** - Complete product data with variants
- **`integration_logs`** - Comprehensive execution tracking

All raw tables include:
- `id`: Primary key
- `created_at`, `updated_at`: Timestamps
- `processed`: Boolean flag (default: false)
- `processed_at`: Timestamp when processed
- Raw JSON data columns

### Normalized Tables (Business Ready)
- **`orders`** - Clean order data optimized for queries
- **`order_lines`** - Line items with product references
- **`products`** - Product catalog metadata
- **`product_variants`** - SKU, inventory, pricing data
- **`sync_log`** - Legacy sync tracking

### Key Database Features
- **Unique constraints** on Shopify IDs for idempotency
- **Foreign key relationships** for data integrity
- **Processing flags** to prevent duplicate transformations

## Environment Configuration

The project uses comprehensive environment variable configuration with templates in [`config/`](config/):

### Core Environment Variables
```bash
# Multi-tenant Configuration
MERCHANT_ID=merchant-001                 # Unique merchant identifier
SHOPIFY_ADMIN=shop-name                  # Shopify admin subdomain
SHOPIFY_ACCESS_TOKEN=shpat_xxxxxxxxx     # Shopify API access token
SHOPIFY_API_VERSION=2023-10              # Shopify API version

# Database Configuration
SUPABASE_HOST=https://project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...         # Database service role key

# Sync Configuration
SYNC_INTERVAL_MINUTES=15                 # Sync frequency
SYNC_LOOKBACK_HOURS=1                    # Time window for incremental sync
API_BATCH_SIZE=250                       # Records per API call

# Business Hours
BUSINESS_HOURS_START=8                   # Start hour (24-hour format)
BUSINESS_HOURS_END=18                    # End hour (24-hour format)
```

### Configuration Templates
- [`config/env.template`](config/env.template) - Comprehensive environment variable template
- [`config/merchant-config.template.json`](config/merchant-config.template.json) - Multi-tenant merchant configuration
- [`config/business-rules.template.json`](config/business-rules.template.json) - Business logic configuration

## Common Development Tasks

### Initial Setup

1. **Database Setup** (using Supabase CLI):
   ```bash
   # Install Supabase CLI (if not installed)
   brew install supabase/tap/supabase

   # Link to your Supabase project
   supabase link --project-ref YOUR_PROJECT_REF

   # Run all migrations to create tables
   supabase db push
   ```

2. **Environment Configuration**:
   ```bash
   cp config/env.template .env
   # Edit .env with your credentials
   ```

3. **Import Workflows** to n8n (in order):
   - `flows/shopify/shared/sync-orchestrator.json`
   - `flows/shopify/orders/shopify-orders-fetch.json`
   - `flows/shopify/orders/orders-transform.json`
   - `flows/shopify/products/shopify-products-fetch.json`
   - `flows/shopify/products/products-transform.json`

### Testing the System

1. **Manual Testing**:
   - Use the Manual Trigger in the sync orchestrator workflow
   - Monitor `integration_logs` table for execution tracking
   - Check n8n execution logs for detailed processing information

2. **Database Monitoring Queries**:
   ```sql
   -- Sync health dashboard
   SELECT
     flow_name,
     status,
     COUNT(*) as executions,
     MAX(created_at) as last_execution
   FROM integration_logs
   WHERE created_at > NOW() - INTERVAL '24 hours'
   GROUP BY flow_name, status;
   ```

### Adding New Merchants (Multi-tenant)

1. Configure additional merchant in environment:
   ```bash
   # Primary merchant
   MERCHANT_ID=merchant-001
   SHOPIFY_ADMIN=shop-name-1
   SHOPIFY_ACCESS_TOKEN=shpat_token_1

   # Additional merchant
   MERCHANT_ID=merchant-002
   SHOPIFY_ADMIN=shop-name-2
   SHOPIFY_ACCESS_TOKEN=shpat_token_2
   ```

2. Use merchant-config template for per-merchant settings
3. Set up database isolation (separate schema or tenant_id column)

### Modifying Field Mappings

Edit the JavaScript transformation functions in n8n:
- **Orders**: "Transform & Validate Orders" node in orders-transform workflow
- **Products**: "Transform & Validate Products" node in products-transform workflow

Both functions include:
- Data validation and type conversion
- Error handling with detailed console logging
- Null value handling and defaults
- Business rule application

## Debugging Common Issues

### API Rate Limiting
- Shopify API limits: 2 calls per second for paid plans
- Workflow uses configurable `API_BATCH_SIZE` (default: 250)
- Adjust `SYNC_INTERVAL_MINUTES` if rate limited
- Retry logic is implemented with exponential backoff

### Data Validation Errors
- Check console logs in n8n execution
- Review `integration_logs` table for error summaries
- Processing functions handle individual record failures gracefully
- Failed records don't stop overall processing

### Database Issues
- Verify `SUPABASE_SERVICE_ROLE_KEY` has write permissions
- Check foreign key relationships in order_lines
- Ensure Shopify IDs are consistent across tables
- If CLI has connection issues, check Supabase project status and permissions

## Workflow Configuration Patterns

### API Requests
- Shopify Admin API version configurable via `SHOPIFY_API_VERSION`
- Incremental sync using `updated_at_min` (lookback window configurable)
- Pagination handled via `API_BATCH_SIZE` parameter
- All API calls include retry logic

### Database Operations
- All upserts use `on_conflict` resolution with Shopify IDs
- `Prefer: resolution=merge-duplicates` header for Supabase
- `continueOnFail: true` for resilience
- Service role key required for write operations
- Batch processing for efficient database operations

### Error Handling Strategy
- Individual record failures don't stop entire sync
- Errors counted and aggregated in orchestrator
- Comprehensive logging to `integration_logs` table
- Slack notifications for critical errors
- Session tracking for end-to-end monitoring

## Multi-tenant Architecture

### Isolation Strategies
1. **Schema per Tenant**: Complete data isolation
2. **Shared Raw + Separate Normalized**: Balance of efficiency and isolation
3. **Tenant ID Columns**: Simple approach with row-level security

### Configuration Management
- Per-merchant environment variables
- Merchant configuration JSON templates
- Business rules per merchant
- Feature flags per merchant

### Scaling Considerations
- Horizontal: Multiple n8n instances behind load balancer
- Vertical: Resource allocation per merchant volume
- Database: Read replicas for reporting queries

## N8n-Specific Notes

- Workflows use n8n expression syntax: `={{ $vars.VARIABLE_NAME }}`
- JavaScript functions use n8n's function node format
- Data flows between nodes as JSON objects
- Use `$input.all()` to access all input items in functions
- Environment variables referenced via `{{$vars.VARIABLE_NAME}}`

## Git Workflow

- Main development happens on feature branches
- Current branch: `add-products-fetching`
- Export workflow changes to JSON after modifications
- Commit workflow JSON files to version control
- Modular workflows allow independent versioning

## Documentation Structure

- [`README.md`](README.md) - Main project overview and quick start
- [`docs/README.md`](docs/README.md) - Library documentation
- [`flows/README.md`](flows/README.md) - Workflow-specific documentation
- [`flows/MIGRATION_SUMMARY.md`](flows/MIGRATION_SUMMARY.md) - Migration from monolithic to modular
- [`scripts/complete-setup.md`](scripts/complete-setup.md) - Edge Function setup guide

## Performance Optimization

### Batching
- Configurable batch sizes for API calls (`API_BATCH_SIZE`)
- Transform batch processing (`TRANSFORM_BATCH_SIZE`)
- Database upsert batching

### Rate Limiting
- Respects Shopify API limits
- Configurable delays between requests
- Exponential backoff for retries

### Caching
- Consider Redis for frequent lookups
- Cache TTL configuration available
- Connection pooling for database

## Security & Compliance

### Data Security
- All API keys in environment variables
- Service role keys for database writes
- Webhook signature verification
- Audit trail in integration_logs

### Compliance Features
- GDPR data anonymization options
- Configurable data retention
- Access logging for all operations
- Role-based access patterns