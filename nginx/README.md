# Nginx Reverse Proxy Configuration

This directory contains Nginx configuration files for the Todo API reverse proxy setup.

## Configuration Files

### `nginx.conf`
Production configuration with SSL/TLS support:
- HTTPS redirect from HTTP
- SSL certificate configuration for Let's Encrypt
- Security headers (HSTS, CSP, etc.)
- Rate limiting
- Proxy settings for Todo API backend

### `nginx-dev.conf`
Development configuration without SSL:
- HTTP only for local development
- Same proxy settings as production
- Simplified security headers
- Rate limiting enabled

### `custom-domain.conf.template`
Template for custom domain configuration:
- Replace `DOMAIN_NAME` with your actual domain
- SSL certificate paths for custom domain
- Production-ready security settings

## Features

### Security
- **SSL/TLS**: Modern cipher suites, TLS 1.2/1.3 only
- **HSTS**: HTTP Strict Transport Security enabled
- **Security Headers**: XSS protection, content type sniffing prevention
- **Rate Limiting**: API endpoint protection (10 req/sec, burst 20)

### Performance
- **Gzip Compression**: Enabled for text-based content
- **HTTP/2**: Enabled for HTTPS connections
- **Connection Keepalive**: Upstream connection pooling
- **Proxy Buffering**: Optimized buffer sizes

### Proxy Configuration
- **Backend**: Proxies to `todo-api:3000` container
- **Headers**: Proper forwarding of client information
- **Timeouts**: 60-second timeouts for all operations
- **Health Checks**: Direct proxy to `/health` endpoint

## Usage

### Development
Use `nginx-dev.conf` for local development without SSL certificates.

### Production
1. Use `nginx.conf` for production with SSL certificates
2. Ensure SSL certificates are properly mounted
3. Configure custom domain using the template

### Custom Domain Setup
1. Copy `custom-domain.conf.template` to `custom-domain.conf`
2. Replace all instances of `DOMAIN_NAME` with your domain
3. Update Docker Compose to use the custom configuration

## SSL Certificate Requirements

The production configuration expects SSL certificates in these locations:
- Certificate: `/etc/letsencrypt/live/DOMAIN_NAME/fullchain.pem`
- Private Key: `/etc/letsencrypt/live/DOMAIN_NAME/privkey.pem`
- Chain: `/etc/letsencrypt/live/DOMAIN_NAME/chain.pem`
- DH Params: `/etc/letsencrypt/ssl-dhparams.pem`

## Rate Limiting

- **API Endpoints**: 10 requests/second with burst of 20
- **Health Checks**: No rate limiting
- **Zone Size**: 10MB memory allocation

## Logging

- **Access Log**: `/var/log/nginx/access.log`
- **Error Log**: `/var/log/nginx/error.log`
- **Health Checks**: Access logging disabled for `/health`

## Customization

### Adding New Routes
Add new `location` blocks in the server configuration:

```nginx
location /new-endpoint/ {
    proxy_pass http://todo_api/new-endpoint/;
    # ... other proxy settings
}
```

### Modifying Security Headers
Update the `add_header` directives in the server block:

```nginx
add_header Custom-Header "value" always;
```

### Adjusting Rate Limits
Modify the `limit_req_zone` and `limit_req` directives:

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=5r/s;
limit_req zone=api burst=10 nodelay;
```