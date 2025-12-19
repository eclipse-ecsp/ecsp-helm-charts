# UIDAM Portal - User Manual

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Configuration Guide](#configuration-guide)
4. [Security & Secrets Management](#security--secrets-management)
5. [OAuth Configuration](#oauth-configuration)
6. [Deployment](#deployment)
7. [Troubleshooting](#troubleshooting)

---

## Overview

The UIDAM Portal is a modern, React-based web administration interface for the UIDAM (Universal Identity and Access Management) ecosystem. It provides comprehensive management capabilities for users, accounts, roles, scopes, and OAuth2 clients.

### Key Features
- User CRUD operations and approval workflows
- Account hierarchy management
- Role and scope management
- OAuth2 client registration and management
- Real-time dashboard with system metrics
- Modern, responsive UI built with React and Material-UI
- Secure OAuth2 authentication

---

## Prerequisites

Before deploying the UIDAM Portal, ensure you have:

1. **Kubernetes Cluster** (v1.19+)
2. **Helm** (v3.0+)
3. **Running UIDAM Services:**
   - UIDAM Authorization Server
   - UIDAM User Management Service
4. **Domain Name** for ingress configuration
5. **SSL/TLS Certificates** (recommended for production)
6. **OAuth2 Client** registered in UIDAM Authorization Server

---

## Configuration Guide

### Basic Configuration (`values.yaml`)

#### 1. Image Configuration

```yaml
image:
  repository: docker.io/eclipseecsp/uidam-portal
  pullPolicy: IfNotPresent
  tag: "1.0.0"
```

**Action Required:**
- Update `repository` if using a custom container registry
- Update `tag` to the desired version

#### 2. Environment Domain Configuration

```yaml
environmentDomainName: local
```

**Action Required:**
- Replace `local` with your actual domain name (e.g., `ecsp.example.com`)
- This domain is used for:
  - Ingress hostname construction
  - OAuth2 redirect URI generation

#### 3. Backend API Endpoints

```yaml
apiEndpoints:
  authorizationServer: "https://uidam-authorization-server.local/sdp"
  userManagement: "http://uidam-user-management:8080"
```

**Action Required:**
- Update `authorizationServer` with your UIDAM Authorization Server URL
- Update `userManagement` with your UIDAM User Management Service URL
- Ensure the URLs are accessible from the Kubernetes cluster
- Include the tenant path in the authorization server URL (e.g., `/sdp`, `/ecsp`)

#### 4. Resource Configuration

```yaml
resources:
  limits:
    cpu: 200m
    memory: 256Mi
  requests:
    cpu: 100m
    memory: 128Mi
```

**Action Required:**
- Adjust CPU and memory based on expected load
- Recommended minimum: 128Mi memory, 100m CPU for portal

#### 5. Nginx Configuration

```yaml
nginx:
  clientMaxBodySize: "10m"
  workerProcesses: "auto"
  workerConnections: "1024"
```

**Action Required:**
- Adjust `clientMaxBodySize` if larger file uploads are needed
- Increase `workerConnections` for high-traffic scenarios

---

## Security & Secrets Management

### OAuth Client Secret

The OAuth client secret is managed through Kubernetes secrets:

```yaml
secrets:
  clientSecret: "ChangeMe"
```

**Action Required:**
1. **DO NOT** use the default `"ChangeMe"` value in production
2. Generate a secure random secret:
   ```bash
   openssl rand -base64 32
   ```
3. Update the `secrets.clientSecret` value in `values.yaml`
4. Alternatively, create the secret manually before Helm installation:
   ```bash
   kubectl create secret generic uidam-portal-credentials \
     --from-literal=clientSecret='YOUR_SECURE_SECRET'
   ```

### Secret Rotation

To rotate the OAuth client secret:

1. Update the secret in UIDAM Authorization Server
2. Update the Kubernetes secret:
   ```bash
   kubectl create secret generic uidam-portal-credentials \
     --from-literal=clientSecret='NEW_SECRET' \
     --dry-run=client -o yaml | kubectl apply -f -
   ```
3. Restart the portal pods:
   ```bash
   kubectl rollout restart deployment/uidam-portal
   ```

---

## OAuth Configuration

### Client Registration

Before deploying the portal, register an OAuth2 client in the UIDAM Authorization Server:

```yaml
oauth:
  clientId: "uidam-portal-client"
  usePKCE: false
```

**Client Configuration Requirements:**
- **Client ID**: `uidam-portal-client` (or your custom client ID)
- **Grant Types**: `authorization_code`, `refresh_token`
- **Redirect URI**: `https://<portal-hostname>/auth/callback`
- **Scopes**: `openid`, `profile`, `email`, and any custom scopes
- **Token Settings**:
  - Access Token TTL: 3600 seconds (1 hour)
  - Refresh Token TTL: 86400 seconds (24 hours)

**Action Required:**
1. Register the OAuth2 client in UIDAM Authorization Server
2. Update `oauth.clientId` with your registered client ID
3. Ensure the redirect URI matches your portal hostname
4. Configure the client secret as described in [Security & Secrets Management](#security--secrets-management)

### PKCE Configuration (Optional)

For enhanced security, enable PKCE (Proof Key for Code Exchange):

```yaml
oauth:
  usePKCE: false  # Set to true to enable PKCE
```

**Action Required:**
- Set `usePKCE: true` for public clients or enhanced security
- Ensure your UIDAM Authorization Server supports PKCE

---

## Application Configuration

### Portal Settings

```yaml
app:
  title: "UIDAM Admin Portal"
  logLevel: "info"
  apiTimeout: 30000
  apiRetryAttempts: 3
  apiRetryDelay: 1000
  tokenStorageKey: "uidam_admin_token"
  refreshTokenStorageKey: "uidam_admin_refresh_token"
```

**Action Required:**
- Customize `title` for your organization
- Set `logLevel` to `debug` for troubleshooting, `error` for production
- Adjust `apiTimeout` based on network latency
- Configure retry settings based on reliability requirements

---

## Ingress Configuration

```yaml
ingress:
  enabled: true
  className: alb  # Use 'nginx' or your ingress controller
  groupName: ic
  scheme: internal  # Use 'internet-facing' for public access
  targetType: ip
  inboundCidrs: []  # Add CIDR blocks for IP whitelisting
  tls:
    enabled: true
    sslRedirect: false
  hosts:
  - hostPrefix: uidam-portal
    paths:
    - /
```

**Action Required:**
1. Update `className` to match your ingress controller
2. Set `scheme` to `internet-facing` for public access
3. Add IP CIDR blocks to `inboundCidrs` for access control
4. Enable TLS and SSL redirect for production:
   ```yaml
   tls:
     enabled: true
     sslRedirect: true
   ```
5. Update `hostPrefix` if needed (results in `<hostPrefix>.<environmentDomainName>`)

---

## Deployment

### Installation

#### 1. Using Helm (Recommended)

```bash
# Add the chart repository (if published)
helm repo add ecsp-helm-charts https://eclipse-ecsp.github.io/ecsp-helm-charts/
helm repo update

# Install with default values
helm install uidam-portal ecsp-helm-charts/uidam-portal

# Install with custom values
helm install uidam-portal ecsp-helm-charts/uidam-portal \
  -f custom-values.yaml \
  --namespace uidam-system \
  --create-namespace
```

#### 2. Using Local Chart

```bash
# Clone the repository
git clone https://github.com/eclipse-ecsp/ecsp-helm-charts.git
cd ecsp-helm-charts/uidam-portal

# Create custom values
cp values.yaml my-values.yaml
# Edit my-values.yaml with your configuration

# Install the chart
helm install uidam-portal . \
  -f my-values.yaml \
  --namespace uidam-system \
  --create-namespace
```

### Verification

Check the deployment status:

```bash
# Check pod status
kubectl get pods -n uidam-system -l app.kubernetes.io/name=uidam-portal

# Check service
kubectl get svc -n uidam-system -l app.kubernetes.io/name=uidam-portal

# Check ingress
kubectl get ingress -n uidam-system

# View logs
kubectl logs -n uidam-system -l app.kubernetes.io/name=uidam-portal --tail=100 -f
```

### Upgrade

```bash
# Upgrade to a new version
helm upgrade uidam-portal ecsp-helm-charts/uidam-portal \
  -f my-values.yaml \
  --namespace uidam-system

# Rollback if needed
helm rollback uidam-portal --namespace uidam-system
```

### Uninstallation

```bash
helm uninstall uidam-portal --namespace uidam-system
```

---

## Troubleshooting

### Common Issues

#### 1. Portal Not Accessible

**Symptoms:**
- Cannot access portal URL
- 502/504 errors

**Solutions:**
```bash
# Check pod status
kubectl get pods -n uidam-system

# Check pod logs
kubectl logs -n uidam-system -l app.kubernetes.io/name=uidam-portal

# Check ingress configuration
kubectl describe ingress -n uidam-system

# Verify backend services are reachable
kubectl run test-pod --rm -it --image=curlimages/curl -- sh
# Then test connectivity:
curl http://uidam-user-management:8080/actuator/health
```

#### 2. OAuth Authentication Fails

**Symptoms:**
- Redirect to authorization server fails
- "Invalid client" or "Invalid redirect URI" errors

**Solutions:**
1. Verify OAuth client configuration in Authorization Server
2. Check redirect URI matches portal hostname exactly
3. Verify client secret is correct:
   ```bash
   kubectl get secret uidam-portal-credentials -n uidam-system -o yaml
   # Decode the secret:
   kubectl get secret uidam-portal-credentials -n uidam-system \
     -o jsonpath='{.data.clientSecret}' | base64 -d
   ```
4. Check authorization server URL in configmap:
   ```bash
   kubectl get configmap uidam-portal -n uidam-system -o yaml
   ```

#### 3. API Calls Failing

**Symptoms:**
- Dashboard shows errors
- User/account operations fail
- Network timeout errors

**Solutions:**
```bash
# Check backend service endpoints in configmap
kubectl get configmap uidam-portal -n uidam-system -o yaml

# Test connectivity from portal pod
kubectl exec -it <portal-pod-name> -n uidam-system -- sh
# Then test:
curl -k https://uidam-authorization-server.local/sdp/actuator/health
curl http://uidam-user-management:8080/actuator/health

# Check network policies
kubectl get networkpolicies -n uidam-system
```

#### 4. High Memory Usage

**Symptoms:**
- Pod gets OOMKilled
- Slow performance

**Solutions:**
1. Increase memory limits:
   ```yaml
   resources:
     limits:
       memory: 512Mi
   ```
2. Adjust Nginx worker processes:
   ```yaml
   nginx:
     workerProcesses: "2"  # Reduce from "auto"
   ```

#### 5. Static Assets Not Loading

**Symptoms:**
- UI appears broken
- 404 errors for JS/CSS files

**Solutions:**
1. Check nginx configuration in configmap
2. Verify volume mounts in deployment
3. Check nginx logs:
   ```bash
   kubectl exec <portal-pod> -n uidam-system -- cat /var/log/nginx/error.log
   ```

### Debug Mode

Enable debug logging for troubleshooting:

```yaml
app:
  logLevel: "debug"
```

Then check browser console and pod logs for detailed information.

### Health Checks

The portal exposes a health check endpoint:

```bash
# From outside the cluster (via ingress)
curl https://uidam-portal.example.com/health

# From within the cluster
kubectl run test --rm -it --image=curlimages/curl -- \
  curl http://uidam-portal/health
```

Expected response: `healthy`

---

## Production Considerations

### Security Checklist

- [ ] Change default OAuth client secret
- [ ] Enable TLS for ingress
- [ ] Configure IP whitelisting via `inboundCidrs`
- [ ] Use internal scheme if portal is not public-facing
- [ ] Enable PKCE for enhanced OAuth security
- [ ] Configure proper resource limits
- [ ] Set up monitoring and alerting
- [ ] Configure log aggregation
- [ ] Implement backup for configuration

### Performance Tuning

1. **Scaling:**
   ```yaml
   replicaCount: 3  # Increase for high availability
   ```

2. **Pod Anti-Affinity:**
   ```yaml
   affinity:
     podAntiAffinity:
       preferredDuringSchedulingIgnoredDuringExecution:
       - weight: 100
         podAffinityTerm:
           topologyKey: kubernetes.io/hostname
           labelSelector:
             matchLabels:
               app.kubernetes.io/name: uidam-portal
   ```

3. **Node Selector:**
   ```yaml
   nodeSelector:
     workload: frontend
   ```

### Monitoring

Configure monitoring with Prometheus/Grafana:

```yaml
# Add Prometheus annotations (custom modification needed)
podAnnotations:
  prometheus.io/scrape: "true"
  prometheus.io/port: "80"
  prometheus.io/path: "/metrics"
```

---

## Support

For issues and questions:

- **GitHub Issues**: [Report bugs or request features](https://github.com/eclipse-ecsp/ecsp-helm-charts/issues)
- **Documentation**: [UIDAM Portal README](https://github.com/eclipse-ecsp/uidam-portal)
- **Security**: See [SECURITY.md](https://github.com/eclipse-ecsp/uidam-portal/blob/main/SECURITY.md)

---

## Version History

| Version | Changes |
|---------|---------|
| 0.0.1   | Initial Helm chart release |
