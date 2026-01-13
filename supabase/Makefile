.PHONY: help update-templates update-templates-ts update-templates-sh

help:
	@echo "Supabase Email Template Management"
	@echo ""
	@echo "Available commands:"
	@echo "  make update-templates     - Update email templates using TypeScript (recommended)"
	@echo "  make update-templates-ts  - Update email templates using TypeScript"
	@echo "  make update-templates-sh  - Update email templates using Bash script"
	@echo ""
	@echo "Prerequisites:"
	@echo "  Add SUPABASE_ACCESS_TOKEN to ../env.json"
	@echo "  Get your token from: https://supabase.com/dashboard/account/tokens"
	@echo ""
	@echo "Example env.json:"
	@echo '  {'
	@echo '    "SUPABASE_URL": "https://your-project.supabase.co",'
	@echo '    "SUPABASE_ACCESS_TOKEN": "sbp_your_token_here"'
	@echo '  }'

update-templates: update-templates-ts

update-templates-ts:
	@echo "🚀 Updating email templates using TypeScript..."
	@npx tsx update_email_templates.ts

update-templates-sh:
	@echo "🚀 Updating email templates using Bash..."
	@./update_email_templates.sh
