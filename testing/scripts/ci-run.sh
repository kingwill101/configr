#!/usr/bin/env bash
# CI-optimized test runner — builds once, runs tests per distro
# Designed for GitHub Actions matrix jobs where CONFIGR_TEST_ENV is set
set -euo pipefail

# Determined by the CI matrix (ubuntu, debian, fedora, arch, alpine)
DISTRO="${CONFIGR_TEST_ENV:-ubuntu}"
TAG="${DISTRO}"

# Map distro to tag
case "$DISTRO" in
  ubuntu|debian) TAG="debian" ;;
  fedora)        TAG="fedora" ;;
  arch)          TAG="arch" ;;
  alpine)        TAG="alpine" ;;
esac

echo "=== CI Test Run: $DISTRO (tag: $TAG) ==="

# Run only tests tagged for this distro
dart pub get
dart test --tags "$TAG" --reporter expanded

echo "=== $DISTRO tests completed ==="