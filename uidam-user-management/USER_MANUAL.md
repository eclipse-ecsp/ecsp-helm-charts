# UIDAM User Management - User Manual

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Chart Structure](#chart-structure)
4. [Configuration Guide](#configuration-guide)
5. [Multi-Tenant Configuration](#multi-tenant-configuration)
6. [Multi-Factor Authentication](#multi-factor-authentication)
7. [Security & Secrets Management](#security--secrets-management)
8. [Database Configuration](#database-configuration)
9. [Notification Configuration](#notification-configuration)
10. [Data Archival CronJob](#data-archival-cronjob)
11. [Password Policy Configuration](#password-policy-configuration)
12. [Monitoring & Metrics](#monitoring--metrics)
13. [Deployment](#deployment)
14. [Upgrading From Chart 1.2.x](#upgrading-from-chart-12x)
15. [Troubleshooting](#troubleshooting)

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
- Multi-factor authentication (TOTP) with optional backup codes
- Scheduled per-tenant data archival
---

## Prerequisites

Before deploying the UIDAM User Management service, ensure you have:

1. **Kubernetes Cluster** (v1.19+)
2. **Helm** (v3.0+)
3. **PostgreSQL Database** (v12+)
4. **SMTP Server** (for email notifications)
5. **UIDAM Authorization Server** (deployed and accessible)

---

## Chart Structure

The chart renders one ConfigMap for global settings, one ConfigMap holding the
**default tenant** configuration, and one ConfigMap **per active tenant** that only
contains the keys that tenant overrides. Secrets follow the same pattern.

| Template | Renders | Notes |
|----------|---------|-------|
| `templates/configmap.yaml` | `<release>-uidam-user-management` | Global, tenant-independent settings |
| `templates/configmap-default-configurations.yaml` | `<release>-uidam-user-management-tenant-default` | Full `DEFAULT_*` baseline, always rendered |
| `templates/configmap-tenants-config.yaml` | `<release>-uidam-user-management-tenant-<id>` | One per active tenant, generated dynamically |
| `templates/secret.yaml` | `<release>-uidam-user-management-credentials` | Global credentials |
| `templates/secret-tenants.yaml` | `<release>-uidam-user-management-tenant-<id>-credentials` | One per active tenant **plus** `default` |
| `templates/archival-cronjob.yaml` | `<release>-uidam-user-management-archival-<id>` | Only when `archivalJob.enabled` is true |
| `templates/notification-config.yaml` | `<release>-uidam-user-management-notification-config` | Only when `notification.config.createDefault` is true |

### How tenant resolution works

1. `configmap-default-configurations.yaml` publishes the complete configuration as
   `DEFAULT_*` environment variables. These back the `tenant-default.properties`
   placeholders inside the application image.
2. `configmap-tenants-config.yaml` iterates over `multiTenant.tenants` and emits
   `tenants_profile_<tenant>_*` keys **only for the fields a tenant actually defines**.
3. The Deployment mounts the global ConfigMap first, then the default ConfigMap,
   then each tenant ConfigMap, so anything a tenant does not override falls back to
   the default tenant values.

A tenant is considered active when its key appears in `multiTenant.tenantIds` or
equals `multiTenant.defaultTenant`. Adding a tenant is therefore a values-only
change - no new template files are needed.

---

## Configuration Guide

### Basic Configuration (`values.yaml`)

#### 1. Image Configuration

```yaml
image:
  repository: docker.io/eclipseecsp/uidam-user-management
  pullPolicy: IfNotPresent
  tag: 1.6.0
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

#### 4. Config Server (optional)

```yaml
configServer:
  host: "http://config-server:8080/config/"
  enabled: false
  springConfigImport: "optional:classpath:tenant-default.properties,optional:configserver:{{ .Values.configServer.host }}"
```

**Action Required:**
- Leave `enabled: false` to source all tenant configuration from the chart's ConfigMaps (default).
- Set `enabled: true` only when a Spring Cloud Config Server owns the tenant
  configuration. In that mode the chart stops emitting `TENANT_IDS`, so the tenant
  list is resolved from the config server instead.

---

## Multi-Tenant Configuration

### Enable Multi-Tenancy

```yaml
multiTenant:
  tenantIds: "ecsp,sdp"
  defaultTenant: "ecsp"
  enabled: false  # Set to true to enable
  configValidationEnabled: false
  dbNameValidationStrategy: "NONE"
```

**Action Required:**
1. Set `enabled: true` to activate multi-tenant mode.
2. Update `tenantIds` with comma-separated tenant identifiers.
3. Set `defaultTenant` to the primary tenant ID.
4. **Important:** Tenant IDs must match those configured in the Authorization Server.

| Key | Purpose |
|-----|---------|
| `tenantIds` | Comma-separated list of tenants to activate. Only these get a ConfigMap/Secret. |
| `defaultTenant` | Tenant used when a request carries no tenant hint. Always activated, even if absent from `tenantIds`. |
| `enabled` | `false` runs the service in single-tenant mode using `defaultTenant`. |
| `configValidationEnabled` | Fail startup when a tenant's configuration is incomplete. |
| `dbNameValidationStrategy` | `NONE`, `PREFIX` or `EXACT` - how tenant DB names are validated. |

### Configuration Inheritance Model

> **Changed in chart 1.6.0.** Tenants no longer repeat the full configuration.

The `default` tenant holds the **complete** configuration. Every other tenant lists
**only the fields that differ**. Anything omitted is inherited from `default`.

```yaml
multiTenant:
  tenants:
    # Overrides only - everything else comes from `default`
    ecsp:
      tenantId: "ecsp"
      tenantName: "ECSP"
      account:
        accountName: "ecsp"
      emailVerification:
        url: "https://api-gateway.{{ .Values.environmentDomainName }}/ecsp/v1/emailVerification/%s"
        authServerResponseUrl: "https://uidam-authorization-server.{{ .Values.environmentDomainName }}/ecsp/emailVerification/verify"
      authServer:
        tokenUrl: "/ecsp/oauth2/token"
        revokeTokenUrl: "/ecsp/revoke/revokeByAdmin"
      recovery:
        authServerResetResponseUrl: "https://uidam-authorization-server.{{ .Values.environmentDomainName }}/ecsp/recovery/reset/"
      database:
        jdbcUrl: "jdbc:postgresql://postgresql:5432/ecsp_db"
      archivalJob:
        enabled: false
        scheduler: "0 5 * * *"

    # The full baseline
    default:
      tenantId: "default"
      tenantName: "DEFAULT"
      # ... every section below ...
```

**Benefits:**
- Adding a tenant is typically 10-15 lines instead of ~60.
- Shared settings are changed in exactly one place.
- Only genuinely tenant-specific keys land in the tenant ConfigMap, which makes
  `kubectl get configmap ...-tenant-ecsp -o yaml` an accurate diff of what is custom.

**Caveat:** because omission means inheritance, you cannot "unset" a value by
removing it. To blank a field, set it explicitly to `""`.

String values support Helm templating, so `{{ .Values.environmentDomainName }}`
is expanded at render time.

### Tenant Configuration Reference

The sections below are valid for the `default` tenant and for any tenant override.

#### Account Configuration

```yaml
account:
  accountName: "default"                # Account display name
  accountType: "Root"                   # Root, Sub, Child, etc.
```

**Action Required:**
- Set a descriptive `accountName` per tenant.
- Configure `accountType` based on your account hierarchy:
  - `Root`: Top-level tenant
  - `Sub`: Sub-tenant of root
  - `Child`: Child tenant

#### User Configuration

```yaml
user:
  passwordEncoder: "SHA-256"            # Password hashing algorithm
  maxAllowedLoginAttempts: 3            # Account lock threshold
  isUserStatusLifeCycleEnabled: false   # Enable status transitions
  externalUserPermittedRoles: "VEHICLE_OWNER"  # Roles allowed for federated users
  externalUserDefaultStatus: ""         # Initial status for federated users
  userDefaultAccountName: "userdefaultaccount"
  additionalAttrCheckEnabledForSignUp: false
  temporaryLockEnabled: true            # Lock instead of permanently disabling
  temporaryLockPeriodMinutes: 30        # Lock duration
```

**Action Required:**

1. **maxAllowedLoginAttempts:** brute-force protection. Recommended 3-5.
2. **temporaryLockEnabled / temporaryLockPeriodMinutes:**
   - `true`: the account unlocks automatically after `temporaryLockPeriodMinutes`.
   - `false`: the account stays locked until an administrator intervenes.
3. **externalUserPermittedRoles:** comma-separated roles assignable to users created
   through an external IdP. Must match roles defined in the Authorization Server.
4. **isUserStatusLifeCycleEnabled:**
   - `true`: enable automatic status transitions (e.g. PENDING to ACTIVE)
   - `false`: manual status management only
5. **additionalAttrCheckEnabledForSignUp:** enforce required custom attributes during
   self-registration.

#### Auth Scope Configuration

```yaml
auth:
  adminScope: "UIDAMSystem"
```

The OAuth2 scope a token must carry to perform administrative operations.

#### Email Verification Configuration

```yaml
emailVerification:
  enabled: false
  url: "https://api-gateway.{{ .Values.environmentDomainName }}/default/v1/emailVerification/%s"
  notificationId: "UIDAM_USER_VERIFY_ACCOUNT"
  expDays: 7
  emailRegexPatternExclude: ""
  authServerResponseUrl: "https://uidam-authorization-server.{{ .Values.environmentDomainName }}/default/emailVerification/verify"
  emailLogoPath: "images/default-logo.svg"
  emailCopyright: "Copyright (c) 2023 HARMAN International. All Rights Reserved."
```

**Action Required:**
- `url` must be reachable by the end user; `%s` is replaced with the verification token.
- `authServerResponseUrl` must point at the Authorization Server path for this tenant.
- `emailRegexPatternExclude` lets you skip verification for internal domains,
  e.g. `.*@yourcompany\.com`.
- `emailLogoPath` and `emailCopyright` brand the generated emails per tenant.

#### Notification Configuration (per tenant)

```yaml
notification:
  apiUrl: "http://notification-api-int-svc:8080/v1/notifications/nonRegisteredUsers"
  notificationId: "uidamCustomEmailTemplate5"
  config:
    resolver: "internal"                # internal | external
    path: "classpath:/notification/uidam-notification-config.json"
  template:
    engine: "thymeleaf"                 # thymeleaf | mustache
    format: "HTML"                      # HTML | TEXT
    resolver: "CLASSPATH"               # CLASSPATH | FILE | URL
    prefix: "/notification/"
    suffix: ".html"
  email:
    provider: "internal"                # internal (Spring Mail) | ignite (Notification Center)
    host: "TO-BE-UPDATED"
    port: "587"
    smtpAuth: "true"
    smtpStartTls: "true"
    smtpStartTlsRequired: "true"
    smtpSSLEnabled: "false"
    smtpDebug: "false"
```

**Action Required:**
- Set `email.host` to your SMTP server; see
  [Email Configuration Examples](#email-configuration-examples) for provider presets.
- SMTP credentials are **not** configured here - they come from the tenant Secret
  (`smtp_username` / `smtp_passwd`). See
  [Security & Secrets Management](#security--secrets-management).
- Use `provider: "ignite"` to delegate delivery to the ECSP Notification Center
  via `apiUrl` instead of sending SMTP directly.

#### Authorization Server Integration

```yaml
authServer:
  hostName: "https://uidam-authorization-server"
  tokenUrl: "/default/oauth2/token"
  revokeTokenUrl: "/default/revoke/revokeByAdmin"
  clientId: "token-mgmt"
```

**Action Required:**
- `hostName` is suffixed with `.{{ .Values.environmentDomainName }}` by the chart,
  so supply the scheme and host prefix only.
- `tokenUrl` and `revokeTokenUrl` are tenant-scoped paths and normally start with
  `/<tenantId>/`.
- `clientId` must exist in the Authorization Server; its secret comes from the
  tenant Secret key `revokeTokenClientSecret`.

#### Client Registration Configuration

```yaml
clientRegistration:
  defaultStatus: "approved"             # approved | pending
  refreshTokenValidity: 3600            # seconds
  accessTokenValidity: 3600             # seconds
  authorizationCodeValidity: 300        # seconds
  hashAlgorithm: "SHA-256"
```

Controls the defaults applied to OAuth2 clients created through the
`/v1/oauth2/client` API. Use `defaultStatus: "pending"` to require manual approval.

#### Password Recovery Configuration

```yaml
recovery:
  secretExpiresInMinutes: 15
  passwordRecoveryNotificationId: "UIDAM_USER_PASSWORD_RECOVERY"
  authServerResetResponseUrl: "https://uidam-authorization-server.{{ .Values.environmentDomainName }}/default/recovery/reset/"
```

**Action Required:**
- Keep `secretExpiresInMinutes` short (10-30 minutes recommended).
- `authServerResetResponseUrl` must match the tenant path on the Authorization Server.

#### Captcha Configuration

```yaml
captcha:
  enforceAfterNoOfFailures: 1
```

Number of failed logins after which a captcha challenge is required. The captcha
site key and secret live in the Authorization Server chart.

#### Database Configuration (Per Tenant)

```yaml
database:
  jdbcUrl: "jdbc:postgresql://postgresql:5432/default_db"
  maxPoolSize: 30
  maxIdleTime: 0
  connectionTimeoutMs: 60000
  defaultSchema: "uidam"
  cachePrepStmts: true
  prepStmtCacheSize: 250
  prepStmtCacheSqlLimit: 2048
```

**Action Required:**
- Create a separate database for each tenant.
- Update the JDBC URL: `jdbc:postgresql://HOST:PORT/DATABASE_NAME`.
- The schema named in `defaultSchema` must exist and be owned by the connection user.
- The driver class is set by the chart; you do not need to configure it.
- Credentials come from the tenant Secret (`username` / `password`), not from this block.

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

#### Liquibase Configuration (Per Tenant)

```yaml
liquibase:
  changeLog: "classpath:database.schema/master.xml"
  defaultSchema: "uidam"
  parametersSchema: "uidam"
```

Liquibase runs on startup and creates/migrates the tenant schema. The seed data it
writes (initial client and admin user) is driven by the `liquibase_*` keys in the
tenant Secret.

---

## Multi-Factor Authentication

> **New in chart 1.6.0.**

```yaml
multiTenant:
  tenants:
    default:
      mfa:
        mfaAppName: "UIDAM"             # Name shown in the authenticator app
        backupCodesEnabled: false       # Issue one-time recovery codes
        backupCodesCount: 8             # How many codes to issue
```

**Action Required:**

1. `mfaAppName` is the issuer label users see in Google Authenticator / Authy.
   Use a per-tenant value so users with several tenants can tell entries apart.
2. Set `backupCodesEnabled: true` to let users recover when they lose their device.
   Codes are single-use and only displayed once at enrolment.
3. MFA enrolment secrets are encrypted at rest using `mfaSecretEncryptionKey` and
   `mfaSecretEncryptionSalt` from the tenant Secret - see
   [Security & Secrets Management](#security--secrets-management).
4. Whether MFA is actually **required** at login is decided by the Authorization
   Server (`mfa.mode`). This chart only stores and encrypts the enrolment data.

> **Important:** changing `mfaSecretEncryptionKey` or `mfaSecretEncryptionSalt` after
> users have enrolled invalidates every existing enrolment. Users must re-enrol.

---

## Security & Secrets Management

> **Changed in chart 1.6.0.** The three hand-maintained `secret-tenant-<id>.yaml`
> templates were replaced by a single `secret-tenants.yaml` that generates one Secret
> per active tenant. Secrets are declared in `values.yaml` only.

### Rendered Secrets

| Secret | Source | Consumed as |
|--------|--------|-------------|
| `<release>-uidam-user-management-credentials` | `secrets`, `postgresql`, `notification.email`, top-level `clientsecretkey`/`clientsecretsalt`/`revokeTokenClientSecret` | Global env vars (`POSTGRES_USERNAME`, `CLIENT_SECRET`, ...) |
| `<release>-uidam-user-management-tenant-default-credentials` | `tenantSecrets.default` | `DEFAULT_*` env vars |
| `<release>-uidam-user-management-tenant-<id>-credentials` | `tenantSecrets.<id>` merged over `tenantSecrets.default` | `tenants_profile_<id>_*` env vars |

Any key a tenant omits is inherited from `tenantSecrets.default`, mirroring the
configuration inheritance model.

### Global Secrets

```yaml
secrets:
  liquibase_clientsecret: "ChangeMe"
  liquibase_userpwd: "ChangeMe"
  liquibase_usersalt: "ChangeMe"
  mfaSecretEncryptionKey: "ChangeMe"
  mfaSecretEncryptionSalt: "ChangeMe"

# Used by the global credentials Secret
clientsecretkey: ChangeMe
clientsecretsalt: ChangeMe
revokeTokenClientSecret: ChangeMe
```

### Tenant-Specific Secrets

```yaml
tenantSecrets:
  default:
    revokeTokenClientSecret: "ChangeMe"
    clientSecretKey: "ChangeMe"
    clientSecretSalt: "ChangeMe"
    mfaSecretEncryptionKey: "ChangeMe"
    mfaSecretEncryptionSalt: "ChangeMe"
    liquibase_clientsecret: "ChangeMe"
    liquibase_userpwd: "ChangeMe"
    liquibase_usersalt: "ChangeMe"
  ecsp:
    # only the keys that differ from `default`
    revokeTokenClientSecret: "ChangeMe"
    clientSecretKey: "ChangeMe"
    clientSecretSalt: "ChangeMe"
    mfaSecretEncryptionKey: "ChangeMe"
    mfaSecretEncryptionSalt: "ChangeMe"
    liquibase_clientsecret: "ChangeMe"
    liquibase_userpwd: "ChangeMe"
    liquibase_usersalt: "ChangeMe"
```

### Key Reference

| Key | Purpose | Suggested generation |
|-----|---------|----------------------|
| `clientSecretKey` | Encrypts OAuth2 client secrets at rest. **Must match the Authorization Server.** | `openssl rand -base64 32` |
| `clientSecretSalt` | Salt for client secret hashing. **Must match the Authorization Server.** | `openssl rand -base64 16` |
| `revokeTokenClientSecret` | Secret of the `token-mgmt` client used to call the Authorization Server revoke endpoint. | `openssl rand -base64 24` |
| `mfaSecretEncryptionKey` | Encrypts stored TOTP seeds. | `openssl rand -base64 32` |
| `mfaSecretEncryptionSalt` | Salt for TOTP seed encryption. | `openssl rand -base64 16` |
| `liquibase_clientsecret` | Secret of the OAuth2 client seeded by the initial migration. | `openssl rand -base64 24` |
| `liquibase_userpwd` | Pre-hashed password of the seeded admin user. | See note below |
| `liquibase_usersalt` | Salt used to produce `liquibase_userpwd`. | `openssl rand -base64 16` |
| `smtp_username` / `smtp_passwd` | SMTP credentials; taken from `notification.email.username` / `notification.email.passwd`. | Provider-specific |
| `username` / `password` | Database credentials; taken from `postgresql.userName` / `postgresql.password`. | Provider-specific |

> **Note on `liquibase_userpwd`:** this is not a plaintext password. It is the
> password already hashed with `liquibase_usersalt` using the tenant's
> `user.passwordEncoder` algorithm. Generate the pair with the UIDAM password
> hashing utility, not with `openssl rand`.

**Generating a full tenant secret set:**

```bash
TENANT=ecsp
echo "tenantSecrets:"
echo "  ${TENANT}:"
echo "    clientSecretKey: \"$(openssl rand -base64 32)\""
echo "    clientSecretSalt: \"$(openssl rand -base64 16)\""
echo "    revokeTokenClientSecret: \"$(openssl rand -base64 24)\""
echo "    mfaSecretEncryptionKey: \"$(openssl rand -base64 32)\""
echo "    mfaSecretEncryptionSalt: \"$(openssl rand -base64 16)\""
```

### Cross-Chart Consistency

These values **must be identical** in the `uidam-authorization-server` chart for the
same tenant, otherwise client secrets written by one service cannot be read by the other:

| uidam-user-management | uidam-authorization-server |
|-----------------------|----------------------------|
| `tenantSecrets.<id>.clientSecretKey` | `tenantSecrets.<id>.clientsecretkey` |
| `tenantSecrets.<id>.clientSecretSalt` | `tenantSecrets.<id>.clientsecretsalt` |
| `tenantSecrets.<id>.revokeTokenClientSecret` | secret of the `token-mgmt` client |

### Using an External Secret Manager

The chart writes Secrets from `values.yaml`, which is convenient for evaluation but
unsuitable for production. To source them externally:

1. Create the Secrets out-of-band with the exact names listed in
   [Rendered Secrets](#rendered-secrets) and the key names from the table above.
2. Delete `templates/secret.yaml` and `templates/secret-tenants.yaml`, or guard them
   behind a values flag in your fork.
3. Keep `postgresql.secretName` pointing at your externally managed Secret.

Tools that work well here: External Secrets Operator, Sealed Secrets, or the
Vault Agent Injector.

### Secret Storage Best Practices

**DO:**
- ✅ Use Kubernetes secrets or external secret managers
- ✅ Rotate secrets every 90 days (except MFA keys - see the warning above)
- ✅ Use different secrets per environment (dev, staging, prod)
- ✅ Use different secrets per tenant
- ✅ Encrypt secrets at rest
- ✅ Audit secret access

**DON'T:**
- ❌ Commit real secrets to version control
- ❌ Share secrets via email or chat
- ❌ Use the same secrets across environments
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

### Liquibase Seed Data

Liquibase runs on startup and migrates each tenant schema. The data it seeds (the
initial OAuth2 client and admin user) is driven by the tenant Secret, **not** by the
`postgres.liquibase` block:

```yaml
tenantSecrets:
  <tenant>:
    liquibase_clientsecret: "ChangeMe"
    liquibase_userpwd: "ChangeMe"
    liquibase_usersalt: "ChangeMe"
```

Per-tenant changelog settings live under the tenant's `liquibase` block - see
[Liquibase Configuration (Per Tenant)](#liquibase-configuration-per-tenant).

**Security Note:**
- Initial seeded passwords should be changed after first login
- Consider disabling default users in production
- Use strong passwords even for initial seeding

> The legacy `postgres.liquibase.*` block in `values.yaml` is no longer read by any
> template. It is retained only for backward compatibility with older overrides and
> can be removed from your values file.

### PostgreSQL Credentials

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
- `userName` / `password` populate the `username` / `password` keys of **every**
  Secret the chart renders (global and per tenant).
- `secretName` must resolve to the rendered global Secret,
  i.e. `<release>-uidam-user-management-credentials`. Change it only if you manage
  that Secret yourself.
- To keep credentials out of `values.yaml`, create the Secret out-of-band and remove
  `templates/secret.yaml` / `templates/secret-tenants.yaml`:
  ```bash
  kubectl create secret generic uidam-user-management-credentials \
    --from-literal=username='uidam_user' \
    --from-literal=password='SecurePassword123!' \
    -n uidam
  ```

> If different tenants use different database users, set the credentials per tenant
> in `tenantSecrets.<tenant>` and extend `templates/secret-tenants.yaml` accordingly.
> Out of the box every tenant Secret reuses `postgresql.userName` / `postgresql.password`.

---

## Notification Configuration

### Email Templates

The service uses email templates for various notifications:

1. **Password Recovery:**
   - Sent when a user requests a password reset
   - Contains a recovery link with a temporary token
   - Token lifetime: `recovery.secretExpiresInMinutes` (default 15 minutes)

2. **User Verification:**
   - Sent when a user signs up, if `emailVerification.enabled` is `true`
   - Contains a verification link valid for `emailVerification.expDays` days

3. **Multi-Factor Enrolment:**
   - Sent when a user enrols or resets an MFA device

Template rendering is controlled per tenant via `notification.template`
(engine, format, resolver, prefix, suffix) and the notification catalogue via
`notification.config`. See
[Notification Configuration (per tenant)](#notification-configuration-per-tenant).

### Default Notification Catalogue

```yaml
notification:
  config:
    createDefault: true
    configName: "uidam-user-management-notification-config"
    resolver: "internal"
    path: "file:/notification/uidam-user-management-notification-config.json"
```

When `createDefault: true` the chart renders
`templates/notification-config.yaml` into a ConfigMap containing the
`UIDAM_USER_VERIFY_ACCOUNT` and `UIDAM_USER_PASSWORD_RECOVERY` templates, and mounts
it at `/notification`. Set it to `false` if you supply your own catalogue.

### SMTP Configuration

Chart-level SMTP settings and credentials live under the top-level `notification`
block. These feed the global ConfigMap **and** the `smtp_username` / `smtp_passwd`
keys of every rendered Secret.

```yaml
notification:
  email:
    provider: "internal"          # internal (Spring Mail) | ignite (Notification Center)
    host: "TO-BE-UPDATED"
    port: "587"
    username: "TO-BE-UPDATED"     # -> Secret key smtp_username
    passwd: "TO-BE-UPDATED"       # -> Secret key smtp_passwd
    smptAuth: "true"
    smptStartTls: "true"
    smptStartTlsRequired: "true"
    smptSSLEnabled: "false"
    smtpDebug: "false"
    overrideSender: "admin@example.com"
    mailingService:
      enabled: false              # Route through an ExternalName service instead
      url: mailing-service
      port: "587"
```

> Per-tenant SMTP host/port/TLS flags can be overridden under
> `multiTenant.tenants.<id>.notification.email`. The **credentials** always come from
> the tenant Secret, which defaults to these top-level values.

### Email Configuration Examples

#### Gmail

```yaml
notification:
  email:
    provider: "internal"
    host: "smtp.gmail.com"
    port: "587"
    username: "your-email@gmail.com"
    passwd: "your-app-password"   # App Password, not your Gmail password
    smptAuth: "true"
    smptStartTls: "true"
    smptStartTlsRequired: "true"
    smptSSLEnabled: "false"
    overrideSender: "noreply@yourdomain.com"
```

**Setup Steps:**
1. Enable 2-factor authentication on the Google account
2. Generate an App Password: Google Account -> Security -> App passwords
3. Use the App Password in `passwd`

#### AWS SES

```yaml
notification:
  email:
    provider: "internal"
    host: "email-smtp.us-east-1.amazonaws.com"
    port: "587"
    username: "YOUR_SES_SMTP_USERNAME"
    passwd: "YOUR_SES_SMTP_PASSWORD"
    smptAuth: "true"
    smptStartTls: "true"
    smptStartTlsRequired: "true"
    smptSSLEnabled: "false"
    overrideSender: "noreply@verified-domain.com"
```

**Setup Steps:**
1. Verify the email address or domain in the SES console
2. Create SMTP credentials: SES -> SMTP Settings -> Create SMTP Credentials
3. Move out of the SES sandbox for production use
4. Configure sending limits and bounce handling

#### SendGrid

```yaml
notification:
  email:
    provider: "internal"
    host: "smtp.sendgrid.net"
    port: "587"
    username: "apikey"            # Literally the string "apikey"
    passwd: "SG.your-sendgrid-api-key"
    smptAuth: "true"
    smptStartTls: "true"
    smptStartTlsRequired: "true"
    smptSSLEnabled: "false"
    overrideSender: "noreply@yourdomain.com"
```

**Setup Steps:**
1. Create a SendGrid account
2. Verify the sender email/domain
3. Create an API Key: Settings -> API Keys -> Create API Key
4. Select the "Mail Send" permission
5. The username is always `apikey`

#### Office 365

```yaml
notification:
  email:
    provider: "internal"
    host: "smtp.office365.com"
    port: "587"
    username: "noreply@yourdomain.com"
    passwd: "TO-BE-UPDATED"
    smptAuth: "true"
    smptStartTls: "true"
    smptStartTlsRequired: "true"
    smptSSLEnabled: "false"
```

**Port Selection:**
- `25`: Standard SMTP (often blocked by cloud providers)
- `587`: SMTP with STARTTLS (recommended)
- `465`: SMTPS (SMTP over SSL) - also set `smptSSLEnabled: "true"`
- `2525`: Alternative port offered by some providers

---

## Data Archival CronJob

> **New in chart 1.6.0.**

The chart can schedule a per-tenant archival job that calls the
`run_archival_job(<tenant>)` stored procedure in the tenant database, moving aged
records out of the live tables.

```yaml
# Runtime settings shared by every archival job
archival:
  image:
    repository: postgres
    tag: 16-alpine
    pullPolicy: IfNotPresent

multiTenant:
  tenants:
    default:
      archivalJob:
        enabled: false            # Baseline for all tenants
        scheduler: "*/30 * * * *"
    ecsp:
      archivalJob:
        enabled: true             # Override per tenant
        scheduler: "0 5 * * *"
```

**Behaviour:**
- One `CronJob` is rendered per tenant whose effective `archivalJob.enabled` is `true`,
  named `<release>-uidam-user-management-archival-<tenant>`.
- Host, port, database and schema are derived from that tenant's `database.jdbcUrl`
  and `database.defaultSchema`.
- Credentials are read from the tenant Secret (`username` / `password`).
- `concurrencyPolicy: Forbid` prevents overlapping runs; jobs time out after 30 minutes.

**Before enabling:**

1. Confirm the stored procedure exists in every target database:
   ```sql
   \c ecsp_db
   SELECT proname FROM pg_proc WHERE proname = 'run_archival_job';
   ```
   It is created by the UIDAM Liquibase changelog. If the query returns no rows, run
   the migration first.
2. Verify the tenant database user may execute the procedure and write to the
   archive tables.
3. Stagger `scheduler` values across tenants so several large tenants do not archive
   simultaneously.

**Verifying:**
```bash
kubectl get cronjob -n uidam | grep archival
kubectl create job -n uidam --from=cronjob/uidam-user-management-archival-ecsp archival-test
kubectl logs -n uidam job/archival-test
```

**Disabling:** set `archivalJob.enabled: false` for the tenant (or for `default` to
turn it off everywhere) and upgrade. The CronJob is removed on the next release.

---

## Password Policy Configuration

Password policies are **data-driven** and stored in the tenant database, not in
`values.yaml`. Manage them through the API:

```
GET    /v1/password-policies          # List policies
POST   /v1/password-policies          # Create a policy
PATCH  /v1/password-policies/{name}   # Update a policy
GET    /v1/users/password-policy      # Effective policy for the caller
```

The chart-level controls that influence password handling are:

| Location | Key | Purpose |
|----------|-----|---------|
| `multiTenant.tenants.<id>.user` | `passwordEncoder` | Hashing algorithm, e.g. `SHA-256` |
| `multiTenant.tenants.<id>.user` | `maxAllowedLoginAttempts` | Failed attempts before lockout |
| `multiTenant.tenants.<id>.user` | `temporaryLockEnabled` | Auto-unlock instead of permanent lock |
| `multiTenant.tenants.<id>.user` | `temporaryLockPeriodMinutes` | Lock duration |
| `multiTenant.tenants.<id>.captcha` | `enforceAfterNoOfFailures` | Failed attempts before captcha |
| `multiTenant.tenants.<id>.recovery` | `secretExpiresInMinutes` | Recovery token lifetime |

> Earlier revisions of this chart exposed `password.minLength`, `password.maxLength`,
> `password.updateTimeInterval` and `password.policyCheckEnabled` in `values.yaml`.
> Those keys were never consumed by the templates and have been removed; use the
> password-policy API instead.

### Password Expiration Workflow

When a password expires according to the active policy:
1. Login succeeds
2. The API returns a status indicating the password has expired
3. The user must change the password before accessing the application
4. The new password must differ from the previous one
5. Password history is retained per the policy

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

- [ ] PostgreSQL database created and accessible (one database per tenant)
- [ ] Schema named in `database.defaultSchema` created and owned by the connection user
- [ ] SMTP server configured and credentials obtained
- [ ] All `ChangeMe` / `TO-BE-UPDATED` placeholders replaced
- [ ] `clientSecretKey` / `clientSecretSalt` match the Authorization Server per tenant
- [ ] MFA encryption key and salt generated (if MFA will be used)
- [ ] Authorization Server deployed and accessible
- [ ] `multiTenant.tenantIds` matches the Authorization Server tenant list
- [ ] Network policies configured
- [ ] Resource limits set appropriately

### Install

```bash
helm install uidam-user-management ./uidam-user-management \
  -n uidam --create-namespace \
  -f my-values.yaml
```

The release name matters: the chart's fullname helper produces
`<release>-uidam-user-management` unless the release name already contains the chart
name. Using `uidam-user-management` as the release name keeps resource names short
and makes `postgresql.secretName` line up with the rendered Secret.

### Verify the rendered output before installing

```bash
# Full render
helm template uidam-user-management ./uidam-user-management -f my-values.yaml

# Confirm the expected tenant ConfigMaps and Secrets appear
helm template uidam-user-management ./uidam-user-management -f my-values.yaml \
  | grep -E '^kind:|^  name:'

# Confirm no placeholder survived
helm template uidam-user-management ./uidam-user-management -f my-values.yaml \
  | grep -E 'ChangeMe|TO-BE-UPDATED'
```

### Post-install checks

```bash
kubectl get configmap -n uidam | grep uidam-user-management
kubectl get secret    -n uidam | grep uidam-user-management
kubectl rollout status deployment/uidam-user-management -n uidam
kubectl logs -n uidam deployment/uidam-user-management | grep -i tenant
```

You should see one `...-tenant-<id>` ConfigMap and one `...-tenant-<id>-credentials`
Secret for every entry in `multiTenant.tenantIds`, plus the `default` pair.

### Upgrade

```bash
helm upgrade uidam-user-management ./uidam-user-management \
  -n uidam -f my-values.yaml
```

ConfigMap and Secret changes trigger a pod restart automatically - the Deployment
carries `checksum/config`, `checksum/config-default` and `checksum/config-tenants`
annotations.

---

## Upgrading From Chart 1.2.x

Chart 1.6.0 changes the template layout and the tenant configuration model. The
application image must be upgraded to `1.6.0` at the same time.

### 1. Templates that were replaced

| Removed | Replaced by |
|---------|-------------|
| `configmap-tenant-default.yaml` | `configmap-default-configurations.yaml` |
| `configmap-tenant-ecsp.yaml`, `configmap-tenant-sdp.yaml` | `configmap-tenants-config.yaml` (dynamic) |
| `secret-tenant-default.yaml`, `secret-tenant-ecsp.yaml`, `secret-tenant-sdp.yaml` | `secret-tenants.yaml` (dynamic) |

Helm removes the old objects automatically on upgrade, because the generated
resources keep the same names.

### 2. Environment variable naming changed

Tenant settings are now published as `tenants_profile_<tenant>_*` instead of
`ECSP_*` / `SDP_*`. This matches what UIDAM 2.x binds. No action is needed unless
you referenced the old names in external tooling.

### 3. Restructure your tenant values

Move everything that is common into `multiTenant.tenants.default` and reduce each
other tenant to its overrides:

```yaml
# Before (1.2.x) - every tenant repeated the full block
multiTenant:
  tenants:
    ecsp:
      tenantId: "ecsp"
      account: { accountName: "ecsp", accountType: "Root" }
      user: { passwordEncoder: "SHA-256", maxAllowedLoginAttempts: 3, ... }
      clientRegistration: { defaultStatus: "approved", ... }
      # ...40 more lines

# After (1.6.0) - only the deltas
multiTenant:
  tenants:
    ecsp:
      tenantId: "ecsp"
      tenantName: "ECSP"
      account:
        accountName: "ecsp"
      database:
        jdbcUrl: "jdbc:postgresql://postgresql:5432/ecsp_db"
```

Leaving the full block in place still works - it simply produces a larger tenant
ConfigMap - so this step can be done gradually.

### 4. New values to set

```yaml
multiTenant:
  tenants:
    default:
      user:
        temporaryLockEnabled: true
        temporaryLockPeriodMinutes: 30
      mfa:
        mfaAppName: "UIDAM"
        backupCodesEnabled: false
        backupCodesCount: 8
      archivalJob:
        enabled: false
        scheduler: "*/30 * * * *"

secrets:
  mfaSecretEncryptionKey: "ChangeMe"
  mfaSecretEncryptionSalt: "ChangeMe"

tenantSecrets:
  <tenant>:
    mfaSecretEncryptionKey: "ChangeMe"
    mfaSecretEncryptionSalt: "ChangeMe"

archival:
  image:
    repository: postgres
    tag: 16-alpine
    pullPolicy: IfNotPresent
```

### 5. Values that were removed

These keys were present in `values.yaml` but never read by any template. They are
gone; delete them from your overrides:

`uidam.account_id`, `uidam.account_name`, `uidam.account_type`,
`maxAllowedLoginAttempts`, `minPasswordLength`, `maxPasswordLength`,
`passwordUpdateTimeInterval`, `user_status_life_cycle_enabled`,
`userDefaultAccountName`, `external_user_permitted_roles`,
`external_user_default_status`, `additional_attr_check_enabled_for_sign_up`,
`auth.server.*`, `revoke_token_client_id`.

Their functional equivalents now live under `multiTenant.tenants.<id>`.

### 6. Upgrade order

1. Upgrade `uidam-authorization-server` to 1.6.0 first.
2. Upgrade `uidam-user-management` to 1.6.0.
3. Confirm both charts use identical `clientSecretKey` / `clientSecretSalt` per tenant.

### 7. Rollback

```bash
helm rollback uidam-user-management -n uidam
```

Liquibase migrations applied by 1.6.0 are **not** reverted by a Helm rollback. Take a
database backup before upgrading.

---

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
# Check tenant configmaps exist (one per active tenant, plus -tenant-default)
kubectl get configmap -n uidam | grep tenant

# Verify tenant secret exists
kubectl get secret -n uidam | grep tenant

# Check logs for tenant initialization
kubectl logs -n uidam <pod-name> | grep -i "tenant"

# Inspect what a tenant actually overrides
kubectl get configmap -n uidam uidam-user-management-tenant-ecsp -o yaml

# Confirm the baseline the tenant inherits from
kubectl get configmap -n uidam uidam-user-management-tenant-default -o yaml

# Common causes:
# - Tenant ID mismatch with Auth Server
# - Tenant key missing from multiTenant.tenantIds, so no ConfigMap was rendered
# - Multi-tenant not enabled
# - Default tenant not set
```

**A setting is not taking effect for one tenant:**

Because a tenant ConfigMap only carries overrides, a missing key means the value is
inherited from `-tenant-default`. Check the default ConfigMap before assuming the
value is lost:

```bash
kubectl get configmap -n uidam uidam-user-management-tenant-default -o yaml \
  | grep -i <setting>
```

Remember that omitting a key means "inherit"; to blank a value, set it explicitly
to `""` in the tenant block.

**ConfigMap ordering:** the Deployment loads the global ConfigMap, then
`-tenant-default`, then each tenant ConfigMap. Later entries win, so a key present in
both the global and a tenant ConfigMap resolves to the tenant value.

#### 6. MFA Enrolment Failures

**Symptoms:** Users cannot enrol, or previously working codes are rejected

```bash
# Confirm the MFA keys are present in the tenant secret
kubectl get secret -n uidam uidam-user-management-tenant-ecsp-credentials \
  -o jsonpath='{.data}' | tr ',' '\n' | grep -i mfa

# Check the app picked them up
kubectl exec -n uidam deploy/uidam-user-management -- \
  printenv | grep -i MFA_SECRET
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| All existing enrolments suddenly invalid | `mfaSecretEncryptionKey` or `...Salt` changed | Restore the previous values, or have every user re-enrol |
| Enrolment fails with a decryption error | Key/salt differ between replicas | Ensure a single Secret is used; restart all pods |
| Codes always rejected | Clock skew between the device and the cluster | Verify NTP on the nodes |

#### 7. Archival CronJob Failures

**Symptoms:** `...-archival-<tenant>` jobs fail

```bash
kubectl get cronjob -n uidam | grep archival
kubectl get jobs -n uidam | grep archival
kubectl logs -n uidam job/<archival-job-name>
```

| Error | Cause | Fix |
|-------|-------|-----|
| `function run_archival_job(...) does not exist` | Liquibase migration has not run for that tenant | Start the service once against that database, then re-run the job |
| `permission denied for schema` | Tenant DB user lacks EXECUTE | Grant execute on the procedure and write access to the archive tables |
| `Unable to connect to PostgreSQL` | Host/port parsed from `database.jdbcUrl` is wrong | Verify the JDBC URL format `jdbc:postgresql://HOST:PORT/DB` |
| Job never starts | `archivalJob.enabled` is false for that tenant | Remember the tenant value overrides `default` |

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
- `GET /v1/users/password-policy` - Effective password policy for the caller
- `GET /v1/password-policies` - List password policies
- `POST /v1/password-policies` - Create a password policy
- `PATCH /v1/password-policies/{name}` - Update a password policy

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
- `templates/configmap.yaml` - Global environment variables
- `templates/configmap-default-configurations.yaml` - Default tenant baseline (`DEFAULT_*`)
- `templates/configmap-tenants-config.yaml` - Per-tenant overrides, generated dynamically
- `templates/secret.yaml` - Global credentials Secret
- `templates/secret-tenants.yaml` - Per-tenant Secrets, generated dynamically
- `templates/archival-cronjob.yaml` - Per-tenant data archival CronJob
- `templates/notification-config.yaml` - Default notification catalogue
- `templates/deployment.yaml` - Deployment specification
- `templates/service.yaml` - Service configuration
- `templates/ingress.yaml` - Ingress configuration
- `templates/mailing-service.yaml` - Optional ExternalName service for SMTP relay

### Adding a New Tenant

No template changes are required - edit `values.yaml` only:

1. Append the tenant ID to `multiTenant.tenantIds`, e.g. `"ecsp,sdp,acme"`.
2. Add an override block under `multiTenant.tenants.acme` containing at minimum
   `tenantId`, `tenantName`, `account.accountName` and `database.jdbcUrl`.
   Everything else is inherited from the `default` tenant.
3. Add `tenantSecrets.acme` with that tenant's secrets. Any key you omit is
   inherited from `tenantSecrets.default`.
4. Create the tenant database and the schema named in `database.defaultSchema`.
5. Mirror steps 1-3 in the `uidam-authorization-server` chart, keeping
   `clientSecretKey` / `clientSecretSalt` and the MFA keys identical.
6. `helm upgrade`. A new ConfigMap and Secret pair appear automatically, and
   Liquibase migrates the new schema on the next pod start.

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
   - Keep shared settings in the `default` tenant and override only deltas
   - Monitor per-tenant metrics
   - Configure tenant-specific quotas
   - Implement tenant-aware logging

---

---

**Document Version:** 2.0  
**Last Updated:** September 30, 2026  
**Component Version:** 1.6.0
