#!/usr/bin/env bash
# GNU Affero General Public License v3.0 or later (see COPYING or https://www.gnu.org/licenses/agpl.txt)
set -euo pipefail

cat << 'EOF'
===========================================
============ Linter: ansible ==============
===========================================
============ Brought to you by ============
       _       _                 _
      | |_ ___| | ___  _   _  __| |
      | __/ __| |/ _ \| | | |/ _` |
      | || (__| | (_) | |_| | (_| |
       \__\___|_|\___/ \__,_|\__,_|
===========================================
===== https://github.com/t-c-l-o-u-d =====
===========================================
EOF
echo ""

errors=0

echo "Running ansible-lint..."
if ! ansible-lint; then
    echo "FAIL: ansible-lint"
    errors=$((errors + 1))
else
    echo "PASS: ansible-lint"
fi

if [[ $errors -gt 0 ]]; then
    echo ""
    echo "Ansible linting failed with $errors error(s)"
    exit 1
fi
