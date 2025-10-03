#!/bin/bash

# SSL Health Check Script for Todo API
# Monitors SSL certificate health and sends alerts

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_DIR/ssl"

# Default values
DOMAIN="${1:-}"
ALERT_DAYS="${2:-30}"
WEBHOOK_URL="${WEBHOOK_URL:-}"
EMAIL_TO="${EMAIL_TO:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
}

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Help function
show_help() {
    cat << EOF
SSL Health Check Script for Todo API

Usage: $0 [DOMAIN] [ALERT_DAYS]

Arguments:
    DOMAIN          Domain to check (optional, checks all if not specified)
    ALERT_DAYS      Days before expiry to alert (default: 30)

Environment Variables:
    WEBHOOK_URL     Slack/Discord webhook URL for alerts
    EMAIL_TO        Email address for alerts
    SMTP_SERVER     SMTP server for email alerts
    SMTP_USER       SMTP username
    SMTP_PASS       SMTP password

Examples:
    $0                              # Check all certificates
    $0 example.com                  # Check specific domain
    $0 example.com 7                # Alert 7 days before expiry

EOF
}

# Send alert via webhook
send_webhook_alert() {
    local message="$1"
    local severity="${2:-warning}"
    
    if [[ -n "$WEBHOOK_URL" ]]; then
        local color="warning"
        case "$severity" in
            "critical") color="danger" ;;
            "warning") color="warning" ;;
            "info") color="good" ;;
        esac
        
        local payload=$(cat << EOF
{
    "attachments": [
        {
            "color": "$color",
            "title": "Todo API SSL Certificate Alert",
            "text": "$message",
            "footer": "SSL Health Check",
            "ts": $(date +%s)
        }
    ]
}
EOF
)
        
        curl -X POST -H 'Content-type: application/json' \
            --data "$payload" \
            "$WEBHOOK_URL" 2>/dev/null || warn "Failed to send webhook alert"
    fi
}

# Send email alert
send_email_alert() {
    local subject="$1"
    local message="$2"
    
    if [[ -n "$EMAIL_TO" && -n "$SMTP_SERVER" ]]; then
        local email_body=$(cat << EOF
Subject: $subject
To: $EMAIL_TO
From: ssl-monitor@todo-api

$message

--
Todo API SSL Health Check
$(date)
EOF
)
        
        echo "$email_body" | sendmail "$EMAIL_TO" 2>/dev/null || \
            warn "Failed to send email alert"
    fi
}

# Check certificate expiry
check_certificate_expiry() {
    local cert_file="$1"
    local domain="$2"
    
    if [[ ! -f "$cert_file" ]]; then
        error "Certificate file not found: $cert_file"
        return 1
    fi
    
    # Get certificate expiry date
    local expiry_date=$(openssl x509 -in "$cert_file" -noout -enddate | cut -d= -f2)
    local expiry_epoch=$(date -d "$expiry_date" +%s)
    local current_epoch=$(date +%s)
    local days_until_expiry=$(( (expiry_epoch - current_epoch) / 86400 ))
    
    info "Certificate for $domain expires in $days_until_expiry days ($expiry_date)"
    
    # Check if certificate is expired
    if [[ $days_until_expiry -lt 0 ]]; then
        local message="CRITICAL: SSL certificate for $domain has EXPIRED!"
        error "$message"
        send_webhook_alert "$message" "critical"
        send_email_alert "CRITICAL: SSL Certificate Expired - $domain" "$message"
        return 2
    fi
    
    # Check if certificate expires soon
    if [[ $days_until_expiry -le $ALERT_DAYS ]]; then
        local message="WARNING: SSL certificate for $domain expires in $days_until_expiry days"
        warn "$message"
        send_webhook_alert "$message" "warning"
        send_email_alert "WARNING: SSL Certificate Expiring Soon - $domain" "$message"
        return 1
    fi
    
    log "Certificate for $domain is healthy (expires in $days_until_expiry days)"
    return 0
}

# Check certificate chain
check_certificate_chain() {
    local cert_file="$1"
    local domain="$2"
    
    info "Checking certificate chain for $domain..."
    
    # Verify certificate chain
    if openssl verify -CAfile "$cert_file" "$cert_file" >/dev/null 2>&1; then
        log "Certificate chain for $domain is valid"
        return 0
    else
        local message="ERROR: Invalid certificate chain for $domain"
        error "$message"
        send_webhook_alert "$message" "critical"
        return 1
    fi
}

# Test SSL connection
test_ssl_connection() {
    local domain="$1"
    local port="${2:-443}"
    
    info "Testing SSL connection to $domain:$port..."
    
    # Test SSL connection
    if timeout 10 openssl s_client -connect "$domain:$port" -servername "$domain" </dev/null >/dev/null 2>&1; then
        log "SSL connection to $domain:$port successful"
        return 0
    else
        local message="ERROR: Cannot establish SSL connection to $domain:$port"
        error "$message"
        send_webhook_alert "$message" "critical"
        return 1
    fi
}

# Check OCSP stapling
check_ocsp_stapling() {
    local domain="$1"
    
    info "Checking OCSP stapling for $domain..."
    
    # Check OCSP stapling
    local ocsp_response=$(timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" -status </dev/null 2>/dev/null | grep -A 1 "OCSP Response Status")
    
    if echo "$ocsp_response" | grep -q "successful"; then
        log "OCSP stapling working for $domain"
        return 0
    else
        warn "OCSP stapling not working for $domain"
        return 1
    fi
}

# Generate health report
generate_health_report() {
    local domain="$1"
    local cert_file="$2"
    
    info "Generating health report for $domain..."
    
    local report_file="/tmp/ssl-health-report-$domain-$(date +%Y%m%d-%H%M%S).txt"
    
    cat > "$report_file" << EOF
SSL Health Report for $domain
Generated: $(date)

Certificate Information:
$(openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Issuer:|Not Before|Not After|DNS:)")

Certificate Chain:
$(openssl x509 -in "$cert_file" -noout -issuer)

Certificate Fingerprint:
$(openssl x509 -in "$cert_file" -noout -fingerprint -sha256)

SSL Configuration Test:
$(timeout 10 openssl s_client -connect "$domain:443" -servername "$domain" </dev/null 2>&1 | grep -E "(Protocol|Cipher|Server public key)")

EOF
    
    info "Health report generated: $report_file"
    
    # Send report if email is configured
    if [[ -n "$EMAIL_TO" ]]; then
        send_email_alert "SSL Health Report - $domain" "$(cat "$report_file")"
    fi
}

# Main health check function
perform_health_check() {
    local domain="$1"
    local cert_dir="$SSL_DIR/letsencrypt/live/$domain"
    local cert_file="$cert_dir/fullchain.pem"
    
    if [[ ! -d "$cert_dir" ]]; then
        warn "No certificate directory found for domain: $domain"
        return 1
    fi
    
    if [[ ! -f "$cert_file" ]]; then
        error "No certificate file found for domain: $domain"
        return 1
    fi
    
    log "Performing health check for domain: $domain"
    
    local exit_code=0
    
    # Check certificate expiry
    check_certificate_expiry "$cert_file" "$domain" || exit_code=$?
    
    # Check certificate chain
    check_certificate_chain "$cert_file" "$domain" || exit_code=$?
    
    # Test SSL connection (if domain is accessible)
    if ping -c 1 "$domain" >/dev/null 2>&1; then
        test_ssl_connection "$domain" || exit_code=$?
        check_ocsp_stapling "$domain" || exit_code=$?
    else
        info "Domain $domain not accessible for connection testing"
    fi
    
    # Generate detailed report if there are issues
    if [[ $exit_code -ne 0 ]]; then
        generate_health_report "$domain" "$cert_file"
    fi
    
    return $exit_code
}

# Main execution
if [[ "$1" == "--help" || "$1" == "-h" ]]; then
    show_help
    exit 0
fi

log "Starting SSL health check..."

overall_exit_code=0

if [[ -n "$DOMAIN" ]]; then
    # Check specific domain
    perform_health_check "$DOMAIN" || overall_exit_code=$?
else
    # Check all domains
    if [[ -d "$SSL_DIR/letsencrypt/live" ]]; then
        for cert_dir in "$SSL_DIR/letsencrypt/live"/*; do
            if [[ -d "$cert_dir" ]]; then
                local domain_name=$(basename "$cert_dir")
                perform_health_check "$domain_name" || overall_exit_code=$?
                echo ""
            fi
        done
    else
        warn "No SSL certificates found in $SSL_DIR/letsencrypt/live"
        exit 1
    fi
fi

if [[ $overall_exit_code -eq 0 ]]; then
    log "All SSL certificates are healthy"
    send_webhook_alert "All SSL certificates are healthy" "info"
else
    error "SSL health check completed with issues (exit code: $overall_exit_code)"
fi

exit $overall_exit_code