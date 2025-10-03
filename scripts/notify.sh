#!/bin/bash

# Notification script for deployment status
# Supports multiple notification channels (Slack, Discord, Email, etc.)

set -euo pipefail

# Default values
NOTIFICATION_TYPE="${NOTIFICATION_TYPE:-console}"
DEPLOYMENT_STATUS="${DEPLOYMENT_STATUS:-unknown}"
APPLICATION_NAME="${APPLICATION_NAME:-Todo API}"
ENVIRONMENT="${ENVIRONMENT:-production}"
VERSION="${VERSION:-unknown}"
SERVER_URL="${SERVER_URL:-}"

# Colors for console output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Send deployment notifications through various channels

OPTIONS:
    -t, --type          Notification type (console, slack, discord, email)
    -s, --status        Deployment status (success, failure, started, warning)
    -a, --app           Application name (default: Todo API)
    -e, --env           Environment (default: production)
    -v, --version       Version/tag being deployed
    -u, --url           Server URL
    --help              Show this help message

ENVIRONMENT VARIABLES:
    NOTIFICATION_TYPE   Notification type
    DEPLOYMENT_STATUS   Deployment status
    APPLICATION_NAME    Application name
    ENVIRONMENT         Environment name
    VERSION             Version/tag
    SERVER_URL          Server URL
    
    # Slack notifications
    SLACK_WEBHOOK_URL   Slack webhook URL
    SLACK_CHANNEL       Slack channel (optional)
    
    # Discord notifications
    DISCORD_WEBHOOK_URL Discord webhook URL
    
    # Email notifications
    SMTP_SERVER         SMTP server
    SMTP_PORT           SMTP port
    SMTP_USERNAME       SMTP username
    SMTP_PASSWORD       SMTP password
    EMAIL_FROM          From email address
    EMAIL_TO            To email address

EXAMPLES:
    $0 --type console --status success --version v1.0.0
    $0 -t slack -s failure -a "Todo API" -e production -v main-abc123
    $0 --type discord --status started --url https://api.example.com

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            NOTIFICATION_TYPE="$2"
            shift 2
            ;;
        -s|--status)
            DEPLOYMENT_STATUS="$2"
            shift 2
            ;;
        -a|--app)
            APPLICATION_NAME="$2"
            shift 2
            ;;
        -e|--env)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -v|--version)
            VERSION="$2"
            shift 2
            ;;
        -u|--url)
            SERVER_URL="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Function to get status emoji and color
get_status_info() {
    local status="$1"
    
    case $status in
        "success")
            echo "✅|#36a64f|SUCCESS"
            ;;
        "failure")
            echo "❌|#ff0000|FAILURE"
            ;;
        "started")
            echo "🚀|#0099cc|STARTED"
            ;;
        "warning")
            echo "⚠️|#ff9900|WARNING"
            ;;
        *)
            echo "ℹ️|#808080|UNKNOWN"
            ;;
    esac
}

# Function to send console notification
send_console_notification() {
    local status_info
    status_info=$(get_status_info "$DEPLOYMENT_STATUS")
    IFS='|' read -r emoji color status_text <<< "$status_info"
    
    echo
    echo "=================================="
    echo "   DEPLOYMENT NOTIFICATION"
    echo "=================================="
    echo
    echo "Application: $APPLICATION_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "Status: $emoji $status_text"
    echo "Version: $VERSION"
    if [[ -n "$SERVER_URL" ]]; then
        echo "URL: $SERVER_URL"
    fi
    echo "Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')"
    echo
    echo "=================================="
}

# Function to send Slack notification
send_slack_notification() {
    local webhook_url="${SLACK_WEBHOOK_URL:-}"
    local channel="${SLACK_CHANNEL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_error "SLACK_WEBHOOK_URL environment variable is required for Slack notifications"
        return 1
    fi
    
    local status_info
    status_info=$(get_status_info "$DEPLOYMENT_STATUS")
    IFS='|' read -r emoji color status_text <<< "$status_info"
    
    local payload
    payload=$(cat << EOF
{
    "text": "$emoji Deployment $status_text",
    "attachments": [
        {
            "color": "$color",
            "fields": [
                {
                    "title": "Application",
                    "value": "$APPLICATION_NAME",
                    "short": true
                },
                {
                    "title": "Environment",
                    "value": "$ENVIRONMENT",
                    "short": true
                },
                {
                    "title": "Version",
                    "value": "$VERSION",
                    "short": true
                },
                {
                    "title": "Status",
                    "value": "$status_text",
                    "short": true
                }
EOF
    )
    
    if [[ -n "$SERVER_URL" ]]; then
        payload+=",
                {
                    \"title\": \"URL\",
                    \"value\": \"$SERVER_URL\",
                    \"short\": false
                }"
    fi
    
    payload+="],
            \"footer\": \"Deployment System\",
            \"ts\": $(date +%s)
        }
    ]"
    
    if [[ -n "$channel" ]]; then
        payload+=",\"channel\": \"$channel\""
    fi
    
    payload+="}"
    
    log_info "Sending Slack notification..."
    
    if curl -X POST -H 'Content-type: application/json' --data "$payload" "$webhook_url" -s > /dev/null; then
        log_info "Slack notification sent successfully"
    else
        log_error "Failed to send Slack notification"
        return 1
    fi
}

# Function to send Discord notification
send_discord_notification() {
    local webhook_url="${DISCORD_WEBHOOK_URL:-}"
    
    if [[ -z "$webhook_url" ]]; then
        log_error "DISCORD_WEBHOOK_URL environment variable is required for Discord notifications"
        return 1
    fi
    
    local status_info
    status_info=$(get_status_info "$DEPLOYMENT_STATUS")
    IFS='|' read -r emoji color status_text <<< "$status_info"
    
    # Convert hex color to decimal
    local color_decimal
    color_decimal=$((16#${color#\#}))
    
    local description="**Application:** $APPLICATION_NAME\\n**Environment:** $ENVIRONMENT\\n**Version:** $VERSION"
    if [[ -n "$SERVER_URL" ]]; then
        description+="\\n**URL:** $SERVER_URL"
    fi
    
    local payload
    payload=$(cat << EOF
{
    "embeds": [
        {
            "title": "$emoji Deployment $status_text",
            "description": "$description",
            "color": $color_decimal,
            "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
            "footer": {
                "text": "Deployment System"
            }
        }
    ]
}
EOF
    )
    
    log_info "Sending Discord notification..."
    
    if curl -X POST -H 'Content-Type: application/json' --data "$payload" "$webhook_url" -s > /dev/null; then
        log_info "Discord notification sent successfully"
    else
        log_error "Failed to send Discord notification"
        return 1
    fi
}

# Function to send email notification
send_email_notification() {
    local smtp_server="${SMTP_SERVER:-}"
    local smtp_port="${SMTP_PORT:-587}"
    local smtp_username="${SMTP_USERNAME:-}"
    local smtp_password="${SMTP_PASSWORD:-}"
    local email_from="${EMAIL_FROM:-}"
    local email_to="${EMAIL_TO:-}"
    
    if [[ -z "$smtp_server" || -z "$smtp_username" || -z "$smtp_password" || -z "$email_from" || -z "$email_to" ]]; then
        log_error "Email configuration incomplete. Required: SMTP_SERVER, SMTP_USERNAME, SMTP_PASSWORD, EMAIL_FROM, EMAIL_TO"
        return 1
    fi
    
    local status_info
    status_info=$(get_status_info "$DEPLOYMENT_STATUS")
    IFS='|' read -r emoji color status_text <<< "$status_info"
    
    local subject="$emoji Deployment $status_text - $APPLICATION_NAME ($ENVIRONMENT)"
    
    local body
    body=$(cat << EOF
Deployment Notification

Application: $APPLICATION_NAME
Environment: $ENVIRONMENT
Status: $status_text
Version: $VERSION
EOF
    )
    
    if [[ -n "$SERVER_URL" ]]; then
        body+="
URL: $SERVER_URL"
    fi
    
    body+="
Timestamp: $(date -u '+%Y-%m-%d %H:%M:%S UTC')

This is an automated notification from the deployment system.
"
    
    log_info "Sending email notification..."
    
    # Create temporary files for email
    local email_file
    email_file=$(mktemp)
    
    cat << EOF > "$email_file"
To: $email_to
From: $email_from
Subject: $subject

$body
EOF
    
    # Send email using sendmail or curl (depending on what's available)
    if command -v sendmail &> /dev/null; then
        if sendmail "$email_to" < "$email_file"; then
            log_info "Email notification sent successfully"
        else
            log_error "Failed to send email notification"
            rm -f "$email_file"
            return 1
        fi
    else
        log_warn "sendmail not available, email notification not implemented for SMTP"
        rm -f "$email_file"
        return 1
    fi
    
    rm -f "$email_file"
}

# Main function
main() {
    log_info "Sending $NOTIFICATION_TYPE notification for deployment status: $DEPLOYMENT_STATUS"
    
    case $NOTIFICATION_TYPE in
        "console")
            send_console_notification
            ;;
        "slack")
            send_slack_notification
            ;;
        "discord")
            send_discord_notification
            ;;
        "email")
            send_email_notification
            ;;
        *)
            log_error "Unknown notification type: $NOTIFICATION_TYPE"
            log_error "Supported types: console, slack, discord, email"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"