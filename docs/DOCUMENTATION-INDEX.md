# Documentation Index

## 📚 Complete Library Documentation

This index provides a comprehensive overview of all documentation available for the n8n Shopify Integration Library.

## 🎯 Quick Start Documentation

### For Immediate Setup
- **[Main README](../README.md)** - Project overview, architecture, and quick start guide
- **[Deployment Guide](./DEPLOYMENT.md)** - Step-by-step deployment instructions
- **[Edge Functions Setup](./EDGE-FUNCTIONS.md)** - Database setup via Edge Functions (recommended)

### For Understanding the Library
- **[Architecture Documentation](./architecture.md)** - Technical design and patterns
- **[Migration Summary](../flows/MIGRATION_SUMMARY.md)** - From monolith to modular transformation

## 📋 In-Depth Documentation

### Database & API
- **[API Reference](./API-REFERENCE.md)** - Complete database schema and query patterns
- **[Database Schema](../supabase/migrations/)** - All migration files with table definitions

### Operations & Maintenance
- **[Troubleshooting Guide](./TROUBLESHOOTING.md)** - Common issues, debugging, and FAQ
- **[CHANGELOG](../CHANGELOG.md)** - Version history, breaking changes, and release notes

### Workflow Documentation
- **[Workflow Guide](../flows/README.md)** - n8n workflow specifics and configuration
- **[Environment Variables](../flows/.env.example)** - Complete configuration template

## 🔧 Development Documentation

### Architecture & Design
- **[Library Architecture](./architecture.md)** - Deep dive into technical decisions and patterns
- **[Multi-Tenant Design](./architecture.md#multi-tenant-implementation)** - Scaling to multiple merchants

### Edge Functions
- **[Edge Functions Guide](./EDGE-FUNCTIONS.md)** - Serverless database operations and automation
- **[Function Code](../supabase/functions/setup-database/index.ts)** - Implementation details

## 📊 Quick Reference

### Database Schema Summary

| Table Type | Tables | Purpose |
|------------|--------|---------|
| **Raw Tables** | `shopify_orders_raw`, `shopify_products_raw` | Complete audit trail |
| **Normalized Tables** | `orders`, `order_lines`, `products`, `product_variants` | Business-ready data |
| **Logging Tables** | `integration_logs`, `sync_log` | Execution tracking |

### Workflow Summary

| Workflow | Purpose | Triggers |
|----------|---------|----------|
| `sync-orchestrator` | Coordinates all sync operations | Cron, Manual |
| `shopify-orders-fetch` | Orders API → Raw table | Scheduled, Manual |
| `orders-transform` | Raw → Normalized orders | Data available |
| `shopify-products-fetch` | Products API → Raw table | Scheduled, Manual |
| `products-transform` | Raw → Normalized products | Data available |

### Environment Variables

| Category | Variables | Required |
|----------|-----------|----------|
| **Multi-tenant** | `MERCHANT_ID`, `SHOP_IDENTIFIER` | ✅ |
| **Shopify API** | `SHOPIFY_ADMIN`, `SHOPIFY_ACCESS_TOKEN` | ✅ |
| **Database** | `SUPABASE_HOST`, `SUPABASE_SERVICE_ROLE_KEY` | ✅ |
| **Sync Config** | `SYNC_INTERVAL_MINUTES`, `SYNC_LOOKBACK_HOURS` | ✅ |
| **Monitoring** | `SLACK_WEBHOOK_URL` | ❌ (optional) |

## 🚀 Setup Checklist

### ✅ Pre-Deployment
- [ ] Supabase project created and linked
- [ ] Shopify Private App with proper scopes
- [ ] n8n instance available (self-hosted or cloud)
- [ ] Environment variables configured

### ✅ Database Setup
- [ ] Run Edge Function setup: `POST /functions/v1/setup-database`
- [ ] Verify all 8 tables created
- [ ] Test database connectivity

### ✅ Workflow Deployment
- [ ] Import 5 modular workflows to n8n
- [ ] Configure n8n credentials
- [ ] Test with manual triggers
- [ ] Enable automated schedules

### ✅ Production Readiness
- [ ] Error monitoring configured
- [ ] Slack notifications working
- [ ] Backup procedures in place
- [ ] Documentation reviewed

## 🔍 Common Use Cases

### 1. First-Time Setup
**Start here:** [Deployment Guide](./DEPLOYMENT.md) → Edge Functions Setup

### 2. Adding New Merchant
**Start here:** Main README → Multi-Tenant Configuration

### 3. Troubleshooting Issues
**Start here:** [Troubleshooting Guide](./TROUBLESHOOTING.md) → Quick Diagnostic

### 4. Understanding Architecture
**Start here:** [Architecture Documentation](./architecture.md) → Design Patterns

### 5. Database Queries
**Start here:** [API Reference](./API-REFERENCE.md) → Query Patterns

### 6. Custom Development
**Start here:** [Edge Functions Guide](./EDGE-FUNCTIONS.md) → Extension Patterns

## 📞 Support & Help

### Self-Service Resources
1. **Search this documentation** - Use Ctrl+F to find specific topics
2. **Check integration_logs table** - Detailed error information
3. **Review n8n execution logs** - Workflow-specific issues
4. **Monitor Slack notifications** - Real-time alerts

### When to Get Help
- Multiple critical failures in 24 hours
- Data corruption suspected
- Performance degradation > 50%
- Security incidents

### Support Request Template
```
Issue: [Brief description]
Environment: [Production/Staging]
Last Working: [Date]
Error Messages: [Exact errors]
Steps Taken: [What you've tried]
Impact: [Business impact]
```

## 📖 Document Updates

### Version Control
- All documentation is version-controlled with the codebase
- Check the [CHANGELOG](../CHANGELOG.md) for recent updates
- Documentation is updated with each release

### Contributing
- Documentation updates are welcome via pull requests
- Follow the existing style and format
- Include examples and code snippets where helpful

## 🔗 Related Resources

### External Documentation
- [n8n Documentation](https://docs.n8n.io/) - Workflow automation platform
- [Supabase Documentation](https://supabase.com/docs) - Database and Edge Functions
- [Shopify API Documentation](https://shopify.dev/docs/admin-api) - REST API reference

### Community Resources
- [n8n Community](https://community.n8n.io/) - User forums and discussions
- [Supabase Discord](https://discord.supabase.com/) - Real-time community support
- [Shopify Forums](https://community.shopify.com/) - Shopify development discussions

## 📋 Documentation Standards

### Format Standards
- **Markdown format** with proper headers and structure
- **Code examples** with syntax highlighting
- **Step-by-step instructions** for procedures
- **Troubleshooting sections** for common issues

### Content Standards
- **Clear, concise language** avoiding jargon where possible
- **Practical examples** and real-world scenarios
- **Complete information** without requiring external resources
- **Consistent terminology** throughout all documents

### Maintenance Standards
- **Regular reviews** for accuracy and relevance
- **Version synchronization** with codebase changes
- **User feedback incorporation** from support tickets
- **Link verification** to prevent broken references

---

## 🎯 Getting Started

**New to the library?** Start with the [Main README](../README.md) for a complete overview.

**Ready to deploy?** Follow the [Deployment Guide](./DEPLOYMENT.md) for step-by-step instructions.

**Need help?** Check the [Troubleshooting Guide](./TROUBLESHOOTING.md) for common issues.

**Want to understand how it works?** Read the [Architecture Documentation](./architecture.md) for technical details.

---

This documentation ecosystem provides everything you need to successfully deploy, operate, and extend the n8n Shopify Integration Library. All documentation is maintained alongside the codebase to ensure accuracy and relevance.