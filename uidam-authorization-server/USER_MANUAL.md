# UIDAM Authorization Server - User Manual

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Configuration Guide](#configuration-guide)
4. [Multi-Tenant Configuration](#multi-tenant-configuration)
5. [Security & Secrets Management](#security--secrets-management)
6. [Database Configuration](#database-configuration)
7. [External IDP Integration](#external-idp-integration)
8. [Monitoring & Metrics](#monitoring--metrics)
9. [Deployment](#deployment)
10. [Troubleshooting](#troubleshooting)

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

## Configuration Guide

### Basic Configuration (`values.yaml`)

#### 1. Image Configuration

```yaml
image:
  repository: docker.io/eclipseecsp/uidam-authorization-server
  pullPolicy: IfNotPresent
  tag: 1.2.2
```

**Action Required:**
- Update `repository` to your container registry if there is any customization done and generated image in your custom repository.
- Update `tag` to the desired version

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

### Tenant-Specific Configuration

Each tenant requires a complete configuration block:

```yaml
multiTenant:
  tenants:
    ecsp:  # Tenant ID (must match tenantIds list)
      tenantId: "ecsp"
      tenantName: "ECSP"
      jksEnabled: true
      externalIdpEnabled: true
      internalLoginEnabled: true
```

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
  reuseRefreshToken: false
```

**Action Required:**
- Adjust TTL values based on security requirements
- Shorter TTLs = more secure but more frequent token refreshes
- Recommended: accessTokenTtl: 3600, refreshTokenTtl: 86400

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

---

## Security & Secrets Management

### Global Secrets

These secrets are shared across all tenants:

```yaml
secrets:
  keystorePassword: "ChangeMe"
  igniteRecaptchaKeySecret: "ChangeMe"
  clientsecretkey: "ChangeMe"
  clientsecretsalt: "ChangeMe"
  clientSecret: "ChangeMe"
```

**Action Required:**

1. **keystorePassword:**
   - Password for the Java KeyStore
   - Must match the password used when creating JKS file
   - Minimum 8 characters, use strong password

2. **igniteRecaptchaKeySecret:**
   - Google reCAPTCHA secret key
   - Obtained from Google reCAPTCHA admin console
   - Keep this secret and never commit to version control

3. **clientsecretkey:**
   - Key used for encrypting OAuth2 client secrets
   - Generate strong random string (32+ characters)
   ```bash
   openssl rand -base64 32
   ```

4. **clientsecretsalt:**
   - Salt for client secret hashing
   - Generate strong random string (16+ characters)
   ```bash
   openssl rand -base64 16
   ```

5. **clientSecret:**
   - Default client secret for internal clients
   - Generate strong random string
   ```bash
   openssl rand -base64 24
   ```

### Tenant-Specific Secrets

Each tenant has its own set of secrets:

```yaml
tenantSecrets:
  ecsp:
    keystorePassword: "ChangeMe"
    igniteRecaptchaKeySecret: "ChangeMe"
    clientsecretkey: "ChangeMe"
    clientsecretsalt: "ChangeMe"
    clientSecret: "ChangeMe"
    googleIDPSecret: "ChangeMe"
    githubIDPSecret: "ChangeMe"
    cognitoIDPSecret: "ChangeMe"
    azureIDPSecret: "ChangeMe"
```

**Action Required:**

1. **Tenant-specific basic secrets:**
   - Follow same generation process as global secrets
   - Use different values for each tenant for isolation

2. **External IDP Secrets:**
   
   **googleIDPSecret:**
   - OAuth2 client secret from Google Cloud Console
   - Navigate to: Console → APIs & Services → Credentials
   - Create OAuth 2.0 Client ID
   - Copy client secret

   **githubIDPSecret:**
   - OAuth App secret from GitHub
   - Navigate to: Settings → Developer settings → OAuth Apps
   - Create OAuth App
   - Copy client secret

   **cognitoIDPSecret:**
   - App client secret from AWS Cognito
   - Navigate to: Cognito → User Pools → App clients
   - Create app client with client secret
   - Copy client secret

   **azureIDPSecret:**
   - Client secret from Azure AD
   - Navigate to: Azure Portal → App registrations
   - Create app registration
   - Generate client secret in Certificates & secrets

### Secret Templates

The chart creates Kubernetes secrets automatically. For each tenant:

**File:** `templates/secret-tenant-ecsp.yaml`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: {{ include "uidam-authorization-server.fullname" . }}-ecsp
data:
  keystorePassword: {{ .Values.tenantSecrets.ecsp.keystorePassword | b64enc | quote }}
  # ... other secrets
```

**Important Notes:**
- Secrets are base64-encoded automatically by Helm
- Never commit unencrypted secrets to git
- Use sealed-secrets, external-secrets, or vault for production
- Rotate secrets regularly (every 90 days recommended)

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

### PostgreSQL Credentials (Separate Section)

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
- Replace `userName` and `password` with actual database credentials
- These are used in the secret template for environment variables
- Store credentials securely using secrets management tools

---

## External IDP Integration

### Configuring External Identity Providers

Each tenant can integrate with multiple external IDPs:

```yaml
externalIdpRegisteredClients:
  - clientName: Google
    registrationId: google
    clientId: xxx
    clientAuthenticationMethod: client_secret_basic
    scope: "openid, profile, email, address, phone"
    authorizationUri: "https://accounts.google.com/o/oauth2/v2/auth"
    tokenUri: "https://www.googleapis.com/oauth2/v4/token"
    userInfoUri: "https://www.googleapis.com/oauth2/v3/userinfo"
    userNameAttributeName: "sub"
    jwkSetUri: "https://www.googleapis.com/oauth2/v3/certs"
    tokenInfoSource: "FETCH_INTERNAL_USER" # user details fetch from user-management API.
    createUserMode: "CREATE_INTERNAL_USER" # create user in user-management if not exists (first time login)
    defaultUserRoles: "VEHICLE_OWNER" # can be updated as needed.
    claimMappings: "firstName#given_name,lastName#family_name,email#email"  # mapping external IDP client with Usermanagement user creation payload attribute
```

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

- [ ] Tenants Database created and accessible
- [ ] All placeholder values replaced with actual values
- [ ] Secrets generated and configured
- [ ] Domain name and DNS configured
- [ ] External IDP credentials obtained (if using)
- [ ] KeyStore and certificates generated
- [ ] Network policies configured
- [ ] Resource limits set appropriately

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
- Verify redirect URI matches exactly in IDP configuration
- Check IDP client ID and secret are correct
- Verify IDP secret is in tenant-specific secret
- Check network connectivity to IDP endpoints
- Review IDP-specific logs in authorization server

#### 4. Token Generation Fails

**Symptoms:** Login succeeds but no token returned

**Solutions:**
- Verify JKS encodeString is valid and properly base64-encoded
- Check keystore password  and alias matches
- Verify JWT key ID is configured


#### 5. Multi-Tenant Issues

**Symptoms:** Tenant-specific configuration not applied

**Solutions:**
- Verify tenant ID is in `multiTenant.tenantIds` list
- Check tenant-specific configmap exists
- Verify tenant-specific secret exists
- Check `DEFAULT_TENANT` environment variable
- Review tenant selection logic in application logs

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
- `templates/configmap.yaml` - Environment variables and application config
- `templates/secret.yaml` - Global secrets
- `templates/secret-tenant-*.yaml` - Tenant-specific secrets
- `templates/deployment.yaml` - Deployment specification
- `templates/ingress.yaml` - Ingress configuration

### Best Practices

1. **Security:**
   - Never commit secrets to version control
   - Use strong, randomly generated passwords
   - Rotate secrets regularly
   - Use network policies to restrict access
   - Enable TLS for all external communication

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
   - Monitor tenant-specific metrics

---

**Document Version:** 1.0  
**Last Updated:** October 27, 2025  
**Component Version:** 1.2.2
