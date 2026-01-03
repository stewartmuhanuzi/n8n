# Shopify Sync Workflows - Modular Library Architecture

This directory contains a refactored, modular architecture for Shopify data synchronization. The monolithic workflow has been broken down into reusable, configurable components following the library architecture pattern.

## Architecture Overview

The new architecture follows a **Raw → Normalized** pattern:
1. **Fetch Workflows**: API → Raw Tables
2. **Transform Workflows**: Raw Tables → Normalized Tables
3. **Orchestrator**: Coordinates the entire process

## Directory Structure

```
/flows/shopify/
├── orders/
│   ├── shopify-orders-fetch.json     # Fetch orders from Shopify API to raw table
│   └── orders-transform.json         # Transform raw orders to normalized format
├── products/
│   ├── shopify-products-fetch.json   # Fetch products from Shopify API to raw table
│   └── products-transform.json       # Transform raw products to normalized format
└── shared/
    └── sync-orchestrator.json        # Coordinates the entire sync process
```

## Workflow Components

### 1. Shopify Orders Fetch (`/flows/shopify/orders/shopify-orders-fetch.json`)
**Purpose**: Fetches orders from Shopify API and stores them in the `raw_shopify_orders` table.

**Key Features**:
- Configurable fetch interval and window
- Retry logic for API failures
- Stores data in raw format with minimal processing
- Comprehensive logging and monitoring

**Environment Variables**:
- `SHOPIFY_FETCH_INTERVAL_MINUTES`: How often to fetch (default: 15)
- `SHOPIFY_API_VERSION`: Shopify API version (default: 2023-10)
- `SHOPIFY_FETCH_LIMIT`: Records per request (default: 250)
- `SHOPIFY_FETCH_WINDOW_HOURS`: Lookback window (default: 1)

### 2. Shopify Products Fetch (`/flows/shopify/products/shopify-products-fetch.json`)
**Purpose**: Fetches products from Shopify API and stores them in the `raw_shopify_products` table.

**Key Features**:
- Same configuration options as orders fetch
- Handles product and variant data in raw format
- Retry and error handling

### 3. Orders Transform (`/flows/shopify/orders/orders-transform.json`)
**Purpose**: Transforms raw order data into normalized `orders` and `order_lines` tables.

**Key Features**:
- Processes unprocessed raw orders in batches
- Validates and cleans data
- Handles orders and line items separately
- Marks raw records as processed
- Comprehensive error tracking

**Environment Variables**:
- `TRANSFORM_INTERVAL_MINUTES`: How often to transform (default: 5)
- `TRANSFORM_BATCH_SIZE`: Records per batch (default: 100)

**Data Flow**:
1. Fetch unprocessed records from `raw_shopify_orders`
2. Transform and validate order data
3. Upsert to `orders` table
4. Transform and validate line items
5. Upsert to `order_lines` table
6. Mark raw records as processed

### 4. Products Transform (`/flows/shopify/products/products-transform.json`)
**Purpose**: Transforms raw product data into normalized `products` and `product_variants` tables.

**Key Features**:
- Same batch processing approach as orders transform
- Handles products and variants
- Comprehensive field mapping and validation

**Data Flow**:
1. Fetch unprocessed records from `raw_shopify_products`
2. Transform and validate product data
3. Upsert to `products` table
4. Transform and validate variants
5. Upsert to `product_variants` table
6. Mark raw records as processed

### 5. Sync Orchestrator (`/flows/shopify/shared/sync-orchestrator.json`)
**Purpose**: Coordinates the entire sync process and provides monitoring.

**Key Features**:
- Business hours enforcement
- Session tracking and logging
- Error aggregation and reporting
- Slack notifications
- Comprehensive sync summary

**Environment Variables**:
- `SYNC_INTERVAL_MINUTES`: Main sync interval (default: 15)
- `BUSINESS_HOURS_START`: Start hour (default: 8)
- `BUSINESS_HOURS_END`: End hour (default: 18)
- `SYNC_ENABLED`: Enable/disable sync (default: true)
- `ENVIRONMENT`: Environment name for logging
- Workflow IDs for component triggers

## Configuration

### Required Environment Variables

All workflows require these base variables:

```bash
# Shopify Configuration
SHOPIFY_ADMIN=your-shop-name
SHOPIFY_ACCESS_TOKEN=your-access-token
SHOPIFY_API_VERSION=2023-10

# Supabase Configuration
SUPABASE_HOST=https://your-project.supabase.co
SUPABASE_SERVICE_ROLE_KEY=your-service-role-key

# Monitoring (Optional)
SLACK_WEBHOOK_URL=your-slack-webhook-url
```

### Optional Configuration Variables

```bash
# Timing Configuration
SHOPIFY_FETCH_INTERVAL_MINUTES=15
SHOPIFY_FETCH_WINDOW_HOURS=1
SHOPIFY_FETCH_LIMIT=250
TRANSFORM_INTERVAL_MINUTES=5
TRANSFORM_BATCH_SIZE=100
SYNC_INTERVAL_MINUTES=15

# Business Hours
BUSINESS_HOURS_START=8
BUSINESS_HOURS_END=18
SYNC_ENABLED=true

# Environment
ENVIRONMENT=production

# Workflow IDs (if custom names used)
WORKFLOW_ID_ORDERS_FETCH=shopify-orders-fetch
WORKFLOW_ID_PRODUCTS_FETCH=shopify-products-fetch
WORKFLOW_ID_ORDERS_TRANSFORM=orders-transform
WORKFLOW_ID_PRODUCTS_TRANSFORM=products-transform
```

## Database Schema Requirements

### Raw Tables (staging)
- `raw_shopify_orders`: Stores raw order JSON from Shopify
- `raw_shopify_products`: Stores raw product JSON from Shopify

Both raw tables need:
- `id`: Primary key
- `created_at`, `updated_at`: Timestamps
- `processed`: Boolean flag (default: false)
- `processed_at`: Timestamp when processed
- Raw JSON data columns

### Normalized Tables (final)
- `orders`: Normalized order data
- `order_lines`: Normalized line item data
- `products`: Normalized product data
- `product_variants`: Normalized variant data

## Deployment Instructions

### 1. Import Workflows
1. Import each JSON file into n8n as separate workflows
2. Set appropriate workflow names matching the file names
3. Configure environment variables in n8n settings

### 2. Set Up Database Tables
Create the required raw and normalized tables in Supabase using the schema definitions.

### 3. Configure Triggers
1. Activate the Sync Orchestrator workflow
2. Ensure fetch workflows are activated
3. Transform workflows will be triggered by the orchestrator

### 4. Test the System
1. Use the Manual Sync Trigger in the orchestrator for initial testing
2. Monitor logs and error handling
3. Verify data flow from raw to normalized tables

## Monitoring and Troubleshooting

### Log Locations
- Each workflow logs to console with structured logging
- Sync orchestrator logs comprehensive summaries to `sync_log` table
- Individual component workflows log their own status

### Error Handling
- All workflows have retry logic for transient failures
- Errors are aggregated and reported in sync summaries
- Failed records are tracked but don't stop processing

### Performance Monitoring
- Monitor fetch batch sizes and intervals
- Track transform processing times
- Watch for backlogs in raw tables (unprocessed records)

## Benefits of This Architecture

1. **Modularity**: Each component can be developed, tested, and deployed independently
2. **Reusability**: Components can be reused in different sync patterns
3. **Resilience**: Failures in one component don't affect others
4. **Scalability**: Components can be scaled independently
5. **Maintainability**: Easier to debug and modify individual components
6. **Monitoring**: Comprehensive logging and error tracking
7. **Flexibility**: Easy to add new data types or modify existing ones

## Migration from Monolithic Workflow

To migrate from the original monolithic workflow:
1. Deploy the new modular workflows
2. Ensure database schema is updated for raw tables
3. Configure all environment variables
4. Test with the manual trigger
5. Once verified, deactivate the original monolithic workflow
6. Activate the new orchestrator

The new system provides the same functionality with improved reliability and maintainability.