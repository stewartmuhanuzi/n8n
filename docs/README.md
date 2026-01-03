# n8n Shopify Integration Library

A professional, multi-tenant n8n library for integrating Shopify with your backend systems. This library provides a robust, scalable solution for synchronizing orders, products, inventory, and customer data between Shopify and your data warehouse or CRM.

## 🚀 Features

- **Multi-tenant Architecture**: Support for multiple Shopify stores from a single n8n instance
- **Real-time & Scheduled Sync**: Webhook-based real-time updates plus scheduled batch synchronization
- **Data Normalization**: Raw Shopify data is transformed into a clean, standardized schema
- **Business Rules Engine**: Configurable business logic for order processing, inventory management, and pricing
- **Error Handling & Monitoring**: Comprehensive error handling with notifications and retry logic
- **Performance Optimized**: Batch processing, rate limiting, and efficient API usage
- **Compliance Ready**: Built-in support for GDPR, CCPA, and SOX compliance requirements

## 📋 Prerequisites

- n8n instance (cloud or self-hosted)
- Shopify store with Private App access
- PostgreSQL, MySQL, or Supabase database (for normalized data storage)
- Redis (optional but recommended for caching)
- Basic understanding of n8n workflows

## 🛠 Quick Start

### 1. Installation

Clone or download this library to your n8n workflows directory:

```bash
git clone https://github.com/your-org/n8n-shopify-library.git
cd n8n-shopify-library
```

### 2. Configuration

Copy the environment template and configure your credentials:

```bash
cp config/env.template .env
```

Edit `.env` with your Shopify and database credentials:

```env
# Shopify Configuration
SHOPIFY_STORE_URL=your-store.myshopify.com
SHOPIFY_ACCESS_TOKEN=shpat_your_access_token_here
SHOPIFY_API_VERSION=2024-01

# Database Configuration
DB_TYPE=postgresql
DB_HOST=localhost
DB_PORT=5432
DB_NAME=n8n_shopify_lib
DB_USER=postgres
DB_PASSWORD=your_postgres_password

# Multi-tenant Configuration
MERCHANT_ID=merchant-001
MERCHANT_DISPLAY_NAME=Your Store Name
```

### 3. Database Setup

Run the provided SQL schema to create the normalized tables:

```sql
-- Import docs/database-schema.sql into your database
```

### 4. Import Workflows

Import the workflows into n8n:

1. Open n8n interface
2. Go to "Import from file"
3. Import `flows/shopify/orders/order-sync.json`
4. Import `flows/shopify/products/product-sync.json`
5. Import any additional workflows as needed

### 5. Configure Workflows

1. Set up credentials in n8n for each workflow
2. Configure environment variable references
3. Test the connections
4. Activate the workflows

## 📁 Library Structure

```
n8n/
├── flows/
│   ├── shopify/
│   │   ├── orders/         # Order-related workflows
│   │   │   ├── order-sync.json
│   │   │   ├── order-processing.json
│   │   │   └── returns-handling.json
│   │   ├── products/       # Product-related workflows
│   │   │   ├── product-sync.json
│   │   │   ├── inventory-update.json
│   │   │   └── pricing-rules.json
│   │   └── shared/         # Reusable components
│   │       ├── api-auth.json
│   │       ├── error-handler.json
│   │       └── data-transform.json
│   └── templates/          # Starter templates
│       ├── basic-sync.json
│       └── advanced-setup.json
├── config/
│   ├── env.template        # Environment variables template
│   └── business-rules.template.json
├── docs/
│   ├── README.md           # This file
│   ├── architecture.md     # Technical architecture
│   ├── onboarding.md       # New merchant setup guide
│   └── api-reference.md    # API documentation
└── scripts/
    ├── setup.sql           # Database setup script
    └── migrate.sh          # Migration helper script
```

## 🔧 Core Concepts

### Raw + Normalized Pattern

The library follows a "raw + normalized" data pattern:

1. **Raw Data**: Exact copies of Shopify API responses are stored for audit purposes
2. **Normalized Data**: Clean, structured data optimized for reporting and analytics

This approach ensures:
- Complete audit trail
- Easy data recovery
- Optimized query performance
- Flexibility for future changes

### Multi-tenant Design

Each merchant/tenant operates in isolation:
- Separate database schema or tenant isolation
- Independent configurations
- Isolated workflows
- Per-tenant error handling

### Workflow Types

1. **Scheduled Syncs**: Run on intervals to fetch and sync data
2. **Webhook Handlers**: Process real-time events from Shopify
3. **Batch Processors**: Handle large data volumes efficiently
4. **Error Handlers**: Manage failures and retries
5. **Notification Workflows**: Send alerts and reports

## 📊 Data Model

The library creates a normalized schema with these main entities:

- `shopify_orders_raw` & `shopify_orders`: Order data
- `shopify_order_lines_raw` & `shopify_order_lines`: Order line items
- `shopify_products_raw` & `shopify_products`: Product catalog
- `shopify_variants_raw` & `shopify_variants`: Product variants
- `shopify_inventory_raw` & `shopify_inventory`: Inventory levels
- `shopify_customers_raw` & `shopify_customers`: Customer data

## 🔐 Security

- API keys stored in environment variables
- HMAC verification for webhooks
- IP whitelisting support
- Rate limiting implemented
- Access logs for all operations

## 📈 Performance

- Batch processing (configurable size)
- API rate limiting respect
- Efficient database operations
- Background processing for heavy tasks
- Configurable timeouts and retries

## 🔔 Monitoring

- Slack integration for notifications
- Email alerts for critical errors
- Database logging of all operations
- Performance metrics tracking
- Health check endpoints

## 🛠 Customization

### Adding Custom Fields

1. Update the environment variables with your field mappings
2. Modify the data transformation functions in the workflows
3. Update the database schema if needed

### Business Rules

Configure custom business logic through environment variables:
- Order processing rules
- Inventory thresholds
- Pricing strategies
- Customer segmentation

### Custom Workflows

Use the shared components to build custom workflows:
- Import `flows/shopify/shared/api-auth.json` for authentication
- Import `flows/shopify/shared/data-transform.json` for data processing
- Import `flows/shopify/shared/error-handler.json` for error handling

## 🚀 Multi-tenant Setup

For multiple stores:

1. Configure additional stores in your `.env` file:
```env
# Primary store
SHOPIFY_STORE_URL=primary-store.myshopify.com
SHOPIFY_ACCESS_TOKEN=shpat_primary_token

# Additional stores
SHOPIFY_STORE_URL_TENANT_1=tenant1-store.myshopify.com
SHOPIFY_ACCESS_TOKEN_TENANT_1=shpat_tenant1_token

SHOPIFY_STORE_URL_TENANT_2=tenant2-store.myshopify.com
SHOPIFY_ACCESS_TOKEN_TENANT_2=shpat_tenant2_token
```

2. Set up separate workflows for each tenant or use a master workflow with tenant routing

3. Configure tenant-specific database isolation if needed

## 🤝 Support

- **Documentation**: Check the `/docs` folder for detailed guides
- **Architecture Guide**: See `docs/architecture.md` for technical details
- **Issues**: Report bugs on GitHub Issues
- **Community**: Join our Discord community
- **Enterprise**: Contact sales@yourcompany.com for enterprise support

## 📄 License

MIT License - see LICENSE file for details.

## 🔄 Version History

- **v2.0.0**: Multi-tenant support, business rules engine, enhanced monitoring
- **v1.5.0**: Webhook support, real-time sync
- **v1.0.0**: Initial release with basic sync functionality

---

## Quick Reference

### Environment Variables (Required)
- `SHOPIFY_STORE_URL`: Your Shopify store URL
- `SHOPIFY_ACCESS_TOKEN`: Shopify private app access token
- `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD`: Database connection
- `MERCHANT_ID`: Unique identifier for your tenant

### Key Files
- `/config/env.template`: Environment configuration template
- `/flows/shopify/`: Core workflow templates
- `/docs/architecture.md`: Technical architecture details

**Happy Integrating!** 🚀