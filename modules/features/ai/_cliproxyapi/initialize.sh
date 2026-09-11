set -euo pipefail

# Preserve provider credentials and configuration changes made through the UI.
if [ ! -e /var/lib/cliproxyapi/config.yaml ]; then
  install -m 0600 "$1" /var/lib/cliproxyapi/config.yaml
fi
