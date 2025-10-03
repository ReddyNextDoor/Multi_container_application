# SSL Certificate Management for Todo API

This directory contains SSL certificate management tools and configurations for the Todo API reverse proxy setup.

## Quick Start

### 1. Initialize SSL Certificates

```bash
# For production
./scripts/ssl-manager.sh init your-domain.com your-email@domain.com

# For testing (staging environment)
./scripts/ssl-manager.sh init your-domain.com your-email@domain.com --staging
```

### 2. Start Production Environment

```bash
# Using Docker Compose
docker-compose -f docker-compose.nginx-prod.yml up -d

# Using Makefile
make -f Makefile.nginx prod
```

### 3. Verify SSL Setup

```bash
# Check certificate status
./scripts/ssl-manager.sh status

# Test nginx configuration
./scripts/ssl-manager.sh test-config

# Check in browser
curl -I https://your-domain.com/health
```

## Directory Structure

```
ssl/
├── README.md                          # This file
├── certbot.conf                       # Certbot configuration
├── todo-api-ssl-renewal.service       # Systemd service for renewal
├── todo-api-ssl-renewal.timer         # Systemd timer for automatic renewal
├── letsencrypt/                       # Let's Encrypt certificates (auto-created)
│   ├── live/                          # Active certificates
│   ├── archive/                       # Certificate history
│   └── renewal/                       # Renewal configuration
├── webroot/                           # Webroot for ACME challenges
├── dhparam/                           # Diffie-Hellman parameters
│   └── ssl-dhparams.pem              # DH parameters file
└── backups/                           # Certificate backups
```

## SSL Manager Commands

The `ssl-manager.sh` script provides comprehensive SSL certificate management:

### Initialize Certificates
```bash
# Production certificates
./scripts/ssl-manager.sh init example.com admin@example.com

# Staging certificates (for testing)
./scripts/ssl-manager.sh init example.com admin@example.com --staging
```

### Renew Certificates
```bash
# Renew all certificates
./scripts/ssl-manager.sh renew

# Renew specific domain
./scripts/ssl-manager.sh renew example.com

# Force renewal (even if not due)
./scripts/ssl-manager.sh renew example.com --force
```

### Check Status
```bash
# Show all certificate status
./scripts/ssl-manager.sh status

# Show specific domain status
./scripts/ssl-manager.sh status example.com
```

### Backup and Restore
```bash
# Create backup
./scripts/ssl-manager.sh backup

# Test configuration
./scripts/ssl-manager.sh test-config
```

### Dry Run Mode
Add `--dry-run` to any command to see what would be done without executing:

```bash
./scripts/ssl-manager.sh init example.com admin@example.com --dry-run
```

## Automatic Renewal Setup

### Option 1: Cron Job (Recommended for Docker environments)

Add to your crontab:
```bash
# Renew certificates twice daily
0 */12 * * * cd /path/to/todo-api && ./scripts/ssl-manager.sh renew
```

### Option 2: Systemd Timer (Recommended for systemd systems)

1. Copy service files:
```bash
sudo cp ssl/todo-api-ssl-renewal.service /etc/systemd/system/
sudo cp ssl/todo-api-ssl-renewal.timer /etc/systemd/system/
```

2. Update the WorkingDirectory in the service file:
```bash
sudo sed -i 's|/opt/todo-api|'$(pwd)'|g' /etc/systemd/system/todo-api-ssl-renewal.service
```

3. Enable and start the timer:
```bash
sudo systemctl daemon-reload
sudo systemctl enable todo-api-ssl-renewal.timer
sudo systemctl start todo-api-ssl-renewal.timer
```

4. Check timer status:
```bash
sudo systemctl status todo-api-ssl-renewal.timer
sudo systemctl list-timers todo-api-ssl-renewal.timer
```

## SSL Configuration Details

### Certificate Locations
- **Live certificates**: `ssl/letsencrypt/live/DOMAIN/`
- **Certificate file**: `fullchain.pem`
- **Private key**: `privkey.pem`
- **Certificate chain**: `chain.pem`

### Security Features
- **TLS 1.2/1.3 only**: Older protocols disabled
- **Strong ciphers**: Modern cipher suites preferred
- **HSTS**: HTTP Strict Transport Security enabled
- **OCSP stapling**: Certificate status validation
- **Perfect Forward Secrecy**: DH parameters generated

### Rate Limiting
Let's Encrypt has rate limits:
- **Certificates per domain**: 50 per week
- **Duplicate certificates**: 5 per week
- **Failed validations**: 5 per hour

Use staging environment for testing to avoid hitting limits.

## Troubleshooting

### Common Issues

#### 1. Certificate Request Failed
```bash
# Check DNS resolution
nslookup your-domain.com

# Verify domain points to your server
curl -I http://your-domain.com/.well-known/acme-challenge/test

# Check firewall
sudo ufw status
```

#### 2. Nginx Won't Start
```bash
# Test configuration
./scripts/ssl-manager.sh test-config

# Check certificate files exist
ls -la ssl/letsencrypt/live/your-domain.com/

# View nginx logs
docker-compose -f docker-compose.nginx-prod.yml logs nginx
```

#### 3. Certificate Renewal Failed
```bash
# Check certificate expiry
./scripts/ssl-manager.sh status

# Force renewal
./scripts/ssl-manager.sh renew --force

# Check renewal logs
docker run --rm -v $(pwd)/ssl/letsencrypt:/etc/letsencrypt certbot/certbot certificates
```

### Debug Mode

Enable debug logging by setting environment variable:
```bash
export CERTBOT_DEBUG=1
./scripts/ssl-manager.sh renew
```

### Manual Certificate Operations

#### View certificate details:
```bash
openssl x509 -in ssl/letsencrypt/live/DOMAIN/fullchain.pem -text -noout
```

#### Check certificate expiry:
```bash
openssl x509 -in ssl/letsencrypt/live/DOMAIN/fullchain.pem -noout -dates
```

#### Test SSL connection:
```bash
openssl s_client -connect your-domain.com:443 -servername your-domain.com
```

## Security Best Practices

1. **Regular Updates**: Keep Certbot and Nginx images updated
2. **Backup Certificates**: Regular backups of SSL certificates
3. **Monitor Expiry**: Set up alerts for certificate expiration
4. **Test Renewals**: Regularly test renewal process
5. **Secure Storage**: Protect private keys with proper file permissions
6. **Rate Limit Monitoring**: Monitor Let's Encrypt rate limits

## Environment Variables

Set these in your environment or `.env` file:

```bash
# SSL configuration
SSL_EMAIL=admin@example.com
SSL_STAGING=false
CERTBOT_IMAGE=certbot/certbot:latest

# Domain configuration
DOMAIN_NAME=your-domain.com
```

## Integration with CI/CD

For automated deployments, add SSL certificate management to your CI/CD pipeline:

```yaml
# Example GitHub Actions step
- name: Setup SSL Certificates
  run: |
    ./scripts/ssl-manager.sh init ${{ secrets.DOMAIN }} ${{ secrets.SSL_EMAIL }}
  env:
    SSL_STAGING: false
```

## Support

For issues with:
- **Let's Encrypt**: Check [Let's Encrypt documentation](https://letsencrypt.org/docs/)
- **Certbot**: Check [Certbot documentation](https://certbot.eff.org/docs/)
- **Nginx SSL**: Check [Nginx SSL documentation](https://nginx.org/en/docs/http/configuring_https_servers.html)