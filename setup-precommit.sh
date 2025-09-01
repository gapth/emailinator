#!/bin/bash

# Setup script for git pre-commit hook
# This script ensures the pre-commit hook is properly installed and dependencies are available

set -e

echo "🔧 Setting up git pre-commit hook..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Check if we're in a git repository
if [ ! -d ".git" ]; then
    print_status $RED "❌ Not in a git repository. Please run this script from the project root."
    exit 1
fi

# Check if the pre-commit hook exists
if [ ! -f ".git/hooks/pre-commit" ]; then
    print_status $RED "❌ Pre-commit hook not found. Please ensure .git/hooks/pre-commit exists."
    exit 1
fi

# Make sure the hook is executable
print_status $YELLOW "🔐 Making pre-commit hook executable..."
chmod +x .git/hooks/pre-commit
print_status $GREEN "✅ Pre-commit hook is now executable"

# Check for required tools
print_status $YELLOW "🔍 Checking for required tools..."

# Check Flutter
if command -v flutter >/dev/null 2>&1; then
    print_status $GREEN "✅ Flutter found: $(flutter --version | head -n1)"
else
    print_status $RED "❌ Flutter not found. Please install Flutter SDK."
    echo "   Visit: https://flutter.dev/docs/get-started/install"
fi

# Check Node.js/npm
if command -v npm >/dev/null 2>&1; then
    print_status $GREEN "✅ npm found: $(npm --version)"
else
    print_status $RED "❌ npm not found. Please install Node.js."
    echo "   Visit: https://nodejs.org/"
fi

# Check Python
if command -v python3 >/dev/null 2>&1; then
    print_status $GREEN "✅ Python found: $(python3 --version)"
else
    print_status $RED "❌ Python3 not found. Please install Python 3.12+."
fi

# Install Python dependencies
print_status $YELLOW "🐍 Installing Python dependencies..."
if make install; then
    print_status $GREEN "✅ Python dependencies installed"
else
    print_status $RED "❌ Failed to install Python dependencies"
    exit 1
fi

# Install npm dependencies
print_status $YELLOW "📦 Installing npm dependencies..."
if npm install; then
    print_status $GREEN "✅ npm dependencies installed"
else
    print_status $RED "❌ Failed to install npm dependencies"
    exit 1
fi

# Test the hook (dry run)
print_status $YELLOW "🧪 Testing pre-commit hook..."
if .git/hooks/pre-commit; then
    print_status $GREEN "✅ Pre-commit hook test passed"
else
    print_status $YELLOW "⚠️  Pre-commit hook test failed, but this might be expected if there are uncommitted changes"
fi

print_status $GREEN "🎉 Pre-commit hook setup complete!"
print_status $YELLOW "📖 See PRE_COMMIT_HOOK_README.md for more information"
