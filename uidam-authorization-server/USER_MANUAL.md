# UIDAM Authorization Server - User Manual

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Chart Structure](#chart-structure)
4. [Configuration Guide](#configuration-guide)
5. [Multi-Tenant Configuration](#multi-tenant-configuration)
6. [Multi-Factor Authentication](#multi-factor-authentication)
7. [Sign-Up Configuration](#sign-up-configuration)
8. [Security & Secrets Management](#security--secrets-management)
9. [Database Configuration](#database-configuration)
10. [External IDP Integration](#external-idp-integration)
11. [Monitoring & Metrics](#monitoring--metrics)
12. [Deployment](#deployment)
13. [Upgrading From Chart 1.2.x](#upgrading-from-chart-12x)
14. [Troubleshooting](#troubleshooting)

---

## Overview

The UIDAM Authorization Server is an OAuth2/OIDC compliant authorization server that provides authentication and authorization services. It supports both single-tenant and multi-tenant deployments with configurable external Identity Provider (IDP) integrations.

### Key Features
- OAuth2 and OpenID Connect support
- Multi-tenant architecture
- External IDP integration (Google, GitHub, Azure, Cognito and etc)
- JWT token management with customizable claims
- Role-based access control (RBAC)
- Password policy management
- User self-registration with CAPTCHA
- Token lifecycle management
- Multi-factor authentication with step-up policies
- Per-client sign-up customisation

---

## Prerequisites

Before deploying the UIDAM Authorization Server, ensure you have:

1. **Kubernetes Cluster** (v1.19+)
2. **Helm** (v3.0+)
3. **PostgreSQL Database** (v12+)
4. **Domain Name** for ingress configuration
5. **SSL/TLS Certificates** (if using HTTPS)
6. **External IDP Credentials** (optional, for federated authentication)

---

## Chart Structure

The chart renders one ConfigMap for global settings, one ConfigMap holding the
**default tenant** configuration, and one ConfigMap **per active tenant** that only
contains the keys that tenant overrides. Secrets follow the same pattern.

| Template | Renders | Notes |
|----------|---------|-------|
| `templates/configmap.yaml` | `<release>-uidam-authorization-server` | Global, tenant-independent settings |
| `templates/configmap-default-configurations.yaml` | `<release>-uidam-authorization-server-tenant-default` | Full `DEFAULT_*` baseline, always rendered |
| `templates/configmap-tenants-config.yaml` | `<release>-uidam-authorization-server-tenant-<id>` | One per active tenant, generated dynamically |
| `templates/secret.yaml` | `<release>-uidam-authorization-server-credentials` | Global credentials |
| `templates/secret-tenants.yaml` | `<release>-uidam-authorization-server-tenant-<id>-credentials` | One per active tenant **plus** `default` |
| `templates/uidam-jks.yaml` | `<release>-uidam-authorization-server-jks` | Fallback keystore file |
| `templates/app-keys.yaml` | `<release>-uidam-authorization-server-app` | JWT key pair and public PEM |

### How tenant resolution works

1. `configmap-default-configurations.yaml` publishes the complete configuration as
   `DEFAULT_*` environment variables. These back the `tenant-default.properties`
   placeholders inside the application image.
2. `configmap-tenants-config.yaml` iterates over `multiTenant.tenants` and emits
   `tenants_profile_<tenant>_*` keys **only for the fields a tenant actually defines**.
3. The Deployment mounts the global ConfigMap first, then each tenant ConfigMap, then
   the default ConfigMap, so anything a tenant does not override falls back to the
   default tenant values.

A tenant is considered active when its key appears in `multiTenant.tenantIds` or
equals `multiTenant.defaultTenant`. Adding a tenant is therefore a values-only
change - no new template files are needed.

---

## Configuration Guide

### Basic Configuration (`values.yaml`)

#### 1. Image Configuration

```yaml
image:
  repository: docker.io/eclipseecsp/uidam-authorization-server
  pullPolicy: IfNotPresent
  tag: 1.6.0
```

**Action Required:**
- Update `repository` to your container registry if there is any customization done and generated image in your custom repository.
- Update `tag` to the desired version
- Keep this in step with the `uidam-user-management` image tag

#### 2. Environment Domain Configuration

```yaml
environmentDomainName: ecsp.example.com
```

**Action Required:**
- Replace `ecsp.example.com` with your actual domain name
- This domain is used for:
  - Ingress hostname construction
  - Password recovery URLs
  - OAuth2 redirect URIs

#### 3. Resource Configuration

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
- Adjust CPU and memory based on expected load
- Recommended minimum: 512Mi memory, 500m CPU

#### 4. Java Options

```yaml
javaOpts: -Xms128m -Xmx512m -XX:+UseG1GC -XX:+UseStringDeduplication -XX:MaxMetaspaceSize=256m
```

**Action Required:**
- Adjust heap size (`-Xmx`) based on available resources
- Ensure `-Xmx` is less than container memory limit
- Recommended: Set `-Xmx` to 70-80% of container memory

#### 5. Config Server (optional)

```yaml
configServer:
  host: "http://config-server:8080/config/"
  enabled: false
  springConfigImport: "optional:classpath:tenant-default.properties"
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
```

**Action Required:**
1. Set `enabled: true` to activate multi-tenant mode
2. Update `tenantIds` with comma-separated tenant identifiers
3. Set `defaultTenant` to the primary tenant which will be root tenant when mulit-tenant is disabled

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
      externalIdpEnabled: false
      ui:
        logoPath: "/images/ecsp-logo.svg"
      account:
        accountId: "TO-BE-UPDATED"
        accountName: "ecsp"
      keyStore:
        keyAlias: "ecsp-uidam-auth-server"
        jksEncodedContent: "ChangeMe"
      cert:
        jwtKeyId: "TO-BE-UPDATED"
      database:
        jdbc_url: "jdbc:postgresql://postgresql:5432/ecsp_db"
      mfa:
        mode: "DISABLED"
        skipUsers: "admin,tenantadmin"

    # The full baseline
    default:
      tenantId: "default"
      tenantName: "DEFAULT"
      # ... every section below ...
```

**Benefits:**
- Adding a tenant is typically 15-20 lines instead of ~70.
- Shared settings are changed in exactly one place.
- The tenant ConfigMap becomes an accurate diff of what is genuinely custom.

**Caveat:** because omission means inheritance, you cannot "unset" a value by
removing it. To blank a field, set it explicitly to `""`.

**Per-tenant items that must always be set:** `tenantId`, `tenantName`,
`database.jdbc_url`, `keyStore.keyAlias`, `keyStore.jksEncodedContent` and
`cert.jwtKeyId`. Sharing a keystore alias or JWT key ID across tenants breaks token
isolation.

### Tenant Configuration Reference

The sections below are valid for the `default` tenant and for any tenant override.

#### Account Configuration

```yaml
account:
  accountId: "TO-BE-UPDATED"        # Unique account identifier (default account created in DB on first-startup)
  accountName: "ecsp"                # Account display name
  accountType: "Root"                # Account type: Root, Sub, etc.
  accountFieldEnabled: true          # Enable account field in tokens
```

**Action Required:**
- Generate unique `accountId` for each tenant (UUID recommended)
- Set descriptive `accountName`
- Configure `accountType` based on your hierarchy

#### Client/Token Configuration

```yaml
client:
  accessTokenTtl: 3600        # Access token lifetime (seconds)
  idTokenTtl: 3600            # ID token lifetime (seconds)
  refreshTokenTtl: 3600       # Refresh token lifetime (seconds)
  authCodeTtl: 300            # Authorization code lifetime (seconds)
  oauthScopeCustomization: false
  authCodeScopelessUserScopes: true   # New in 1.6.0
  reuseRefreshToken: false
  idTokenProperties:                  # New in 1.6.0
    additionalClaims: ""
```

**Action Required:**
- Adjust TTL values based on security requirements
- Shorter TTLs = more secure but more frequent token refreshes
- Recommended: accessTokenTtl: 3600, refreshTokenTtl: 86400

**New in 1.6.0:**

| Key | Purpose |
|-----|---------|
| `authCodeScopelessUserScopes` | When `true`, an authorization-code request that asks for no scopes receives the user's full scope set. When `false`, a scopeless request yields a token with no scopes. |
| `idTokenProperties.additionalClaims` | Comma-separated user attributes to copy into the **ID token** (separate from `user.jwtAdditionalClaimAttributes`, which targets the access token). Leave empty to add none. |

#### UI Configuration

```yaml
ui:
  logoPath: "/images/default-logo.svg"
```

Path to the logo shown on that tenant's login and consent pages. Set a distinct value
per tenant so users can tell branded login pages apart. The file must exist in the
image's static resources or in the custom UI volume.

#### User Configuration

```yaml
user:
  captchaAfterInvalidFailures: 1    # Show CAPTCHA after N failed attempts
  captchaRequired: false             # Require CAPTCHA on all logins
  maxAllowedLoginAttempts: 3         # Lock account after N attempts
  defaultRole: "VEHICLE_OWNER"       # Default role for new users, can be updated as needed
  signUpEnabled: true                # Enable self-registration
  jwtAdditionalClaimAttributes: "accountType, accountName"
```

**Action Required:**
- Configure brute-force protection (`maxAllowedLoginAttempts`)
- Set appropriate `defaultRole` for your application
- Configure CAPTCHA settings if using Google reCAPTCHA
- List additional JWT claims in `jwtAdditionalClaimAttributes`

#### External URLs Configuration

```yaml
externalUrls:
  userManagementUrl: "http://uidam-user-management:8080"
  clientByClientIdEndpoint: "/v1/oauth2/client/{clientId}"
  userByUsernameEndpoint: "/v1/users/{userName}/byUserName"
  recoveryNotificationEndpoint: "/v1/users/{userName}/recovery/forgotpassword"
  updatePasswordUsingSecretEndpoint: "/v1/users/recovery/set-password"
  addUserEventsEndpoint: "/v1/users/{id}/events"
  selfCreateUserEndpoint: "/v1/users/self"
  passwordPolicyEndpoint: "/v1/users/password-policy"
  createFedratedUserEndpoint: "/v1/users/federated"
```

**Action Required:**
- Update `userManagementUrl` if using external URL or different namespace
- Keep endpoint paths unless customizing the user-management API

#### KeyStore Configuration

```yaml
keyStore:
  keyStoreFilename: "uidamauthserver.jks"
  keyAlias: "uidam-auth-server" # kestore alias, password to be updated in secrets
  keyType: "JKS"
  jwtPubKeyPem: "/app/uidam-pub-key-pem"
  jksEncodedContent: "ChangeMe"  # Base64-encoded JKS file if this is null or empty then it fallback to file mentioned in keyStoreFilename
```

**Action Required:**
1. **Generate Java KeyStore:**
   ```bash
   keytool -genkeypair -alias uidam-auth-server \
     -keyalg RSA -keysize 2048 -validity 3650 \
     -keystore uidamauthserver.jks \
     -storepass YourStrongPassword
   ```

2. **Base64 encode the JKS file:**
   ```bash
   base64 -w 0 uidamauthserver.jks > jks.base64
   ```

3. **Update values:**
   - Replace `jksEncodedContent: "ChangeMe"` with the base64 content
   - Store JKS password in `tenantSecrets.ecsp.keystorePassword`

#### Certificate Configuration

```yaml
cert:
  jwtPublicKey: "app.pub"
  jwtPrivateKey: "app.key"
  jwtKeyId: "TO-BE-UPDATED"  # Unique key identifier, prefix with tenantId.
```

**Action Required:**
1. **Generate RSA key pair:**
   ```bash
   # Generate private key
   openssl genrsa -out app.key 2048
   
   # Extract public key
   openssl rsa -in app.key -pubout -out app.pub
   
   # Generate key ID (can be any unique string)
   echo "jwt-key-$(date +%s)" > key.id
   ```

2. **Update values.yaml:**
   - Update `jwtKeyId` with unique identifier (e.g., "jwt-key-2025-001")
   - Store private key content in `app_key` section
   - Store public key content in `app_pub` section

#### CAPTCHA Configuration

```yaml
captcha:
  recaptchaVerifyUrl: "https://www.google.com/recaptcha/api/siteverify"
  recaptchaKeySite: "ChangeMe"
```

**Action Required:**
1. **Register site with Google reCAPTCHA:**
   - Visit: https://www.google.com/recaptcha/admin/create
   - Select reCAPTCHA v2 or v3
   - Add your domain(s)
   - Get site key and secret key

2. **Update configuration:**
   - Replace `recaptchaKeySite: "ChangeMe"` with site key
   - Store secret key in `tenantSecrets.ecsp.igniteRecaptchaKeySecret`

#### Database Configuration (Per Tenant)

```yaml
database:
  jdbc_url: "jdbc:postgresql://postgresql:5432/ecsp_db" # DB details to be updated as needed.
```

**Action Required:**
- Create separate database for each tenant
- Update JDBC URL with correct host, port, and database name
- Format: `jdbc:postgresql://HOST:PORT/DATABASE_NAME`
- The driver class is set by the chart; you do not need to configure it
- Credentials come from the tenant Secret (`username` / `password`), not from this block

---

## Multi-Factor Authentication

> **New in chart 1.6.0.**

MFA policy is decided here; enrolment data is stored and encrypted by the
`uidam-user-management` service.

```yaml
multiTenant:
  tenants:
    default:
      mfa:
        mfaAppName: "UIDAM"
        mode: "DISABLED"                                  # DISABLED | CONDITIONAL | REQUIRED
        stepUpScopes: "UIDAMSystem,ManageUsers,ManageAccounts"
        skipUsers: "admin,tenantadmin"
        skipClients: ""
        skipAccounts: ""
        stepUpClients: ""
        stepUpAccounts: ""
```

### Modes

| Mode | Behaviour |
|------|-----------|
| `DISABLED` | MFA is never challenged. Safe default. |
| `CONDITIONAL` | MFA is challenged only for step-up situations - a request for a scope in `stepUpScopes`, or a client/account listed in `stepUpClients` / `stepUpAccounts`. |
| `REQUIRED` | Every interactive login requires MFA, except the exclusions below. |

### Exclusions

| Key | Effect |
|-----|--------|
| `skipUsers` | Comma-separated usernames that never get an MFA challenge. Keep at least one break-glass admin here. |
| `skipClients` | Client IDs exempt from MFA, e.g. machine-to-machine clients. |
| `skipAccounts` | Account names exempt from MFA. |

### Step-up triggers (CONDITIONAL mode)

| Key | Effect |
|-----|--------|
| `stepUpScopes` | Requesting any of these scopes forces a fresh MFA challenge. |
| `stepUpClients` | These client IDs always trigger a challenge. |
| `stepUpAccounts` | These account names always trigger a challenge. |

### Rollout guidance

1. Deploy with `mode: "DISABLED"` and let users enrol voluntarily.
2. Move to `CONDITIONAL` and list your privileged scopes in `stepUpScopes`.
3. Only move to `REQUIRED` once enrolment coverage is high, and keep
   `skipUsers` populated so you cannot lock yourself out.

**Required companion configuration:** set `mfaSecretEncryptionKey` and
`mfaSecretEncryptionSalt` in this chart's `tenantSecrets` **and** in the matching
`uidam-user-management` tenant secrets. The enrolment app name shown in authenticator
apps comes from `mfa.mfaAppName`.

---

## Sign-Up Configuration

> **New in chart 1.6.0.**

```yaml
multiTenant:
  tenants:
    default:
      user:
        signUpEnabled: true
      signup:
        additionalAttributesEnabled: false
      clientSpecificSignupConfigs: []
```

`signup.additionalAttributesEnabled` turns on collection of custom attributes during
self-registration.

### Per-client sign-up customisation

`clientSpecificSignupConfigs` lets a single tenant present different sign-up rules
depending on which OAuth2 client started the flow:

```yaml
clientSpecificSignupConfigs:
  - clientId: "partner-portal"
    skipAttributes: "hasValidPassport"
    defaultRoles: "VEHICLE_OWNER"
    defaultAccount: "userdefaultaccount"
    customAttributeListMap: "custom:companyName#VW,signupSourceClientId#partner-portal"
    userStatus: ""
    customAttributesForClaims: "ATTR_custom:companyName"
```

| Key | Purpose |
|-----|---------|
| `clientId` | The OAuth2 client this configuration applies to. |
| `skipAttributes` | Comma-separated attributes to omit from the sign-up form. |
| `defaultRoles` | Roles assigned to users who register through this client. |
| `defaultAccount` | Account the new user is attached to. |
| `customAttributeListMap` | `attribute#value` pairs pre-filled on the created user. |
| `userStatus` | Initial status; empty means the tenant default. |
| `customAttributesForClaims` | Attributes promoted into token claims, prefixed `ATTR_`. |

Leave the list empty (`[]`) to apply the same sign-up rules to every client.

---

## Security & Secrets Management

> **Changed in chart 1.6.0.** The three hand-maintained `secret-tenant-<id>.yaml`
> templates were replaced by a single `secret-tenants.yaml` that generates one Secret
> per active tenant. Secrets are declared in `values.yaml` only.

### Rendered Secrets

| Secret | Source | Consumed as |
|--------|--------|-------------|
| `<release>-uidam-authorization-server-credentials` | `secrets`, `postgresql` | Global env vars (`POSTGRES_USERNAME`, `KEYSTORE_PASS`, ...) |
| `<release>-uidam-authorization-server-tenant-default-credentials` | `tenantSecrets.default` | `DEFAULT_*` env vars |
| `<release>-uidam-authorization-server-tenant-<id>-credentials` | `tenantSecrets.<id>` merged over `tenantSecrets.default` | `tenants_profile_<id>_*` env vars |

Any key a tenant omits is inherited from `tenantSecrets.default`, mirroring the
configuration inheritance model.

### Global Secrets

These back the non-tenant-scoped environment variables:

```yaml
secrets:
  keystorePassword: "ChangeMe"
  igniteRecaptchaKeySecret: "ChangeMe"
  clientsecretkey: "ChangeMe"
  clientsecretsalt: "ChangeMe"
  clientSecret: "ChangeMe"
  mfaSecretEncryptionKey: "ChangeMe"
  mfaSecretEncryptionSalt: "ChangeMe"
```

### Tenant-Specific Secrets

```yaml
tenantSecrets:
  default:
    keystorePassword: "ChangeMe"
    igniteRecaptchaKeySecret: "ChangeMe"
    clientsecretkey: "ChangeMe"
    clientsecretsalt: "ChangeMe"
    clientSecret: "ChangeMe"
    mfaSecretEncryptionKey: "ChangeMe"
    mfaSecretEncryptionSalt: "ChangeMe"
    googleIDPSecret: "ChangeMe"
    githubIDPSecret: "ChangeMe"
    cognitoIDPSecret: "ChangeMe"
    azureIDPSecret: "ChangeMe"
  ecsp:
    # only the keys that differ from `default`
    keystorePassword: "ChangeMe"
    clientsecretkey: "ChangeMe"
    clientsecretsalt: "ChangeMe"
    mfaSecretEncryptionKey: "ChangeMe"
    mfaSecretEncryptionSalt: "ChangeMe"
```

### Key Reference

| Key | Purpose | Suggested generation |
|-----|---------|----------------------|
| `keystorePassword` | Password of the JKS holding the token signing key. Must match the password used with `keytool`. | Strong passphrase |
| `igniteRecaptchaKeySecret` | Google reCAPTCHA **secret** key (the site key is `captcha.recaptchaKeySite`). | From the reCAPTCHA console |
| `clientsecretkey` | Encrypts OAuth2 client secrets at rest. **Must match `uidam-user-management`.** | `openssl rand -base64 32` |
| `clientsecretsalt` | Salt for client secret hashing. **Must match `uidam-user-management`.** | `openssl rand -base64 16` |
| `clientSecret` | Default secret for internally provisioned clients. | `openssl rand -base64 24` |
| `mfaSecretEncryptionKey` | Encrypts stored TOTP seeds. **Must match `uidam-user-management`.** | `openssl rand -base64 32` |
| `mfaSecretEncryptionSalt` | Salt for TOTP seed encryption. **Must match `uidam-user-management`.** | `openssl rand -base64 16` |
| `googleIDPSecret` | OAuth2 client secret from Google Cloud Console | Provider console |
| `githubIDPSecret` | OAuth App secret from GitHub | Provider console |
| `cognitoIDPSecret` | App client secret from AWS Cognito | Provider console |
| `azureIDPSecret` | Client secret from Azure AD app registration | Provider console |

> **Important:** changing `mfaSecretEncryptionKey` or `mfaSecretEncryptionSalt` after
> users have enrolled invalidates every existing enrolment. Users must re-enrol.

### How external IDP secrets are wired

`templates/deployment.yaml` walks each tenant's `externalIdpRegisteredClients` list
and maps entry *N* to the Secret key `<clientName in lowercase>IDPSecret`:

```
externalIdpRegisteredClients[0].clientName: Google
  -> env tenants_profile_<tenant>_external-idp-registered-client-list[0]_client-secret
  -> secret key  googleIDPSecret
```

This means **`clientName` must be one of `Google`, `Github`, `Cognito` or `Azure`**
unless you also add the matching `<name>IDPSecret` key to
`templates/secret-tenants.yaml`. The index is positional, so reordering the list
reorders which secret each client receives - always append new providers at the end.

### Cross-Chart Consistency

These values **must be identical** in the `uidam-user-management` chart for the same
tenant, otherwise client secrets and MFA enrolments written by one service cannot be
read by the other:

| uidam-authorization-server | uidam-user-management |
|----------------------------|-----------------------|
| `tenantSecrets.<id>.clientsecretkey` | `tenantSecrets.<id>.clientSecretKey` |
| `tenantSecrets.<id>.clientsecretsalt` | `tenantSecrets.<id>.clientSecretSalt` |
| `tenantSecrets.<id>.mfaSecretEncryptionKey` | `tenantSecrets.<id>.mfaSecretEncryptionKey` |
| `tenantSecrets.<id>.mfaSecretEncryptionSalt` | `tenantSecrets.<id>.mfaSecretEncryptionSalt` |

Note the capitalisation differs between the two charts - this is intentional and
matches each chart's existing key names.

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

**Important Notes:**
- Secrets are base64-encoded automatically by Helm - the values in `values.yaml` are plaintext
- Never commit real secrets to git
- Rotate secrets regularly (every 90 days recommended), except the MFA keys

---
## Database Configuration

### PostgreSQL Connection

```yaml
postgres:
  host: postgresql
  port: 5432
  secretName: uidam-authorization-server-credentials
  userName: TO-BE-UPDATED
  password: TO-BE-UPDATED
  databaseName: postgresql
  schemaName: eclipseecsp
```

**Action Required:**

1. **Create Database:**
   ```sql
   -- Create database
   CREATE DATABASE uidam_auth_db;
   
   -- Create user
   CREATE USER uidam_auth_user WITH PASSWORD 'StrongPassword123!';
   
   -- Grant privileges
   GRANT ALL PRIVILEGES ON DATABASE uidam_auth_db TO uidam_auth_user;
   
   -- Create schema
   \c uidam_auth_db
   CREATE SCHEMA eclipseecsp;
   GRANT ALL ON SCHEMA eclipseecsp TO uidam_auth_user;
   ```

2. **Update Configuration:**
   - `host`: PostgreSQL service name or IP
   - `port`: PostgreSQL port (default: 5432)
   - `userName`: Database user (update in `postgresql.userName`)
   - `password`: Database password (update in `postgresql.password`)
   - `databaseName`: Database name
   - `schemaName`: Schema name for tables

### PostgreSQL Advanced Configuration

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
- Adjust `max_pool_size` based on concurrent users
- Formula: `max_pool_size = (concurrent_users * 2) + buffer`
- For 100 concurrent users: 30-50 connections
- For 500 concurrent users: 100-150 connections

### PostgreSQL Credentials

```yaml
postgresql:
  host: postgresql
  connection: postgresql
  port: 5432
  secretName: uidam-authorization-server-credentials
  userName: ChangeMe
  password: ChangeMe
```

**Action Required:**
- `userName` / `password` populate the `username` / `password` keys of **every**
  Secret the chart renders (global and per tenant).
- `secretName` must resolve to the rendered global Secret,
  i.e. `<release>-uidam-authorization-server-credentials`. Change it only if you
  manage that Secret yourself.
- `postgresql.host` / `postgresql.port` plus `postgres.databaseName` build the global
  `POSTGRES_DATASOURCE`. Per-tenant datasources come from each tenant's
  `database.jdbc_url`.

> If different tenants use different database users, set the credentials per tenant
> in `tenantSecrets.<tenant>` and extend `templates/secret-tenants.yaml` accordingly.
> Out of the box every tenant Secret reuses `postgresql.userName` / `postgresql.password`.

> The legacy top-level `tenant:` block in `values.yaml` is no longer read by any
> template. Its single-tenant environment variables were removed in 1.6.0 because
> they duplicated - and sometimes blanked - the multi-tenant values. It is retained
> only for backward compatibility with older overrides and can be deleted.

---

## External IDP Integration

### Configuring External Identity Providers

Each tenant can integrate with multiple external IDPs:

```yaml
externalIdpRegisteredClients:
  - clientName: Google
    registrationId: google
    enabled: false                     # New in 1.6.0 - per-provider on/off switch
    clientId: xxx
    clientAuthenticationMethod: client_secret_basic
    scope: "openid, profile, email, address, phone"
    authorizationUri: "https://accounts.google.com/o/oauth2/v2/auth"
    tokenUri: "https://www.googleapis.com/oauth2/v4/token"
    userInfoUri: "https://www.googleapis.com/oauth2/v3/userinfo"
    userNameAttributeName: "sub"
    jwkSetUri: "https://www.googleapis.com/oauth2/v3/certs"
    tokenInfoSource: "FETCH_INTERNAL_USER" # user details fetch from user-management API.
    includeIdpIdToken: false           # New in 1.6.0
    createUserMode: "CREATE_INTERNAL_USER" # create user in user-management if not exists (first time login)
    defaultUserRoles: "VEHICLE_OWNER" # can be updated as needed.
    claimMappings: "firstName#given_name,lastName#family_name,email#email"  # mapping external IDP client with Usermanagement user creation payload attribute
    scopePreference: "INTERNAL"        # New in 1.6.0 - INTERNAL | EXTERNAL
```

> `externalIdpRegisteredClients` is only consulted when the tenant also sets
> `externalIdpEnabled: true`.

### New Fields in 1.6.0

| Field | Values | Purpose |
|-------|--------|---------|
| `enabled` | `true` / `false` | Turn an individual provider on or off without deleting its configuration. Ship providers disabled and enable them once credentials are in place. |
| `includeIdpIdToken` | `true` / `false` | When `true`, the original IdP ID token is passed through in the UIDAM response. Only enable if a downstream client genuinely needs the upstream token. |
| `scopePreference` | `INTERNAL` / `EXTERNAL` | `INTERNAL` (default) issues the scopes UIDAM holds for the user. `EXTERNAL` derives scopes from IdP roles using `roleClaimKey` and `scopeRoleMappings`. |
| `roleClaimKey` | claim name | Which IdP claim carries the user's roles, e.g. `cognito:roles`. Required when `scopePreference: EXTERNAL`. |
| `scopeRoleMappings` | list | Maps external role values onto internal UIDAM scopes. |
| `conditions` | object | Optional gate - only apply this provider when a claim matches. Keys: `claimKey`, `expectedValue`, `operator`. |

**Mapping external roles to internal scopes:**

```yaml
  - clientName: Cognito
    registrationId: cognito
    enabled: true
    scopePreference: "EXTERNAL"
    roleClaimKey: "cognito:roles"
    scopeRoleMappings:
      - externalRoles: "arn:aws:iam::123456789012:role/ReadOnly"
        internalScopes: "IgniteStoreSeller"
      - externalRoles: "arn:aws:iam::123456789012:role/Admin"
        internalScopes: "UIDAMSystem,ManageUsers"
    claimMappings: "firstName#cognito:username,email#email,externalIdpRoles#cognito:roles"
```

> **Ordering matters.** The Deployment binds client secrets positionally -
> `externalIdpRegisteredClients[0]` receives the secret named after its `clientName`.
> Append new providers to the end of the list rather than inserting them, and see
> [How external IDP secrets are wired](#how-external-idp-secrets-are-wired).

### Google OAuth2 Setup

**Action Required:**

1. **Create OAuth2 Credentials:**
   - Go to: https://console.cloud.google.com/apis/credentials
   - Create OAuth 2.0 Client ID
   - Application type: Web application
   - Authorized redirect URIs: `https://your-domain.com/login/oauth2/code/google`

2. **Update Configuration:**
   ```yaml
   - clientName: Google
     registrationId: google
     clientId: "YOUR_GOOGLE_CLIENT_ID"
   ```

3. **Add Secret:**
   ```yaml
   tenantSecrets:
     ecsp:
       googleIDPSecret: "YOUR_GOOGLE_CLIENT_SECRET"
   ```

### GitHub OAuth Setup

**Action Required:**

1. **Create GitHub OAuth App:**
   - Go to: https://github.com/settings/developers
   - Click "New OAuth App"
   - Authorization callback URL: `https://your-domain.com/login/oauth2/code/github`

2. **Update Configuration:**
   ```yaml
   - clientName: Github
     registrationId: github
     clientId: "YOUR_GITHUB_CLIENT_ID"
     scope: "read:user"
   ```

3. **Add Secret:**
   ```yaml
   tenantSecrets:
     ecsp:
       githubIDPSecret: "YOUR_GITHUB_CLIENT_SECRET"
   ```

### Azure AD Setup

**Action Required:**

1. **Register Application in Azure:**
   - Go to: Azure Portal → Azure Active Directory → App registrations
   - Click "New registration"
   - Redirect URI: `https://your-domain.com/login/oauth2/code/azureidp`

2. **Update Configuration:**
   ```yaml
   - clientName: Azure
     registrationId: azureidp
     clientId: "YOUR_AZURE_CLIENT_ID"
   ```

3. **Add Secret:**
   ```yaml
   tenantSecrets:
     ecsp:
       azureIDPSecret: "YOUR_AZURE_CLIENT_SECRET"
   ```

### AWS Cognito Setup

**Action Required:**

1. **Create App Client in Cognito:**
   - Go to: AWS Console → Cognito → User Pools
   - Select your user pool
   - Create app client with client secret
   - Add callback URL: `https://your-domain.com/login/oauth2/code/cognito`

2. **Update Configuration:**
   ```yaml
   - clientName: Cognito
     registrationId: cognito
     clientId: "YOUR_COGNITO_CLIENT_ID"
     authorizationUri: "https://your-domain.auth.region.amazoncognito.com/oauth2/authorize"
     tokenUri: "https://your-domain.auth.region.amazoncognito.com/oauth2/token"
     userInfoUri: "https://your-domain.auth.region.amazoncognito.com/oauth2/userInfo"
     jwkSetUri: "https://cognito-idp.region.amazonaws.com/POOL_ID/.well-known/jwks.json"
   ```

3. **Add Secret:**
   ```yaml
   tenantSecrets:
     ecsp:
       cognitoIDPSecret: "YOUR_COGNITO_CLIENT_SECRET"
   ```

### Claim Mappings

Configure how IDP claims map to internal user attributes:

```yaml
claimMappings: "firstName#given_name,lastName#family_name,email#email"
```

**Format:** `internalField#idpClaim,internalField#idpClaim`

**Common Mappings:**
- `firstName#given_name` - First name from IDP
- `lastName#family_name` - Last name from IDP
- `email#email` - Email address
- `phoneNumber#phone_number` - Phone number

---

## Monitoring & Metrics

### Prometheus Configuration

```yaml
metrics:
  basePath: "/actuator"
  prometheus:
    enabled: "false"  # Set to true to enable
    path: /prometheus
    agent:
      port: "9100"
      port_exposed: "9100"
```

**Action Required:**

1. **Enable Prometheus:**
   - Set `enabled: "true"`
   - Ensure Prometheus can scrape port 9100

2. **Configure ServiceMonitor (if using Prometheus Operator):**
   ```yaml
   apiVersion: monitoring.coreos.com/v1
   kind: ServiceMonitor
   metadata:
     name: uidam-authorization-server
   spec:
     selector:
       matchLabels:
         app: uidam-authorization-server
     endpoints:
     - port: metrics
       path: /prometheus
   ```

### Datadog Configuration

```yaml
metrics:
  datadog:
    enabled: "false" # Datadog support available in case of Prometheus is available. 
    uri: "https://api.datadoghq.com"
    apiKey: "ChangeMe"
    applicationKey: "ChangeMe"
    descriptions: "true"
    readTimeout: "5s"
    connectTimeout: "5s"
    batchSize: "1000"
    step: "1m"
```

**Action Required:**

1. **Get Datadog API Keys:**
   - Login to Datadog
   - Navigate to: Organization Settings → API Keys
   - Create new API key and Application key

2. **Update Configuration:**
   - Set `enabled: "true"`
   - Replace `apiKey` with your Datadog API key
   - Replace `applicationKey` with your Datadog Application key
   - Update `uri` if using EU region: `https://api.datadoghq.eu`

### Metrics Tags

```yaml
metrics:
  tags:
    envName: "dev"
    product: "UIDAM"
    service: "UIDAM-Authorization-Server"
```

**Action Required:**
- Update `envName` to your environment (dev, staging, prod)
- Customize tags for your monitoring setup

### Database Health Monitoring

```yaml
health:
  postgresdb:
    monitor:
      enabled: "false"
      restartOnFailure: "false"
      restart_on_failure: "false"
```

**Action Required:**
- Set `enabled: "true"` to monitor PostgreSQL connectivity
- Set `restartOnFailure: "true"` to auto-restart on DB failures
- Recommended for production: enabled=true, restartOnFailure=false

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
- Set `enabled: "true"` to collect DB connection pool metrics
- Adjust `freq_ms` for metric collection frequency

---

## Deployment

### Pre-Deployment Checklist

- [ ] Tenant databases created and accessible
- [ ] All `ChangeMe` / `TO-BE-UPDATED` placeholders replaced
- [ ] Per-tenant `keyStore.keyAlias`, `keyStore.jksEncodedContent` and `cert.jwtKeyId` are unique
- [ ] `clientsecretkey` / `clientsecretsalt` match `uidam-user-management` per tenant
- [ ] `mfaSecretEncryptionKey` / `mfaSecretEncryptionSalt` match `uidam-user-management` per tenant
- [ ] Domain name and DNS configured
- [ ] External IDP credentials obtained, and unused providers left `enabled: false`
- [ ] KeyStore and certificates generated
- [ ] Network policies configured
- [ ] Resource limits set appropriately

### Install

```bash
helm install uidam-authorization-server ./uidam-authorization-server \
  -n uidam --create-namespace \
  -f my-values.yaml
```

The release name matters: the chart's fullname helper produces
`<release>-uidam-authorization-server` unless the release name already contains the
chart name. Using `uidam-authorization-server` as the release name keeps resource
names short and makes `postgresql.secretName` line up with the rendered Secret.

### Verify the rendered output before installing

```bash
# Full render
helm template uidam-authorization-server ./uidam-authorization-server -f my-values.yaml

# Confirm the expected tenant ConfigMaps and Secrets appear
helm template uidam-authorization-server ./uidam-authorization-server -f my-values.yaml \
  | grep -E '^kind:|^  name:'

# Confirm no placeholder survived
helm template uidam-authorization-server ./uidam-authorization-server -f my-values.yaml \
  | grep -E 'ChangeMe|TO-BE-UPDATED'
```

### Post-install checks

```bash
kubectl get configmap -n uidam | grep uidam-authorization-server
kubectl get secret    -n uidam | grep uidam-authorization-server
kubectl rollout status deployment/uidam-authorization-server -n uidam
curl -s https://auth-server.<your-domain>/<tenant>/.well-known/openid-configuration | jq .
```

You should see one `...-tenant-<id>` ConfigMap and one `...-tenant-<id>-credentials`
Secret for every entry in `multiTenant.tenantIds`, plus the `default` pair.

### Upgrade

```bash
helm upgrade uidam-authorization-server ./uidam-authorization-server \
  -n uidam -f my-values.yaml
```

ConfigMap changes trigger a pod restart automatically - the Deployment carries
`checksum/config`, `checksum/config-default` and `checksum/config-tenants` annotations.

### Deployment Order

1. Deploy or upgrade `uidam-authorization-server` **first**.
2. Then deploy or upgrade `uidam-user-management`.
3. Confirm both charts share the same `clientsecretkey` / `clientsecretsalt` and MFA
   keys for every tenant.

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
other tenant to its overrides - see
[Configuration Inheritance Model](#configuration-inheritance-model). Leaving the full
block in place still works, so this step can be done gradually.

### 4. New values to set

```yaml
multiTenant:
  tenants:
    default:
      ui:
        logoPath: "/images/default-logo.svg"
      client:
        authCodeScopelessUserScopes: true
        idTokenProperties:
          additionalClaims: ""
      signup:
        additionalAttributesEnabled: false
      clientSpecificSignupConfigs: []
      mfa:
        mfaAppName: "UIDAM"
        mode: "DISABLED"
        stepUpScopes: "UIDAMSystem,ManageUsers,ManageAccounts"
        skipUsers: "admin,tenantadmin"
        skipClients: ""
        skipAccounts: ""
        stepUpClients: ""
        stepUpAccounts: ""
      externalIdpRegisteredClients:
        - clientName: Google
          enabled: false            # new
          includeIdpIdToken: false  # new
          scopePreference: "INTERNAL"  # new
          # ...existing fields...

secrets:
  mfaSecretEncryptionKey: "ChangeMe"
  mfaSecretEncryptionSalt: "ChangeMe"

tenantSecrets:
  <tenant>:
    mfaSecretEncryptionKey: "ChangeMe"
    mfaSecretEncryptionSalt: "ChangeMe"
```

### 5. Configuration that was removed

The global ConfigMap no longer emits the legacy single-tenant block
(`TENANT_ID`, `TENANT_NAME`, `TENANT_ALIAS`, `TENANT_ACCOUNT_*`, `KEYSTORE_*`,
`JWT_*`, `USER_MANAGEMENT_ENV`, `CLIENT_BY_CLIENT_ID_ENDPOINT`, ...). Several of
those keys were bound to `values.yaml` entries that no longer existed and were being
rendered as empty strings, which silently overrode the multi-tenant values.

Their functional equivalents now live under `multiTenant.tenants.<id>`. The
top-level `tenant:` block in `values.yaml` is inert and can be deleted.

Two further fixes worth knowing about:
- `POSTGRES_DATASOURCE` previously referenced `postgres.uidam_dbname`, which does not
  exist, producing a datasource URL with no database name. It now uses
  `postgres.databaseName`.
- `UIDAM_DEFAULT_DB_SCHEMA` was emitted twice; the second occurrence read a missing
  value and blanked the first. Only `uidam.defaultDbSchema` is used now.

### 6. Rollback

```bash
helm rollback uidam-authorization-server -n uidam
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
kubectl logs -n uidam <pod-name>

# Check events
kubectl describe pod -n uidam <pod-name>

# Common causes:
# - Database connection failed: Check postgres.host and credentials
# - Missing secrets: Verify all secrets are created
# - Invalid configuration: Check configmap for syntax errors
```

#### 2. Database Connection Errors

**Symptoms:** Logs show "Connection refused" or "Authentication failed"

**Solutions:**
```bash
# Test database connectivity from pod
kubectl exec -it -n uidam <pod-name> -- bash
psql -h postgresql -U uidam_user -d uidam_db

# Check:
# - Database host is reachable
# - Database user exists and has permissions
# - Password is correct in secret
# - Database exists
```

#### 3. External IDP Login Fails

**Symptoms:** Redirect to IDP works but callback fails

**Solutions:**
- Verify the tenant has `externalIdpEnabled: true`
- Verify the provider entry has `enabled: true`
- Verify redirect URI matches exactly in IDP configuration
- Check IDP client ID and secret are correct
- Verify IDP secret is in tenant-specific secret
- Check network connectivity to IDP endpoints
- Review IDP-specific logs in authorization server

**Wrong secret being used:** client secrets are bound by list position. Confirm the
index-to-secret mapping is what you expect:

```bash
kubectl get deploy -n uidam uidam-authorization-server -o yaml \
  | grep -A3 'external-idp-registered-client-list'
```

If you inserted a provider in the middle of `externalIdpRegisteredClients`, every
later provider shifted onto the wrong secret. Append instead of inserting.

#### 4. Token Generation Fails

**Symptoms:** Login succeeds but no token returned

**Solutions:**
- Verify JKS encodeString is valid and properly base64-encoded
- Check keystore password and alias matches
- Verify JWT key ID is configured
- Confirm the tenant does not share `keyStore.keyAlias` or `cert.jwtKeyId` with another tenant


#### 5. Multi-Tenant Issues

**Symptoms:** Tenant-specific configuration not applied

**Solutions:**
- Verify tenant ID is in `multiTenant.tenantIds` list
- Check the tenant ConfigMap exists
- Verify the tenant Secret exists
- Check the `TENANT_DEFAULT` environment variable
- Review tenant selection logic in application logs

```bash
# One ConfigMap per active tenant, plus -tenant-default
kubectl get configmap -n uidam | grep tenant

# Inspect what a tenant actually overrides
kubectl get configmap -n uidam uidam-authorization-server-tenant-ecsp -o yaml

# Confirm the baseline the tenant inherits from
kubectl get configmap -n uidam uidam-authorization-server-tenant-default -o yaml
```

**A setting is not taking effect for one tenant:** because a tenant ConfigMap only
carries overrides, a missing key means the value is inherited from `-tenant-default`.
Check the default ConfigMap before assuming the value is lost. Omitting a key means
"inherit"; to blank a value, set it explicitly to `""`.

**ConfigMap ordering:** the Deployment loads the global ConfigMap, then each tenant
ConfigMap, then `-tenant-default`. Later entries win, which is why `DEFAULT_*` keys
are never shadowed by the global ConfigMap.

#### 6. MFA Problems

**Symptoms:** Users are not challenged, or previously working codes are rejected

```bash
# What mode is the tenant in?
kubectl get configmap -n uidam uidam-authorization-server-tenant-ecsp -o yaml \
  | grep -i mfa

# Confirm the MFA keys reached the pod
kubectl exec -n uidam deploy/uidam-authorization-server -- printenv | grep -i MFA
```

| Symptom | Cause | Fix |
|---------|-------|-----|
| Never challenged | `mfa.mode` is `DISABLED`, or the user/client/account is in a `skip*` list | Set `CONDITIONAL` or `REQUIRED`, and review the exclusions |
| Challenged unexpectedly | Requested scope is in `stepUpScopes` | Expected behaviour in `CONDITIONAL` mode |
| All enrolments suddenly invalid | `mfaSecretEncryptionKey` or `...Salt` changed, or differs from `uidam-user-management` | Restore the previous values, or have every user re-enrol |
| Codes always rejected | Clock skew between the device and the cluster | Verify NTP on the nodes |

### Debugging Commands

```bash
# Get all resources
kubectl get all -n uidam -l app=uidam-authorization-server

# Describe pod
kubectl describe pod -n uidam <pod-name>

# View logs
kubectl logs -n uidam <pod-name> --tail=100 --follow

# View configmap
kubectl get configmap -n uidam uidam-authorization-server -o yaml

# View secrets (base64 encoded)
kubectl get secret -n uidam uidam-authorization-server-credentials -o yaml

# Execute commands in pod
kubectl exec -it -n uidam <pod-name> -- bash

# Port forward for local testing
kubectl port-forward -n uidam svc/uidam-authorization-server 9443:9443
```

### Logs Analysis

Key log messages to look for:

**Success Messages:**
```
Successfully connected to database
JWT keys loaded successfully
OAuth2 authorization server started
Multi-tenant configuration loaded for tenant: <tenantId>
External IDP configured: <idp>
```

**Error Messages:**
```
Failed to connect to database - Check database configuration
Invalid keystore password - Verify secret configuration
Tenant configuration not found - Check tenant ID and configmap
Failed to load JWT keys - Verify certificate configuration
```

---

## Support and Additional Resources

### Configuration Files Reference

- `values.yaml` - Main configuration file
- `templates/configmap.yaml` - Global environment variables and application config
- `templates/configmap-default-configurations.yaml` - Default tenant baseline (`DEFAULT_*`)
- `templates/configmap-tenants-config.yaml` - Per-tenant overrides, generated dynamically
- `templates/secret.yaml` - Global credentials Secret
- `templates/secret-tenants.yaml` - Per-tenant Secrets, generated dynamically
- `templates/uidam-jks.yaml` - Fallback keystore ConfigMap
- `templates/app-keys.yaml` - JWT key pair and public PEM
- `templates/deployment.yaml` - Deployment specification
- `templates/service.yaml` - Service configuration
- `templates/ingress.yaml` - Ingress configuration

### Adding a New Tenant

No template changes are required - edit `values.yaml` only:

1. Append the tenant ID to `multiTenant.tenantIds`, e.g. `"ecsp,sdp,acme"`.
2. Add an override block under `multiTenant.tenants.acme` containing at minimum
   `tenantId`, `tenantName`, `database.jdbc_url`, `keyStore.keyAlias`,
   `keyStore.jksEncodedContent` and `cert.jwtKeyId`.
3. Add `tenantSecrets.acme` with that tenant's secrets. Any key you omit is
   inherited from `tenantSecrets.default`.
4. Create the tenant database and schema.
5. Mirror steps 1-4 in the `uidam-user-management` chart, keeping
   `clientsecretkey` / `clientsecretsalt` and the MFA keys identical.
6. `helm upgrade`. A new ConfigMap and Secret pair appear automatically.

### Best Practices

1. **Security:**
   - Never commit secrets to version control
   - Use strong, randomly generated passwords
   - Rotate secrets regularly, except the MFA encryption key and salt
   - Use network policies to restrict access
   - Enable TLS for all external communication
   - Ship external IDP providers with `enabled: false` until credentials are verified

2. **Performance:**
   - Adjust database connection pool based on load
   - Set appropriate resource limits
   - Enable metrics and monitoring
   - Configure horizontal pod autoscaling

3. **High Availability:**
   - Run multiple replicas (replicaCount: 2+)
   - Configure pod disruption budgets
   - Use readiness and liveness probes
   - Implement database connection retry logic

4. **Multi-Tenancy:**
   - Keep tenant configurations isolated
   - Use separate databases per tenant if possible
   - Keep shared settings in the `default` tenant and override only deltas
   - Give every tenant its own keystore alias and JWT key ID
   - Monitor tenant-specific metrics

---

**Document Version:** 2.0  
**Last Updated:** September 30, 2026  
**Component Version:** 1.6.0
