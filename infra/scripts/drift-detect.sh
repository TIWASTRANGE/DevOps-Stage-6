#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

TERRAFORM_DIR="./infra/terraform"
EMAIL_RECIPIENT="${NOTIFICATION_EMAIL}"

echo -e "${YELLOW} Running Terraform Drift Detection...${NC}"

cd "$TERRAFORM_DIR"

# Initialize Terraform
terraform init -input=false

# Run terraform plan and capture exit code
set +e
terraform plan -detailed-exitcode -out=drift-plan
PLAN_EXIT_CODE=$?
set -e

# Exit codes:
# 0 = No changes
# 1 = Error
# 2 = Changes detected (drift)

if [ $PLAN_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN} No drift detected. Infrastructure is in sync.${NC}"
    exit 0
elif [ $PLAN_EXIT_CODE -eq 2 ]; then
    echo -e "${RED} DRIFT DETECTED!${NC}"
    echo -e "${YELLOW}Changes have been detected in your infrastructure.${NC}"
    
    # Send email notification
    if [ -n "$EMAIL_RECIPIENT" ]; then
        echo -e "${YELLOW} Sending email notification...${NC}"
        
        # Create email body
        cat > /tmp/drift-email.txt << EOF
Subject: Terraform Drift Detected - Action Required

Infrastructure drift has been detected!

Time: $(date)
Repository: $(git config --get remote.origin.url)
Branch: $(git rev-parse --abbrev-ref HEAD)
Commit: $(git rev-parse --short HEAD)

Please review the plan and take appropriate action.

To view the full plan, run:
cd $TERRAFORM_DIR && terraform show drift-plan

To apply the changes, run:
cd $TERRAFORM_DIR && terraform apply drift-plan
EOF
        
        # Send email (requires mailx or sendmail configured)
        if command -v mail &> /dev/null; then
            mail -s "Terraform Drift Detected" "$EMAIL_RECIPIENT" < /tmp/drift-email.txt
            echo -e "${GREEN} Email sent successfully${NC}"
        else
            echo -e "${YELLOW} Email client not configured. Manual notification required.${NC}"
        fi
    fi
    
    echo ""
    echo -e "${YELLOW}Waiting for manual approval...${NC}"
    echo -e "Review the plan and press ENTER to continue with apply, or Ctrl+C to abort."
    read -r
    
    echo -e "${YELLOW} Applying changes...${NC}"
    terraform apply drift-plan
    
    echo -e "${GREEN} Changes applied successfully!${NC}"
    exit 0
else
    echo -e "${RED} Terraform plan failed with exit code $PLAN_EXIT_CODE${NC}"
    exit 1
fi