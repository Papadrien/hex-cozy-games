#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# inject_google_services.sh
#
# Reconstruit google-services.json depuis la variable d'environnement base64
# GOOGLE_SERVICES_JSON_BASE64 — à utiliser dans GitHub Actions (ou tout autre
# CI/CD) pour ne pas committer le vrai fichier dans le repo.
#
# Usage dans GitHub Actions :
#   - name: Inject Firebase config
#     run: bash scripts/inject_google_services.sh
#     env:
#       GOOGLE_SERVICES_JSON_BASE64: ${{ secrets.GOOGLE_SERVICES_JSON_BASE64 }}
#
# Pour encoder votre google-services.json en base64 :
#   base64 -i android/app/google-services.json | tr -d '\n'
#   → copier le résultat dans un secret GitHub nommé GOOGLE_SERVICES_JSON_BASE64
# ─────────────────────────────────────────────────────────────────────────────

set -euo pipefail

TARGET="android/app/google-services.json"

if [ -z "${GOOGLE_SERVICES_JSON_BASE64:-}" ]; then
  echo "⚠️  Variable GOOGLE_SERVICES_JSON_BASE64 non définie."
  echo "    En local, assurez-vous que $TARGET contient le vrai fichier Firebase."
  exit 0
fi

echo "$GOOGLE_SERVICES_JSON_BASE64" | base64 --decode > "$TARGET"
echo "✅ $TARGET reconstruit depuis GOOGLE_SERVICES_JSON_BASE64"
