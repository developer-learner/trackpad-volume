#!/bin/bash
# Installs a pre-commit hook that reminds to run SMOKE-CHECK.md
# when main.swift has changed.

HOOK_DIR="$(git rev-parse --git-dir)/hooks"
HOOK="$HOOK_DIR/pre-commit"

cat > "$HOOK" << 'HOOK_EOF'
#!/bin/bash
if git diff --cached --name-only | grep -q "Sources/trackpad-volume/main.swift"; then
    echo ""
    echo "⚠️  main.swift changed — run SMOKE-CHECK before pushing"
    echo "   See docs/SMOKE-CHECK.md"
    echo ""
fi
HOOK_EOF

chmod +x "$HOOK"
echo "Pre-commit hook installed at $HOOK"
