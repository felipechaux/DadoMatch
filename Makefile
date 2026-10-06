.PHONY: release promote status help

BUMP ?= patch

## Bump the version (BUMP=patch|minor|major), tag it and upload to Internal Testing
release:
	@case "$(BUMP)" in patch|minor|major) ;; *) echo "BUMP must be patch, minor or major"; exit 1 ;; esac
	gh workflow run release.yml --ref main -f bump=$(BUMP)
	@echo "🚀 Release ($(BUMP)) started. Follow it with: make status"

## Promote the latest Internal Testing build to Production
promote:
	gh workflow run deploy.yml --ref main -f lane=production
	@echo "📦 Promotion to Production started. Follow it with: make status"

## Show the latest release/deploy runs
status:
	gh run list --workflow release.yml --limit 3
	gh run list --workflow deploy.yml --limit 3

help:
	@echo ""
	@echo "  make release [BUMP=patch|minor|major]  Bump, tag and upload to Internal Testing"
	@echo "  make promote                           Promote latest Internal build to Production"
	@echo "  make status                            Show latest release/deploy runs"
	@echo ""
