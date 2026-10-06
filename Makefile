.PHONY: release promote notes release-ci promote-ci status help

BUMP ?= patch

## Local: bump the version (BUMP=patch|minor|major), upload to Internal Testing and tag vX.Y.Z
release:
	@case "$(BUMP)" in patch|minor|major) ;; *) echo "BUMP must be patch, minor or major"; exit 1 ;; esac
	bundle exec fastlane android release bump:$(BUMP)

## Preview the next release notes (uploads nothing); with BUMP=... also saves them as the draft release uses
notes:
	bundle exec fastlane android notes $(if $(filter command line,$(origin BUMP)),bump:$(BUMP))

## Local: promote the latest Internal Testing build to Production
promote:
	bundle exec fastlane android production

## Same as release/promote, but on GitHub Actions
release-ci:
	@case "$(BUMP)" in patch|minor|major) ;; *) echo "BUMP must be patch, minor or major"; exit 1 ;; esac
	gh workflow run release.yml --ref main -f bump=$(BUMP)
	@echo "🚀 Release ($(BUMP)) started on GitHub Actions. Follow it with: make status"

promote-ci:
	gh workflow run deploy.yml --ref main -f lane=production
	@echo "📦 Promotion to Production started on GitHub Actions. Follow it with: make status"

## Show the latest GitHub Actions release/deploy runs
status:
	gh run list --workflow release.yml --limit 3
	gh run list --workflow deploy.yml --limit 3

help:
	@echo ""
	@echo "  make release [BUMP=patch|minor|major]     Bump, upload to Internal Testing and tag (local)"
	@echo "  make promote                              Promote latest Internal build to Production (local)"
	@echo "  make notes [BUMP=patch]                   Preview the next release notes (BUMP saves a draft)"
	@echo "  make release-ci / promote-ci [BUMP=...]   Same, on GitHub Actions"
	@echo "  make status                               Latest GitHub Actions runs"
	@echo ""
