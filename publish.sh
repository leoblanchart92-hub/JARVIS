#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"

if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Utilisation : ./publish.sh 1.0.1"
  echo "Indique une version au format MAJEUR.MINEUR.CORRECTIF."
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Erreur : Git n'est pas installé."
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "Erreur : GitHub CLI (gh) n'est pas installé."
  echo "Installe GitHub CLI puis connecte-toi avec : gh auth login"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Erreur : connecte-toi à GitHub avec : gh auth login"
  exit 1
fi

BRANCH="$(git branch --show-current)"
if [[ "$BRANCH" != "main" ]]; then
  echo "Erreur : place-toi sur la branche main (branche actuelle : $BRANCH)."
  exit 1
fi

git add -A
if ! git diff --cached --quiet; then
  git commit -m "Publish ASTRA v$VERSION"
else
  echo "Aucun changement local à committer."
fi

echo "Envoi du code sur GitHub..."
git push origin main

echo "Lancement de la compilation APK et de la publication v$VERSION..."
gh workflow run release-apk.yml --ref main -f version="$VERSION"

echo
echo "Publication lancée."
echo "Suivi : https://github.com/leoblanchart92-hub/Jarvis/actions"
echo "La Release et le tag v$VERSION seront créés seulement si la compilation réussit."
