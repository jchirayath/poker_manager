#!/bin/bash

# Script to update Supabase email templates from EMAIL_TEMPLATES.md
# This uses the Supabase Management API to programmatically update email templates
# Reads configuration from env.json in the project root

set -e

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMPLATES_FILE="$SCRIPT_DIR/EMAIL_TEMPLATES.md"
ENV_FILE="$SCRIPT_DIR/../env.json"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo -e "${RED}Error: jq is not installed${NC}"
    echo "Install jq:"
    echo "  macOS: brew install jq"
    echo "  Ubuntu/Debian: sudo apt-get install jq"
    exit 1
fi

# Check if env.json exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: env.json not found at: $ENV_FILE${NC}"
    exit 1
fi

# Load configuration from env.json
SUPABASE_URL=$(jq -r '.SUPABASE_URL' "$ENV_FILE")
SUPABASE_ACCESS_TOKEN=$(jq -r '.SUPABASE_ACCESS_TOKEN // empty' "$ENV_FILE")

# Extract project reference from URL
SUPABASE_PROJECT_REF=$(echo "$SUPABASE_URL" | sed -E 's|https://([^.]+)\.supabase\.co|\1|')

# Validate configuration
if [ -z "$SUPABASE_ACCESS_TOKEN" ] || [ "$SUPABASE_ACCESS_TOKEN" == "null" ]; then
    echo -e "${RED}Error: SUPABASE_ACCESS_TOKEN is not set in env.json${NC}"
    echo "Get your access token from: https://supabase.com/dashboard/account/tokens"
    echo "Add it to env.json as: \"SUPABASE_ACCESS_TOKEN\": \"sbp_your_token_here\""
    exit 1
fi

if [ -z "$SUPABASE_PROJECT_REF" ]; then
    echo -e "${RED}Error: Could not extract project reference from SUPABASE_URL${NC}"
    exit 1
fi

echo -e "${GREEN}Updating Supabase email templates...${NC}"
echo -e "📋 Using project: ${SUPABASE_PROJECT_REF}"
echo -e "📁 Reading templates from: EMAIL_TEMPLATES.md\n"

# Function to extract template content from markdown
extract_template() {
    local template_name=$1
    local field=$2

    if [ "$field" == "subject" ]; then
        # Extract subject (between **Subject:** and next ```)
        sed -n "/## [0-9]\. $template_name/,/## [0-9]\./p" "$TEMPLATES_FILE" | \
        sed -n '/\*\*Subject:\*\*/,/```/p' | \
        sed '1d;$d' | sed '/^```$/d' | sed 's/^```//'
    elif [ "$field" == "body" ]; then
        # Extract HTML body (between **Body (HTML):** and next ---)
        sed -n "/## [0-9]\. $template_name/,/^---$/p" "$TEMPLATES_FILE" | \
        sed -n '/\*\*Body (HTML):\*\*/,/^```$/p' | \
        sed '1d;$d' | sed '/^```html$/d' | sed '/^```$/d'
    fi
}

# Function to update a template via API
update_template() {
    local template_type=$1
    local template_name=$2

    echo -e "${YELLOW}Updating $template_name...${NC}"

    subject=$(extract_template "$template_name" "subject")
    body=$(extract_template "$template_name" "body")

    if [ -z "$subject" ] || [ -z "$body" ]; then
        echo -e "${RED}Error: Could not extract template content for $template_name${NC}"
        return 1
    fi

    # Create JSON payload with lowercase field names and _content suffix
    template_type_lower=$(echo "$template_type" | tr '[:upper:]' '[:lower:]')
    json_payload=$(jq -n \
        --arg subject "$subject" \
        --arg body "$body" \
        --arg type_lower "$template_type_lower" \
        '{
            ("mailer_subjects_" + $type_lower): $subject,
            ("mailer_templates_" + $type_lower + "_content"): $body
        }')

    # Make API request
    response=$(curl -s -w "\n%{http_code}" -X PATCH \
        "https://api.supabase.com/v1/projects/$SUPABASE_PROJECT_REF/config/auth" \
        -H "Authorization: Bearer $SUPABASE_ACCESS_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$json_payload")

    http_code=$(echo "$response" | tail -n1)
    response_body=$(echo "$response" | sed '$d')

    if [ "$http_code" -eq 200 ] || [ "$http_code" -eq 201 ]; then
        echo -e "${GREEN}✓ Successfully updated $template_name${NC}\n"
    else
        echo -e "${RED}✗ Failed to update $template_name (HTTP $http_code)${NC}"
        echo "Response: $response_body"
        echo ""
        return 1
    fi
}

# Update each template
update_template "CONFIRMATION" "Confirm Signup"
update_template "RECOVERY" "Reset Password"
update_template "MAGIC_LINK" "Magic Link"
update_template "INVITE" "Invite User"

echo -e "${GREEN}All email templates updated successfully!${NC}"
echo -e "${YELLOW}Note: Changes may take a few minutes to propagate.${NC}"
