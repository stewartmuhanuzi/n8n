# Architecture Documentation

## Overview

The n8n Shopify Integration Library follows a scalable, event-driven architecture designed for multi-tenant deployment. This document explains the technical design, data flow, and architectural decisions that make the library robust, maintainable, and enterprise-ready.

## Core Architectural Principles

### 1. Raw + Normalized Data Pattern

The library implements a dual-storage approach for maximum flexibility and reliability:

#### Raw Data Storage
- **Purpose**: Complete audit trail and data fidelity
- **Format**: Exact JSON response from Shopify API
- **Structure**: Minimal transformation, preserve original structure
- **Use Cases**: Debugging, compliance, data recovery

#### Normalized Data Storage
- **Purpose**: Optimized for queries and analytics
- **Format**: Clean, relational structure
- **Structure**: Standardized fields, consistent types
- **Use Cases**: Reporting, business intelligence, API consumption

#### Benefits of this Pattern
1. **Audit Compliance**: Raw data provides complete audit trail
2. **Performance**: Normalized data enables fast queries
3. **Flexibility**: Can re-normalize without re-fetching
4. **Recovery**: Restore from raw if normalization fails
5. **Evolution**: Adapt to API changes without data loss

### 2. Multi-tenant Isolation

Each tenant operates in a secure, isolated environment while sharing infrastructure:

#### Isolation Layers
```
┌─────────────────────────────────────────────────────────────┐
│                    n8n Instance Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Tenant A   │  │  Tenant B   │  │  Tenant C   │         │
│  │ Workflows   │  │ Workflows   │  │ Workflows   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                   Data Storage Layer                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │  Schema A   │  │  Schema B   │  │  Schema C   │         │
│  │ (Isolated)  │  │ (Isolated)  │  │ (Isolated)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

#### Implementation Strategies

1. **Schema-per-Tenant** (Recommended for production)
   - Complete data isolation
   - Easy backup/restore per tenant
   - Simplified security model
   - Resource overhead per tenant

2. **Shared Schema with Tenant ID**
   - Efficient resource usage
   - Requires row-level security
   - Complex query filtering
   - Risk of cross-tenant data access

3. **Hybrid Approach** (Default)
   - Raw data in shared schema with tenant_id
   - Normalized data in tenant-specific schemas
   - Balance of isolation and efficiency

## High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Shopify API   │    │   n8n Platform  │    │   Data Layer    │
│                 │    │                 │    │                 │
│ - REST APIs     │◄──►│ - Workflows     │◄──►│ - PostgreSQL    │
│ - Webhooks      │    │ - Schedulers    │    │ - Raw Tables    │
│ - Bulk APIs     │    │ - Error Handling│    │ - Normalized    │
│ - GraphQL       │    │ - Monitoring    │    │   Tables        │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         │              ┌─────────────────┐              │
         │              │   Observability│              │
         └──────────────►│   & Alerting   │◄─────────────┘
                        │                 │
                        │ - Metrics       │
                        │ - Logs          │
                        │ - Notifications │
                        └─────────────────┘
```

## Data Flow Architecture

### 1. Data Ingestion Flow

```
┌─────────────────────────────────────────────────────────────┐
│                     Data Ingestion                          │
│                                                             │
│  Shopify Event                                             │
│       │                                                    │
│       ▼                                                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │  Webhook    │    │  Scheduled  │    │   Manual    │    │
│  │  Handler    │    │   Sync      │    │   Trigger   │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│         │                   │                   │         │
│         └───────────────────┼───────────────────┘         │
│                             ▼                             │
│                    ┌─────────────┐                        │
│                    │  Validation │                        │
│                    │  & Parsing  │                        │
│                    └─────────────┘                        │
│                             │                             │
│                             ▼                             │
│                    ┌─────────────┐                        │
│                    │  Raw Data   │                        │
│                    │   Storage   │                        │
│                    └─────────────┘                        │
└─────────────────────────────────────────────────────────────┘
```

### 2. Normalization Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                Normalization Pipeline                        │
│                                                             │
│  Raw Tables                                                 │
│       │                                                    │
│       ▼                                                    │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    │
│  │  Data       │    │  Business   │    │  Field      │    │
│  │ Extraction  │───►│  Rules      │───►│  Mapping    │    │
│  └─────────────┘    └─────────────┘    └─────────────┘    │
│                             │                             │
│                             ▼                             │
│                    ┌─────────────┐                        │
│                    │  Data       │                        │
│                    │ Transform   │                        │
│                    └─────────────┘                        │
│                             │                             │
│                             ▼                             │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Normalized Tables                      │ │
│  │  (Optimized for queries and reporting)              │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 3. Multi-tenant Data Flow

```
┌─────────────────────────────────────────────────────────────┐
│                  Multi-tenant Flow                         │
│                                                             │
│  Event Source                                              │
│       │                                                    │
│       ▼                                                    │
│  ┌─────────────┐                                          │
│  │   Tenant    │                                          │
│  │ Identifier  │                                          │
│  └─────────────┘                                          │
│       │                                                    │
│       ▼                                                    │
│  ┌─────────────────────────────────────────────────────┐ │
│  │              Tenant Router                          │ │
│  │  • Route to correct tenant workflows               │ │
│  │  • Apply tenant-specific configurations           │ │
│  │  • Isolate execution context                      │ │
│  └─────────────────────────────────────────────────────┘ │
│       │                                                    │
│       ▼                                                    │
│  ┌─────────────────────────────────────────────────────┐ │
│  │             Tenant-specific Processing             │ │
│  │  • Independent error handling                     │ │
│  │  • Separate rate limiting                        │ │
│  │  • Custom business rules                         │ │
│  └─────────────────────────────────────────────────────┘ │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐ │
│  │            Isolated Data Storage                    │ │
│  │  • Separate schemas or row-level security         │ │
│  │  • Tenant-specific indexes                       │ │
│  │  • Independent backup/restore                   │ │
│  └─────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## Workflow Architecture

### Workflow Categories

#### 1. Data Collection Workflows

**Scheduled Sync Workflows**
```json
{
  "type": "scheduled_sync",
  "trigger": {
    "type": "cron",
    "schedule": "*/15 * * * *"
  },
  "purpose": "Periodic polling for new/updated data",
  "characteristics": [
    "Rate limiting aware",
    "Incremental fetching",
    "Checkpoint tracking",
    "Error recovery"
  ],
  "components": [
    "Date range calculation",
    "API pagination handling",
    "Rate limit management",
    "Bulk data storage",
    "Progress tracking"
  ]
}
```

**Webhook Handler Workflows**
```json
{
  "type": "webhook_handler",
  "trigger": {
    "type": "webhook",
    "events": ["order/create", "order/update", "product/update"]
  },
  "purpose": "Real-time event processing",
  "characteristics": [
    "Low latency",
    "Immediate acknowledgment",
    "Event deduplication",
    "Asynchronous processing"
  ],
  "components": [
    "HMAC verification",
    "Event routing",
    "Immediate storage",
    "Processing queue",
    "Acknowledgment response"
  ]
}
```

#### 2. Data Processing Workflows

**Normalization Workflows**
```json
{
  "type": "normalization",
  "trigger": {
    "type": "data_available",
    "source": "raw_tables"
  },
  "purpose": "Transform raw data to normalized schema",
  "characteristics": [
    "Idempotent",
    "Batch optimized",
    "Incremental updates",
    "Data validation"
  ],
  "components": [
    "Schema mapping",
    "Type conversion",
    "Business rule application",
    "Relationship resolution",
    "Validation checks"
  ]
}
```

**Business Logic Workflows**
```json
{
  "type": "business_logic",
  "trigger": {
    "type": "data_normalized"
  },
  "purpose": "Apply tenant-specific business rules",
  "characteristics": [
    "Configurable",
    "Tenant-aware",
    "Rule engine",
    "Audit logging"
  ],
  "components": [
    "Rule evaluation",
    "Condition checking",
    "Action execution",
    "Result storage",
    "Audit trail"
  ]
}
```

#### 3. Support Workflows

**Error Handling Workflows**
```json
{
  "type": "error_handler",
  "trigger": {
    "type": "error",
    "source": "any_workflow"
  },
  "purpose": "Manage errors and retries",
  "characteristics": [
    "Error classification",
    "Retry logic",
    "Escalation",
    "Recovery procedures"
  ],
  "components": [
    "Error analysis",
    "Retry calculation",
    "Notification sending",
    "Quarantine management",
    "Manual intervention"
  ]
}
```

### Workflow Patterns

#### 1. Fan-out/Fan-in Pattern
```
Event Source
     │
     ▼
┌─────────────┐
│   Router    │
└─────────────┘
     │
┌────┴────┐
│         │
▼         ▼
Processor 1  Processor 2
│         │
└────┬────┘
     │
     ▼
┌─────────────┐
│  Aggregator │
└─────────────┘
```

#### 2. Circuit Breaker Pattern
```
API Call
   │
   ▼
┌─────────────┐
│  Circuit    │◄─── Failures ────┐
│  Breaker    │                  │
└─────────────┘                  │
     │                         │
     ▼                         │
┌─────────────┐                 │
│   Request   │                 │
└─────────────┘                 │
     │                         │
     ▼                         │
┌─────────────┐                 │
│  Response   │                 │
└─────────────┘                 │
     │                         │
     └─────────┐ Success ──────┘
               │
               ▼
        Reset Circuit
```

#### 3. Idempotent Processing Pattern
```
Event ID
    │
    ▼
┌─────────────┐
│   Check     │
│  Processed  │
└─────────────┘
    │
    ├─── Yes ───► Skip
    │
    └─── No ────► Process
```

## Database Architecture

### Schema Design Philosophy

#### Raw Tables Design
```sql
-- Store exact API responses with minimal changes
CREATE TABLE shopify_orders_raw (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(50) NOT NULL,
    shopify_order_id BIGINT NOT NULL,
    shopify_order_number VARCHAR(32),
    raw_data JSONB NOT NULL,
    received_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    processed_at TIMESTAMP WITH TIME ZONE,
    source VARCHAR(20) NOT NULL, -- 'webhook', 'scheduled', 'manual'
    event_type VARCHAR(50),
    version VARCHAR(20) DEFAULT 'v1',

    CONSTRAINT uq_tenant_order UNIQUE(tenant_id, shopify_order_id)
);

-- Indexes for efficient querying
CREATE INDEX idx_raw_tenant_received ON shopify_orders_raw(tenant_id, received_at);
CREATE INDEX idx_raw_processed ON shopify_orders_raw(processed_at) WHERE processed_at IS NULL;
CREATE INDEX idx_raw_shopify_id ON shopify_orders_raw(shopify_order_id);
```

#### Normalized Tables Design
```sql
-- Optimized for queries and analytics
CREATE TABLE shopify_orders (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(50) NOT NULL,
    shopify_order_id BIGINT NOT NULL,
    order_number BIGINT NOT NULL,
    customer_id BIGINT,
    customer_email VARCHAR(255),
    financial_status VARCHAR(50),
    fulfillment_status VARCHAR(50),
    total_price DECIMAL(10,2),
    subtotal_price DECIMAL(10,2),
    tax_price DECIMAL(10,2),
    shipping_price DECIMAL(10,2),
    currency VARCHAR(3),
    created_at TIMESTAMP WITH TIME ZONE NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE NOT NULL,
    processed_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),

    CONSTRAINT uq_tenant_order_norm UNIQUE(tenant_id, shopify_order_id)
);

-- Optimized indexes
CREATE INDEX idx_orders_tenant_date ON shopify_orders(tenant_id, created_at);
CREATE INDEX idx_orders_customer ON shopify_orders(tenant_id, customer_id);
CREATE INDEX idx_orders_status ON shopify_orders(tenant_id, financial_status, fulfillment_status);
CREATE INDEX idx_orders_email ON shopify_orders(customer_email);
```

### Multi-tenant Implementation

#### Option 1: Schema-per-Tenant (Production Recommended)
```sql
-- Create schemas for each tenant
CREATE SCHEMA tenant_001;
CREATE SCHEMA tenant_002;

-- Create tables in each schema
CREATE TABLE tenant_001.shopify_orders (
    -- Same structure as normalized table, but without tenant_id
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    shopify_order_id BIGINT NOT NULL,
    -- ... other fields
);

-- Grant permissions per tenant
GRANT USAGE ON SCHEMA tenant_001 TO tenant_001_user;
GRANT ALL ON ALL TABLES IN SCHEMA tenant_001 TO tenant_001_user;
```

#### Option 2: Shared Schema with Row-Level Security
```sql
-- Create shared normalized tables
CREATE TABLE shopify_orders_shared (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id VARCHAR(50) NOT NULL,
    -- ... other fields
);

-- Enable Row Level Security
ALTER TABLE shopify_orders_shared ENABLE ROW LEVEL SECURITY;

-- Create policy for each tenant
CREATE POLICY tenant_001_policy ON shopify_orders_shared
    FOR ALL TO tenant_001_user
    USING (tenant_id = 'tenant_001');
```

### Data Relationship Model

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│  shopify_orders │─────│shopify_customers│─────│shopify_addresses│
│                 │     │                 │     │                 │
│ • id            │     │ • id            │     │ • id            │
│ • shopify_id    │     │ • shopify_id    │     │ • customer_id   │
│ • customer_id   │◄────│ • email         │     │ • type          │
│ • total_price   │     │ • first_name    │     │ • address1      │
│ • status        │     │ • last_name     │     │ • city          │
│ • created_at    │     │ • phone         │     │ • province      │
└─────────────────┘     └─────────────────┘     │ • country       │
         │                      │              │ • postal_code   │
         │                      │              └─────────────────┘
         ▼                      ▼
┌─────────────────┐     ┌─────────────────┐
│shopify_order_   │     │shopify_customer │
│lines            │     │_tags            │
│                 │     │                 │
│ • id            │     │ • id            │
│ • order_id      │     │ • customer_id   │
│ • product_id    │     │ • tag           │
│ • variant_id    │     └─────────────────┘
│ • quantity      │              │
│ • price         │              ▼
└─────────────────┘     ┌─────────────────┐
         │              │shopify_customer │
         │              │_segments        │
         ▼              │                 │
┌─────────────────┐     │ • id            │
│ shopify_products│     │ • customer_id   │
│                 │     │ • segment       │
│ • id            │     └─────────────────┘
│ • shopify_id    │
│ • title         │
│ • vendor        │
│ • product_type  │
│ • created_at    │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│shopify_variants │
│                 │
│ • id            │
│ • product_id    │
│ • sku           │
│ • price         │
│ • inventory_id  │
│ • created_at    │
└─────────────────┘
         │
         ▼
┌─────────────────┐
│shopify_inventory│
│                 │
│ • id            │
│ • variant_id    │
│ • quantity      │
│ • location_id   │
│ • updated_at    │
└─────────────────┘
```

## API Integration Architecture

### Shopify API Strategy

#### Rate Limiting Implementation
```javascript
class ShopifyRateLimiter {
    constructor() {
        this.bucket = {
            size: 40,        // Shopify's burst limit
            refillRate: 2,   // Requests per second
            current: 40,     // Current tokens
            lastRefill: Date.now()
        };
    }

    async execute(request) {
        await this.waitForToken();

        try {
            const response = await this.makeRequest(request);

            // Check remaining calls from response headers
            const remaining = parseInt(response.headers['x-shopify-shop-api-call-limit']);
            this.updateBucket(remaining);

            return response;
        } catch (error) {
            if (error.status === 429) {
                await this.handleRateLimit(error);
                return this.execute(request);
            }
            throw error;
        }
    }

    async waitForToken() {
        this.refill();

        while (this.bucket.current <= 0) {
            await this.sleep(1000);
            this.refill();
        }

        this.bucket.current--;
    }

    refill() {
        const now = Date.now();
        const elapsed = (now - this.lastRefill) / 1000;
        const tokensToAdd = Math.floor(elapsed * this.refillRate);

        this.bucket.current = Math.min(
            this.bucket.size,
            this.bucket.current + tokensToAdd
        );
        this.lastRefill = now;
    }
}
```

#### Authentication & Security
```javascript
class ShopifyAuth {
    constructor(config) {
        this.accessToken = config.accessToken;
        this.storeUrl = config.storeUrl;
        this.webhookSecret = config.webhookSecret;
    }

    // API request authentication
    getAuthHeaders() {
        return {
            'X-Shopify-Access-Token': this.accessToken,
            'Content-Type': 'application/json',
            'User-Agent': 'n8n-shopify-library/2.0.0'
        };
    }

    // Webhook verification
    verifyWebhook(body, hmacHeader) {
        const hmac = crypto
            .createHmac('sha256', this.webhookSecret)
            .update(body, 'utf8')
            .digest('base64');

        return crypto.timingSafeEqual(
            Buffer.from(hmac),
            Buffer.from(hmacHeader)
        );
    }

    // Token rotation
    async rotateToken(newToken) {
        // Validate new token
        await this.validateToken(newToken);

        // Update configuration
        this.accessToken = newToken;

        // Log rotation
        logger.info('Access token rotated', {
            timestamp: new Date().toISOString(),
            tokenPrefix: newToken.substring(0, 10)
        });
    }
}
```

## Error Handling & Resilience

### Error Classification System

#### Error Categories
```javascript
const ErrorCategories = {
    TRANSIENT: {
        examples: ['Network timeout', 'Rate limit', '5xx errors'],
        strategy: 'Retry with exponential backoff',
        maxRetries: 5,
        baseDelay: 1000
    },

    CONFIGURATION: {
        examples: ['Invalid credentials', 'Missing permissions'],
        strategy: 'Fail fast, notify admin',
        maxRetries: 0,
        requiresManualIntervention: true
    },

    BUSINESS_LOGIC: {
        examples: ['Validation failure', 'Rule violation'],
        strategy: 'Log error, continue processing',
        maxRetries: 0,
        requiresReview: true
    },

    PERMANENT: {
        examples: ['4xx errors', 'Invalid data format'],
        strategy: 'Quarantine data, notify',
        maxRetries: 0,
        quarantineData: true
    }
};
```

#### Error Handler Implementation
```javascript
class ErrorHandler {
    constructor(context) {
        this.context = context;
        this.metrics = new MetricsCollector();
    }

    async handle(error, context) {
        // Classify error
        const category = this.classifyError(error);

        // Log with full context
        await this.logError(error, context, category);

        // Update metrics
        this.metrics.increment(`errors.${category.toLowerCase()}`);

        // Handle based on category
        switch (category) {
            case ErrorCategories.TRANSIENT:
                return this.handleTransient(error, context);

            case ErrorCategories.CONFIGURATION:
                return this.handleConfiguration(error, context);

            case ErrorCategories.BUSINESS_LOGIC:
                return this.handleBusinessLogic(error, context);

            case ErrorCategories.PERMANENT:
                return this.handlePermanent(error, context);
        }
    }

    async handleTransient(error, context) {
        const retryCount = context.retryCount || 0;
        const maxRetries = ErrorCategories.TRANSIENT.maxRetries;

        if (retryCount >= maxRetries) {
            await this.escalateError(error, context, 'MAX_RETRIES_EXCEEDED');
            return { status: 'failed', reason: 'Max retries exceeded' };
        }

        const delay = this.calculateBackoff(retryCount);

        return {
            status: 'retry',
            delay: delay,
            retryCount: retryCount + 1
        };
    }

    calculateBackoff(attempt) {
        const baseDelay = ErrorCategories.TRANSIENT.baseDelay;
        const maxDelay = 60000; // 1 minute

        // Exponential backoff with jitter
        const exponentialDelay = baseDelay * Math.pow(2, attempt);
        const jitter = Math.random() * 1000;

        return Math.min(exponentialDelay + jitter, maxDelay);
    }
}
```

## Monitoring & Observability

### Metrics Collection Strategy

#### Core Metrics
```javascript
class MetricsCollector {
    constructor() {
        this.counters = {
            apiRequests: new Counter(),
            successfulSyncs: new Counter(),
            failedSyncs: new Counter(),
            webhooksReceived: new Counter(),
            errorsByType: new Counter(['type', 'tenant'])
        };

        this.gauges = {
            apiRateLimitRemaining: new Gauge(),
            queueSize: new Gauge(['tenant']),
            processingLatency: new Gauge(['operation']),
            lastSuccessfulSync: new Gauge(['tenant'])
        };

        this.histograms = {
            orderValue: new Histogram(['tenant', 'currency']),
            syncDuration: new Histogram(['entity', 'tenant']),
            apiResponseTime: new Histogram(['endpoint', 'method'])
        };
    }

    recordApiCall(endpoint, method, responseTime, remainingLimit) {
        this.counters.apiRequests.inc();
        this.histograms.apiResponseTime.observe(
            { endpoint, method },
            responseTime
        );
        this.gauges.apiRateLimitRemaining.set(remainingLimit);
    }

    recordSync(entity, tenant, duration, recordCount, success) {
        this.histograms.syncDuration.observe(
            { entity, tenant },
            duration
        );

        if (success) {
            this.counters.successfulSyncs.inc({ tenant });
            this.gauges.lastSuccessfulSync.set(
                { tenant },
                Date.now() / 1000
            );
        } else {
            this.counters.failedSyncs.inc({ tenant });
        }
    }
}
```

#### Alerting Rules
```yaml
alerting_rules:
  high_error_rate:
    condition: |
      rate(errors_total[5m]) > 0.05
    duration: 5m
    labels:
      severity: warning
    annotations:
      summary: "High error rate detected"
      description: "Error rate is {{ $value }} errors per second"

  api_rate_limit_exhausted:
    condition: |
      shopify_api_rate_limit_remaining < 5
    duration: 1m
    labels:
      severity: critical
    annotations:
      summary: "Shopify API rate limit nearly exhausted"
      description: "Only {{ $value }} API calls remaining"

  sync_delay:
    condition: |
      time() - last_successful_sync_timestamp > 1800
    duration: 10m
    labels:
      severity: warning
    annotations:
      summary: "Sync delay detected"
      description: "No successful sync in 30 minutes"

  queue_backlog:
    condition: |
      queue_size > 1000
    duration: 5m
    labels:
      severity: critical
    annotations:
      summary: "Queue backlog growing"
      description: "{{ $value }} items in queue"
```

### Logging Strategy

#### Structured Logging Format
```javascript
const logEntry = {
    timestamp: new Date().toISOString(),
    level: 'info',
    tenant: 'tenant_001',
    workflow: 'order_sync',
    executionId: 'exec_12345',
    correlationId: 'corr_67890',
    message: 'Order processed successfully',
    data: {
        orderId: '12345',
        orderValue: 99.99,
        processingTime: 1250
    },
    tags: ['orders', 'sync', 'success']
};
```

#### Log Levels and Usage
- **DEBUG**: Detailed flow tracing, API request/response bodies
- **INFO**: Normal operations, successful completions
- **WARN**: Recoverable errors, rate limit warnings
- **ERROR**: Failed operations, exceptions
- **FATAL**: System-level failures, requires immediate attention

## Security Architecture

### Security Layers

#### 1. Network Security
```yaml
network_security:
  ip_whitelist:
    - description: "Shopify webhook IPs"
      ranges: ["23.227.38.64/27", "23.227.38.128/27"]

  tls_configuration:
    version: "1.3"
    ciphers: ["TLS_AES_256_GCM_SHA384"]
    certificates:
      type: "managed"
      auto_renewal: true
```

#### 2. Application Security
```javascript
class ApplicationSecurity {
    constructor() {
        this.csrfTokens = new Map();
        this.sessionStore = new RedisStore();
    }

    // Input validation
    validateInput(data, schema) {
        const validation = Joi.validate(data, schema);
        if (validation.error) {
            throw new ValidationError(validation.error);
        }
        return validation.value;
    }

    // SQL injection prevention
    buildQuery(tenantId, params) {
        // Use parameterized queries
        return {
            text: 'SELECT * FROM shopify_orders WHERE tenant_id = $1 AND id = $2',
            values: [tenantId, params.id]
        };
    }

    // XSS prevention
    sanitizeHtml(input) {
        return DOMPurify.sanitize(input, {
            ALLOWED_TAGS: [],
            ALLOWED_ATTR: []
        });
    }
}
```

#### 3. Data Encryption
```javascript
class DataEncryption {
    constructor(keyId) {
        this.keyId = keyId;
        this.kms = new AWS.KMS();
    }

    async encryptSensitiveData(data) {
        const response = await this.kms.encrypt({
            KeyId: this.keyId,
            Plaintext: JSON.stringify(data)
        }).promise();

        return response.CiphertextBlob.toString('base64');
    }

    async decryptSensitiveData(encryptedData) {
        const response = await this.kms.decrypt({
            CiphertextBlob: Buffer.from(encryptedData, 'base64')
        }).promise();

        return JSON.parse(response.Plaintext.toString());
    }
}
```

## Performance Optimization

### Optimization Strategies

#### 1. Database Optimization
```sql
-- Partitioning for large tables
CREATE TABLE shopify_orders_partitioned (
    LIKE shopify_orders INCLUDING ALL
) PARTITION BY RANGE (created_at);

-- Monthly partitions
CREATE TABLE shopify_orders_2024_01
    PARTITION OF shopify_orders_partitioned
    FOR VALUES FROM ('2024-01-01') TO ('2024-02-01');

-- Materialized views for reporting
CREATE MATERIALIZED VIEW monthly_order_summary AS
SELECT
    tenant_id,
    DATE_TRUNC('month', created_at) as month,
    COUNT(*) as order_count,
    SUM(total_price) as total_revenue,
    AVG(total_price) as avg_order_value
FROM shopify_orders
GROUP BY tenant_id, DATE_TRUNC('month', created_at);

-- Refresh strategy
CREATE OR REPLACE FUNCTION refresh_monthly_summary()
RETURNS void AS $$
BEGIN
    REFRESH MATERIALIZED VIEW CONCURRENTLY monthly_order_summary;
END;
$$ LANGUAGE plpgsql;
```

#### 2. Caching Strategy
```javascript
class CacheManager {
    constructor() {
        this.redis = new Redis(process.env.REDIS_URL);
        this.localCache = new LRU({ max: 1000 });
    }

    async get(key, fetchFn, options = {}) {
        const { ttl = 3600, useLocal = true } = options;

        // Try local cache first
        if (useLocal) {
            const local = this.localCache.get(key);
            if (local) return local;
        }

        // Try Redis
        const cached = await this.redis.get(key);
        if (cached) {
            const data = JSON.parse(cached);
            if (useLocal) {
                this.localCache.set(key, data);
            }
            return data;
        }

        // Fetch and cache
        const data = await fetchFn();
        await this.set(key, data, { ttl, useLocal });

        return data;
    }

    async set(key, data, options = {}) {
        const { ttl = 3600, useLocal = true } = options;

        if (useLocal) {
            this.localCache.set(key, data);
        }

        await this.redis.setex(
            key,
            ttl,
            JSON.stringify(data)
        );
    }
}
```

#### 3. Batch Processing
```javascript
class BatchProcessor {
    constructor(options = {}) {
        this.batchSize = options.batchSize || 100;
        this.maxConcurrency = options.maxConcurrency || 5;
    }

    async processBatch(items, processor) {
        const batches = this.createBatches(items, this.batchSize);
        const semaphore = new Semaphore(this.maxConcurrency);

        const results = await Promise.all(
            batches.map(async (batch) => {
                await semaphore.acquire();
                try {
                    return await processor(batch);
                } finally {
                    semaphore.release();
                }
            })
        );

        return results.flat();
    }

    createBatches(items, size) {
        const batches = [];
        for (let i = 0; i < items.length; i += size) {
            batches.push(items.slice(i, i + size));
        }
        return batches;
    }
}
```

## Deployment Architecture

### Container-based Deployment
```yaml
# docker-compose.yml
version: '3.8'
services:
  n8n:
    image: n8nio/n8n:latest
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}
      - WEBHOOK_URL=https://${DOMAIN}/
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=postgres
      - DB_POSTGRESDB_PORT=5432
      - DB_POSTGRESDB_DATABASE=n8n
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}
      - N8N_LOG_LEVEL=info
      - N8N_METRICS=true
    volumes:
      - ./flows:/home/node/.n8n/workflows
      - ./config:/home/node/.n8n/config
      - n8n_data:/home/node/.n8n
    ports:
      - "5678:5678"
    depends_on:
      - postgres
      - redis
    restart: unless-stopped

  postgres:
    image: postgres:14-alpine
    environment:
      - POSTGRES_USER=${DB_USER}
      - POSTGRES_PASSWORD=${DB_PASSWORD}
      - POSTGRES_DB=n8n
    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql
    ports:
      - "5432:5432"
    restart: unless-stopped

  redis:
    image: redis:7-alpine
    command: redis-server --appendonly yes --requirepass ${REDIS_PASSWORD}
    volumes:
      - redis_data:/data
    ports:
      - "6379:6379"
    restart: unless-stopped

  nginx:
    image: nginx:alpine
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf
      - ./ssl:/etc/nginx/ssl
    depends_on:
      - n8n
    restart: unless-stopped

volumes:
  n8n_data:
  postgres_data:
  redis_data:
```

### Kubernetes Deployment
```yaml
# k8s-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: n8n-shopify-library
spec:
  replicas: 3
  selector:
    matchLabels:
      app: n8n-shopify-library
  template:
    metadata:
      labels:
        app: n8n-shopify-library
    spec:
      containers:
      - name: n8n
        image: n8nio/n8n:latest
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "2Gi"
            cpu: "2000m"
        env:
        - name: DB_TYPE
          value: "postgresdb"
        - name: DB_POSTGRESDB_HOST
          value: "postgres-service"
        envFrom:
        - secretRef:
            name: n8n-secrets
        volumeMounts:
        - name: workflows
          mountPath: /home/node/.n8n/workflows
        - name: config
          mountPath: /home/node/.n8n/config
      volumes:
      - name: workflows
        configMap:
          name: n8n-workflows
      - name: config
        configMap:
          name: n8n-config
---
apiVersion: v1
kind: Service
metadata:
  name: n8n-service
spec:
  selector:
    app: n8n-shopify-library
  ports:
  - port: 5678
    targetPort: 5678
  type: LoadBalancer
```

## Best Practices & Guidelines

### Development Best Practices

1. **Workflow Design**
   - Keep workflows focused on single responsibilities
   - Use reusable components from `/flows/shopify/shared/`
   - Implement proper error handling at each step
   - Add comprehensive logging and metrics

2. **Data Handling**
   - Always validate data before processing
   - Use parameterized queries to prevent SQL injection
   - Implement proper data sanitization
   - Follow GDPR and other compliance requirements

3. **Security**
   - Never commit credentials to version control
   - Use environment variables for sensitive data
   - Implement proper webhook verification
   - Regular security audits and updates

### Operational Best Practices

1. **Monitoring**
   - Set up comprehensive alerting
   - Monitor key metrics and trends
   - Implement log aggregation and analysis
   - Regular health checks

2. **Performance**
   - Regular performance tuning
   - Monitor resource usage
   - Optimize database queries
   - Implement caching strategies

3. **Backup & Recovery**
   - Regular automated backups
   - Test restore procedures
   - Document disaster recovery plan
   - Implement point-in-time recovery

This architecture provides a robust, scalable foundation for Shopify integrations that can handle enterprise requirements while maintaining flexibility for customization and growth.