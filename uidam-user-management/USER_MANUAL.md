# UIDAM User Management - User Manual

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Configuration Guide](#configuration-guide)
4. [Multi-Tenant Configuration](#multi-tenant-configuration)
5. [Security & Secrets Management](#security--secrets-management)
6. [Database Configuration](#database-configuration)
7. [Notification Configuration](#notification-configuration)
8. [Password Policy Configuration](#password-policy-configuration)
9. [Monitoring & Metrics](#monitoring--metrics)
10. [Deployment](#deployment)
11. [Troubleshooting](#troubleshooting)

---

## Overview

The UIDAM User Management service provides comprehensive user lifecycle management, including user creation, authentication, password management, role assignment, and event tracking. It integrates with the Authorization Server for OAuth2/OIDC token management.

### Key Features
- User CRUD operations
- Password policy enforcement
- Multi-tenant user isolation
- Email notifications (password recovery, verification)
- User event tracking and audit logs
- Role-based access control
- Account lifecycle management
- Self-service user registration
- Password recovery workflows
- Oauth2 client management
---

## Prerequisites

Before deploying the UIDAM User Management service, ensure you have:

1. **Kubernetes Cluster** (v1.19+)
2. **Helm** (v3.0+)
3. **PostgreSQL Database** (v12+)
4. **SMTP Server** (for email notifications)
5. **UIDAM Authorization Server** (deployed and accessible)

---

## Configuration Guide

### Basic Configuration (`values.yaml`)

#### 1. Image Configuration

```yaml
image:
  repository: docker.io/eclipseecsp/uidam-user-management
  pullPolicy: IfNotPresent
  tag: 1.2.3
```

**Action Required:**
- Update `repository` to your container registry
- Update `tag` to the desired version
- Ensure tag matches authorization server version for compatibility

#### 2. Resource Configuration

```yaml
resources:
  limits:
    cpu: 2000m
    memory: 2Gi
  requests:
    cpu: 500m
    memory: 512Mi
```

**Action Required:**
- Adjust CPU and memory based on expected user load
- Recommended minimum for production: 1Gi memory, 500m CPU
- For high user activity (1000+ concurrent): 2Gi memory, 1000m CPU

#### 3. Java Options

```yaml
javaOpts: -Xms128m -Xmx512m -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxMetaspaceSize=256m
```

**Action Required:**
- Adjust heap size (`-Xmx`) based on available resources
- Ensure `-Xmx` is 70-80% of container memory limit
- For 2Gi container: `-Xmx1536m`
- For 1Gi container: `-Xmx768m`

---

## Multi-Tenant Configuration

### Enable Multi-Tenancy

```yaml
multiTenant:
  tenantIds: "ecsp,sdp"
  defaultTenant: "ecsp"
  enabled: false  # Set to true to enable
```

**Action Required:**
1. Set `enabled: true` to activate multi-tenant mode
2. Update `tenantIds` with comma-separated tenant identifiers
3. Set `defaultTenant` to the primary tenant ID
4. **Important:** Tenant IDs must match those configured in Authorization Server

### Tenant-Specific Configuration

Each tenant requires a complete configuration block:

```yaml
multiTenant:
  tenants:
    ecsp:  # Tenant ID (must match tenantIds list and Auth Server)
      tenantId: "ecsp"
      tenantName: "ECSP"
```

#### Account Configuration

```yaml
account:
  accountId: "TO-BE-UPDATED"           # Unique account identifier
  accountName: "ecsp"                   # Account display name
  accountType: "Root"                   # Root, Sub, Child, etc.
  accountFieldEnabled: true             # Enable account field in user records
```

**Action Required:**
- Generate unique `accountId` for each tenant (UUID recommended)
- Use same `accountId` as configured in Authorization Server
- Set descriptive `accountName`
- Configure `accountType` based on your account hierarchy
  - `Root`: Top-level tenant
  - `Sub`: Sub-tenant of root
  - `Child`: Child tenant

#### User Configuration

```yaml
user:
  defaultStatus: "ACTIVE"               # Initial status for new users
  defaultRole: "VEHICLE_OWNER"          # Default role assignment
  permittedRoles: "VEHICLE_OWNER,ADMIN" # Comma-separated allowed roles
  maxAllowedLoginAttempts: "3"          # Account lock threshold
  signUpEnabled: "true"                 # Enable self-registration
  statusLifeCycleEnabled: "false"       # Enable status transitions
```

**Action Required:**

1. **defaultStatus:**
   - `ACTIVE`: Users can login immediately (recommended for internal users)
   - `PENDING`: Requires verification (recommended for self-registration)
   - `INACTIVE`: User exists but cannot login

2. **defaultRole:**
   - Define based on your application
   - Examples: `USER`, `VEHICLE_OWNER`, `CUSTOMER`, `MEMBER`
   - Must match roles defined in Authorization Server

3. **permittedRoles:**
   - List all roles that can be assigned to users
   - Comma-separated, no spaces
   - Examples: `VEHICLE_OWNER,FLEET_MANAGER,ADMIN,SUPPORT`

4. **maxAllowedLoginAttempts:**
   - Brute-force protection
   - Recommended: 3-5 attempts
   - Set to "0" to disable account locking

5. **signUpEnabled:**
   - `true`: Allow public user registration
   - `false`: Admin-only user creation

6. **statusLifeCycleEnabled:**
   - `true`: Enable automatic status transitions (e.g., PENDING → ACTIVE)
   - `false`: Manual status management only

#### Static Password Policy Configuration

```yaml
password:
  minLength: "10"                       # Minimum password length
  maxLength: "15"                       # Maximum password length
  updateTimeInterval: "1"               # Password expiry (days)
  policyCheckEnabled: "true"            # Enable password policy
```

**Action Required:**

1. **Password Length:**
   - Minimum recommended: 8-12 characters
   - Maximum recommended: 64 characters
   - Balance security with usability

2. **updateTimeInterval:**
   - Password expiry period in days
   - `0`: Never expires
   - `90`: Industry standard for sensitive applications
   - `180`: Common for internal applications
   - `365`: Minimum for compliance

3. **policyCheckEnabled:**
   - `true`: Enforce complexity rules (recommended)
   - Password must contain:
     - Uppercase letter
     - Lowercase letter
     - Number
     - Special character

**Example Password Policies by Use Case:**

| Use Case | minLength | maxLength | updateTimeInterval | policyCheckEnabled |
|----------|-----------|-----------|-------------------|-------------------|
| High Security | 12 | 64 | 90 | true |
| Standard | 10 | 64 | 180 | true |
| Low Risk | 8 | 64 | 365 | true |
| Development | 6 | 64 | 0 | false |

#### External URLs Configuration

```yaml
externalUrls:
  authorizationServerUrl: "http://uidam-authorization-server:9000"
  tokenEndpoint: "/oauth2/token"
  revokeTokenEndpoint: "/revoke/revokeByAdmin"
```

**Action Required:**
- Update `authorizationServerUrl` if using:
  - External URL: `https://auth.yourdomain.com`
  - Different namespace: `http://uidam-authorization-server.uidam-system:9000`
  - Different port: Check service configuration
- Keep endpoint paths unless Authorization Server API is customized

#### Notification Configuration

```yaml
notification:
  enabled: "true"                       # Enable email notifications
  email:
    fromAddress: "noreply@example.com"  # Sender email address
    fromName: "UIDAM System"            # Sender display name
    host: "smtp.example.com"            # SMTP server hostname
    port: "587"                         # SMTP port
    protocol: "smtp"                    # Protocol: smtp or smtps
    auth: "true"                        # Enable SMTP authentication
    starttls: "true"                    # Enable STARTTLS
    sslEnabled: "false"                 # Enable SSL/TLS
```

**Action Required:**

1. **SMTP Server Configuration:**

   **For Gmail:**
   ```yaml
   host: "smtp.gmail.com"
   port: "587"
   protocol: "smtp"
   auth: "true"
   starttls: "true"
   sslEnabled: "false"
   ```
   - Enable "Less secure app access" OR use App Password
   - Store credentials in secrets

   **For AWS SES:**
   ```yaml
   host: "email-smtp.us-east-1.amazonaws.com"
   port: "587"
   protocol: "smtp"
   auth: "true"
   starttls: "true"
   sslEnabled: "false"
   ```
   - Create SMTP credentials in SES console
   - Verify sender email address

   **For SendGrid:**
   ```yaml
   host: "smtp.sendgrid.net"
   port: "587"
   protocol: "smtp"
   auth: "true"
   starttls: "true"
   sslEnabled: "false"
   ```
   - Username: "apikey"
   - Password: Your SendGrid API Key

   **For Office 365:**
   ```yaml
   host: "smtp.office365.com"
   port: "587"
   protocol: "smtp"
   auth: "true"
   starttls: "true"
   sslEnabled: "false"
   ```

2. **From Address:**
   - Must be verified/owned by your organization
   - Use no-reply address for system emails
   - Examples: `noreply@yourdomain.com`, `system@yourdomain.com`

3. **Port Selection:**
   - `25`: Standard SMTP (often blocked by ISPs)
   - `587`: SMTP with STARTTLS (recommended)
   - `465`: SMTPS (SMTP over SSL)
   - `2525`: Alternative port (some providers)

#### Database Configuration (Per Tenant)

```yaml
database:
  jdbcUrl: "jdbc:postgresql://postgresql:5432/ecsp_db"
  schemaName: "uidam"
```

**Action Required:**
- Create separate database for each tenant
- Update JDBC URL: `jdbc:postgresql://HOST:PORT/DATABASE_NAME`
- Create schema: Schema name must match `schemaName` field
- Grant permissions to database user

**Database Setup Example:**
```sql
-- Create tenant database
CREATE DATABASE ecsp_db;

-- Connect to database
\c ecsp_db;

-- Create schema
CREATE SCHEMA uidam;

-- Grant permissions
GRANT ALL ON SCHEMA uidam TO uidam_user;
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA uidam TO uidam_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA uidam TO uidam_user;
```

---

## Security & Secrets Management

### Global Secrets

These secrets are used for encryption and token management:

```yaml
secrets:
  clientsecretkey: "ChangeMe"
  clientsecretsalt: "ChangeMe"
  revokeTokenClientSecret: "ChangeMe"
  smtp_username: "ChangeMe"
  smtp_password: "ChangeMe"
  liquibase_clientsecret: "ChangeMe"
  liquibase_userpwd: "ChangeMe"
  liquibase_usersalt: "ChangeMe"
```

**Action Required:**

1. **clientsecretkey:**
   - Key for encrypting OAuth2 client secrets
   - Must match value in Authorization Server
   - Generate: `openssl rand -base64 32`
   - Length: 32+ characters

2. **clientsecretsalt:**
   - Salt for client secret hashing
   - Must match value in Authorization Server
   - Generate: `openssl rand -base64 16`
   - Length: 16+ characters

3. **revokeTokenClientSecret:**
   - Secret for token revocation client
   - Used when calling Authorization Server revoke endpoint
   - Generate: `openssl rand -base64 24`
   - Length: 24+ characters

4. **smtp_username:**
   - SMTP authentication username
   - Usually your email address for Gmail/O365
   - For AWS SES: SMTP username from credentials
   - For SendGrid: "apikey"

5. **smtp_password:**
   - SMTP authentication password
   - For Gmail: App Password (not account password)
   - For AWS SES: SMTP password from credentials
   - For SendGrid: API Key
   - Never use plain account passwords

6. **Liquibase Secrets:**
   - Used for database migration initial data seeding
   
   **liquibase_clientsecret:**
   - Default client secret for migration-created clients
   - Generate: `openssl rand -base64 24`
   
   **liquibase_userpwd:**
   - Default password for migration-created users
   - Generate strong password
   - Should be changed on first login
   
   **liquibase_usersalt:**
   - Salt for user password hashing
   - Generate: `openssl rand -base64 16`

### Tenant-Specific Secrets

Each tenant has its own secret configuration:

```yaml
tenantSecrets:
  ecsp:
    clientsecretkey: "ChangeMe"
    clientsecretsalt: "ChangeMe"
    revokeTokenClientSecret: "ChangeMe"
    smtp_username: "ChangeMe"
    smtp_password: "ChangeMe"
```

**Action Required:**

1. **Tenant Isolation:**
   - Use different secrets for each tenant
   - Prevents cross-tenant data access
   - Enhances security in multi-tenant environments

2. **Tenant-Specific SMTP:**
   - Each tenant can have different email sender
   - Example: `noreply-ecsp@company.com`, `noreply-sdp@company.com`
   - Configure separate SMTP credentials per tenant if needed

3. **Secret Generation:**
   ```bash
   # Generate all secrets for a tenant
   echo "Secrets for tenant: ecsp"
   echo "clientsecretkey: $(openssl rand -base64 32)"
   echo "clientsecretsalt: $(openssl rand -base64 16)"
   echo "revokeTokenClientSecret: $(openssl rand -base64 24)"
   ```

### Secret Storage Best Practices

**DO:**
- ✅ Use Kubernetes secrets or external secret managers
- ✅ Rotate secrets every 90 days
- ✅ Use different secrets per environment (dev, staging, prod)
- ✅ Use different secrets per tenant
- ✅ Encrypt secrets at rest
- ✅ Audit secret access

**DON'T:**
- ❌ Commit secrets to version control
- ❌ Share secrets via email or chat
- ❌ Use same secrets across environments
- ❌ Use weak or predictable secrets
- ❌ Store secrets in plain text

---

## Database Configuration

### PostgreSQL Connection Pool

```yaml
postgres:
  max_pool_size: "30"
  max_idle_time: "0"
  data_source_properties:
    cachePrepStmts: "true"
    prepStmtCacheSize: "250"
    prepStmtCacheSqlLimit: "2048"
  connecion_timeout_ms: "60000"
  expected99thPercentileMs: "60000"
```

**Action Required:**

1. **Connection Pool Sizing:**
   - Formula: `pool_size = (number_of_cores * 2) + effective_spindle_count`
   - For read-heavy: Increase pool size
   - For write-heavy: Keep pool size moderate
   - Monitor connection usage and adjust

2. **Connection Timeout:**
   - `connecion_timeout_ms`: Time to wait for connection
   - Default: 60000ms (60 seconds)
   - Increase if experiencing timeout errors
   - Decrease for faster failure detection

### Liquibase Configuration

```yaml
postgres:
  liquibase:
    clientsecret: ChangeMe
    userpwd: ChangeMe
    usersalt: ChangeMe
```

**Action Required:**

1. **Purpose:**
   - Liquibase manages database schema migrations
   - These secrets seed initial data (default users, clients)
   - Values should match those in `secrets.liquibase_*`

2. **Security Note:**
   - Initial seeded passwords should be changed after first login
   - Consider disabling default users in production
   - Use strong passwords even for initial seeding

### PostgreSQL Credentials (Separate Section)

```yaml
postgresql:
  host: postgresql
  connection: postgresql
  port: 5432
  secretName: uidam-user-management-credentials
  userName: ChangeMe
  password: ChangeMe
```

**Action Required:**
- This section is used by Kubernetes secret templates
- `userName` and `password` must match database credentials
- Store actual credentials in secrets, not in values.yaml
- Example workflow:
  ```bash
  kubectl create secret generic uidam-user-management-credentials \
    --from-literal=username='uidam_user' \
    --from-literal=password='SecurePassword123!' \
    -n uidam
  ```

---

## Notification Configuration

### Email Templates

The service uses email templates for various notifications:

1. **Password Recovery:**
   - Sent when user requests password reset
   - Contains recovery link with temporary token
   - Token expiration: Configurable (default: 24 hours)

2. **User Verification:**
   - Sent when user signs up
   - Contains verification link
   - Required if `defaultStatus: "PENDING"`

3. **Password Changed:**
   - Notification when password is updated
   - Security measure to detect unauthorized changes

4. **Account Locked:**
   - Sent when account locked due to failed login attempts
   - Contains instructions for unlocking

### Email Configuration Examples

#### Gmail Configuration

```yaml
notification:
  enabled: "true"
  email:
    fromAddress: "noreply@yourdomain.com"
    fromName: "UIDAM System"
    host: "smtp.gmail.com"
    port: "587"
    protocol: "smtp"
    auth: "true"
    starttls: "true"
    sslEnabled: "false"

secrets:
  smtp_username: "your-email@gmail.com"
  smtp_password: "your-app-password"  # Not your Gmail password!
```

**Setup Steps:**
1. Enable 2-factor authentication on Gmail
2. Generate App Password: Google Account → Security → App passwords
3. Use App Password in `smtp_password` secret

#### AWS SES Configuration

```yaml
notification:
  enabled: "true"
  email:
    fromAddress: "noreply@verified-domain.com"
    fromName: "UIDAM System"
    host: "email-smtp.us-east-1.amazonaws.com"
    port: "587"
    protocol: "smtp"
    auth: "true"
    starttls: "true"
    sslEnabled: "false"

secrets:
  smtp_username: "YOUR_SES_SMTP_USERNAME"
  smtp_password: "YOUR_SES_SMTP_PASSWORD"
```

**Setup Steps:**
1. Verify email address or domain in SES console
2. Create SMTP credentials: SES → SMTP Settings → Create SMTP Credentials
3. Move out of SES sandbox for production use
4. Configure sending limits and bounce handling

#### SendGrid Configuration

```yaml
notification:
  enabled: "true"
  email:
    fromAddress: "noreply@yourdomain.com"
    fromName: "UIDAM System"
    host: "smtp.sendgrid.net"
    port: "587"
    protocol: "smtp"
    auth: "true"
    starttls: "true"
    sslEnabled: "false"

secrets:
  smtp_username: "apikey"  # Literally the string "apikey"
  smtp_password: "SG.your-sendgrid-api-key"
```

**Setup Steps:**
1. Create SendGrid account
2. Verify sender email/domain
3. Create API Key: Settings → API Keys → Create API Key
4. Select "Mail Send" permission
5. Username is always "apikey"


---

## Password Policy Configuration

### Configuring Password Requirements

```yaml
password:
  minLength: "10"
  maxLength: "15"
  updateTimeInterval: "1"
  policyCheckEnabled: "true"
```

**Password Policy Enforcement:**

When `policyCheckEnabled: "true"`, passwords must contain:
- At least one uppercase letter (A-Z)
- At least one lowercase letter (a-z)
- At least one digit (0-9)
- At least one special character (!@#$%^&*()_+-=[]{}|;:,.<>?)
- Length between minLength and maxLength

### Password Expiration Workflow

When password expires (`updateTimeInterval` days passed):
1. User login is successful
2. API returns status code indicating password expired
3. User must change password before accessing application
4. New password must be different from old password
5. Password history is maintained (last N passwords)

---

## Monitoring & Metrics

### Prometheus Configuration

```yaml
metrics:
  prometheus:
    enabled: "false"
  agent:
    port: "9100"
    port_exposed: "9100"
```

**Action Required:**

1. **Enable Prometheus Metrics:**
   ```yaml
   metrics:
     prometheus:
       enabled: "true"
   ```

2. **Configure Prometheus Scraping:**
   ```yaml
   # prometheus-config.yaml
   scrape_configs:
     - job_name: 'uidam-user-management'
       kubernetes_sd_configs:
         - role: pod
       relabel_configs:
         - source_labels: [__meta_kubernetes_pod_label_app]
           regex: uidam-user-management
           action: keep
       metrics_path: /actuator/prometheus
       scheme: http
   ```

### Health Monitoring

```yaml
health:
  postgresdb:
    monitor:
      enabled: "true"
      restart_on_failure: "true"
```

**Action Required:**

1. **Database Health Check:**
   - Set `enabled: "true"` to monitor DB connectivity
   - Set `restart_on_failure: "true"` for auto-restart on DB failure
   - Production recommendation: enabled=true, restart_on_failure=false

2. **Health Endpoints:**
   - Liveness: `/actuator/health/liveness`
   - Readiness: `/actuator/health/readiness`
   - Full health: `/actuator/health`

3. **Configure Kubernetes Probes:**
   ```yaml
   livenessProbe:
     httpGet:
       path: /actuator/health/liveness
       port: 8080
     initialDelaySeconds: 30
     periodSeconds: 10
   
   readinessProbe:
     httpGet:
       path: /actuator/health/readiness
       port: 8080
     initialDelaySeconds: 30
     periodSeconds: 10
   ```

### PostgreSQL Metrics

```yaml
postgresdb:
  metrics:
    enabled: "false"
    executor_shutdown_buffer_ms: "2000"
    thread:
      freq_ms: "5000"
      intial_delay_ms: "2000"
```

**Action Required:**
- Set `enabled: "true"` for detailed DB connection pool metrics
- Adjust `freq_ms` for metric collection frequency
- Lower frequency = more real-time metrics but higher overhead
- Recommended: 5000ms for production

---

## Deployment

### Pre-Deployment Checklist

- [ ] PostgreSQL database created and accessible
- [ ] SMTP server configured and credentials obtained
- [ ] All placeholder values replaced with actual values
- [ ] Secrets generated and stored securely
- [ ] Authorization Server deployed and accessible
- [ ] Network policies configured
- [ ] Resource limits set appropriately
- [ ] Multi-tenant configuration matches Authorization Server

## Troubleshooting

### Common Issues

#### 1. Pod Not Starting

**Symptoms:** Pod in CrashLoopBackOff or Error state

**Solutions:**
```bash
# Check logs
kubectl logs -n uidam <pod-name> --previous

# Check events
kubectl describe pod -n uidam <pod-name>

# Common causes:
# - Database connection failed
# - Liquibase migration failed
# - Missing secrets
# - Invalid configuration
# - Out of memory
```

**Specific Error Messages:**

| Error | Cause | Solution |
|-------|-------|----------|
| "Connection refused" | DB not accessible | Verify DB host/port, check network |
| "Authentication failed" | Wrong DB credentials | Check username/password in secrets |
| "Schema not found" | Schema doesn't exist | Create schema in database |
| "Liquibase validation failed" | Checksum mismatch | Clear changeloglock, re-run migration |
| "OutOfMemoryError" | Insufficient memory | Increase memory limits |

#### 2. Database Connection Errors

**Symptoms:** Logs show connection failures

**Diagnostic Steps:**
```bash
# Test DB connectivity from pod
kubectl exec -it -n uidam <pod-name> -- bash
nc -zv postgresql 5432
telnet postgresql 5432

# Test with psql
psql -h postgresql -U uidam_user -d uidam_user_db

# Check connection pool
kubectl logs -n uidam <pod-name> | grep -i "HikariPool"
```

**Common Fixes:**
1. Verify database host is correct
2. Check database user exists and has permissions
3. Verify password in secret matches database
4. Ensure database and schema exist
5. Check connection pool settings
6. Verify PostgreSQL is running

#### 3. Email Sending Failures

**Symptoms:** Password recovery fails, no emails received

**Diagnostic Steps:**
```bash
# Check logs for SMTP errors
kubectl logs -n uidam <pod-name> | grep -i "mail\|smtp"

# Test SMTP from pod
kubectl exec -it -n uidam <pod-name> -- bash
telnet smtp.example.com 587

# Check if pod can reach SMTP server
kubectl exec -it -n uidam <pod-name> -- \
  nc -zv smtp.example.com 587
```

**Common Email Issues:**

| Issue | Solution |
|-------|----------|
| Connection timeout | Check firewall rules, allow outbound 587/465 |
| Authentication failed | Verify SMTP username/password |
| Sender rejected | Verify sender email with SMTP provider |
| TLS/SSL errors | Check starttls/sslEnabled settings |
| Rate limit exceeded | Implement rate limiting, contact provider |
| Emails go to spam | Configure SPF, DKIM, DMARC DNS records |

#### 4. Authorization Server Integration

**Symptoms:** Token operations fail, revoke endpoint errors

**Solutions:**
```bash
# Test connectivity to auth server
kubectl exec -it -n uidam <pod-name> -- \
  curl -I http://uidam-authorization-server:9000/actuator/health

# Check token endpoint
kubectl logs -n uidam <pod-name> | grep -i "token"

# Verify configuration
kubectl get configmap -n uidam uidam-user-management -o yaml | grep -i "auth"

# Common causes:
# - Authorization Server not running
# - Wrong URL in configuration
# - Network policy blocking traffic
# - Client credentials incorrect
# - Token expired or invalid
```

#### 5. Multi-Tenant Issues

**Symptoms:** Tenant-specific configuration not applied

**Solutions:**
```bash
# Check tenant configmaps exist
kubectl get configmap -n uidam | grep tenant

# Verify tenant secret exists
kubectl get secret -n uidam | grep tenant

# Check logs for tenant initialization
kubectl logs -n uidam <pod-name> | grep -i "tenant"

# Verify tenant configuration
kubectl get configmap -n uidam uidam-user-management-tenant-ecsp -o yaml

# Common causes:
# - Tenant ID mismatch with Auth Server
# - Tenant configmap/secret not created
# - Multi-tenant not enabled
# - Default tenant not set
```

## API Reference

### Key Endpoints

#### User Management
- `POST /v1/users` - Create new user
- `GET /v1/users/{id}` - Get user by ID
- `GET /v1/users/{userName}/byUserName` - Get user by username
- `PUT /v1/users/{id}` - Update user
- `DELETE /v1/users/{id}` - Delete user
- `GET /v1/users` - List users (paginated)

#### Password Management
- `POST /v1/users/{userName}/recovery/forgotpassword` - Request password reset
- `POST /v1/users/recovery/set-password` - Reset password with token
- `PUT /v1/users/{id}/password` - Change password

#### User Events
- `POST /v1/users/{id}/events` - Add user event
- `GET /v1/users/{id}/events` - Get user events

#### Password Policy
- `GET /v1/users/password-policy` - Get password policy

#### Health & Monitoring
- `GET /actuator/health` - Health check
- `GET /actuator/health/liveness` - Liveness probe
- `GET /actuator/health/readiness` - Readiness probe
- `GET /actuator/prometheus` - Prometheus metrics
- `GET /actuator/info` - Application info

---

## Support and Additional Resources

### Configuration Files Reference

- `values.yaml` - Main configuration file
- `templates/configmap.yaml` - Environment variables
- `templates/secret.yaml` - Global secrets
- `templates/secret-tenant-*.yaml` - Tenant-specific secrets
- `templates/deployment.yaml` - Deployment specification
- `templates/service.yaml` - Service configuration
- `templates/ingress.yaml` - Ingress configuration

### Best Practices

1. **Security:**
   - Use strong passwords for all secrets
   - Enable TLS for all communication
   - Rotate secrets every 90 days
   - Use separate secrets per tenant
   - Never commit secrets to git
   - Use sealed-secrets or vault

2. **Performance:**
   - Tune database connection pool
   - Set appropriate resource limits
   - Enable metrics and monitoring
   - Use database indexes
   - Cache frequently accessed data

3. **High Availability:**
   - Run multiple replicas (3+ for production)
   - Configure pod disruption budgets
   - Use separate database per tenant
   - Implement database replication
   - Configure auto-scaling

4. **Email Delivery:**
   - Use dedicated SMTP service
   - Configure SPF/DKIM/DMARC
   - Monitor bounce rates
   - Implement rate limiting
   - Use email templates

5. **Multi-Tenancy:**
   - Isolate tenant data completely
   - Use separate databases per tenant
   - Monitor per-tenant metrics
   - Configure tenant-specific quotas
   - Implement tenant-aware logging

---

---

**Document Version:** 1.0  
**Last Updated:** October 27, 2025  
**Component Version:** 1.2.3
