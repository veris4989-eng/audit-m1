#!/usr/bin/env bash
# =============================================================================
# prep-kali.sh - Prepare/verifie une Kali pour le lab CERBERE. Idempotent.
# A lancer DANS le dossier qui contient users.txt et cerbere.wordlist.
#   chmod +x prep-kali.sh && ./prep-kali.sh
# =============================================================================
set -u
GREEN='\033[0;32m'; RED='\033[0;31m'; YEL='\033[0;33m'; NC='\033[0m'
ok(){ printf "  ${GREEN}[OK]${NC} %s\n" "$1"; }
ko(){ printf "  ${RED}[ABSENT]${NC} %s\n" "$1"; }

# outil -> paquet apt (best effort ; le verificateur reste la source de verite)
declare -A PKG=(
  [nxc]=netexec
  [impacket-GetNPUsers]=python3-impacket
  [impacket-GetUserSPNs]=python3-impacket
  [impacket-secretsdump]=python3-impacket
  [bloodhound-python]=bloodhound.py
  [hashcat]=hashcat
  [ntpdate]=ntpdate
)
TOOLS=(nxc impacket-GetNPUsers impacket-GetUserSPNs impacket-secretsdump bloodhound-python hashcat ntpdate)

echo "== 1. Outils =="
missing_pkgs=""
for t in "${TOOLS[@]}"; do
  if command -v "$t" >/dev/null 2>&1; then ok "$t"; else ko "$t"; missing_pkgs="$missing_pkgs ${PKG[$t]}"; fi
done

echo "== 2. Ressources du lab =="
for f in users.txt cerbere.wordlist; do
  if [ -f "$f" ]; then ok "$f ($(wc -l < "$f") lignes)"; else ko "$f  (copie-le depuis le dossier TP2)"; fi
done

if [ -n "${missing_pkgs// /}" ]; then
  uniq_pkgs=$(echo "$missing_pkgs" | tr ' ' '\n' | sed '/^$/d' | sort -u | tr '\n' ' ')
  echo ""
  printf "${YEL}== 3. Installation des manquants ==${NC}\n"
  echo "  sudo apt-get update && sudo apt-get install -y $uniq_pkgs"
  read -r -p "  Lancer l'installation maintenant ? [o/N] " a
  if [ "${a:-N}" = "o" ] || [ "${a:-N}" = "O" ]; then
    sudo apt-get update -y && sudo apt-get install -y $uniq_pkgs
    echo ""
    echo "  Relance ./prep-kali.sh pour re-verifier (doit etre tout vert)."
  else
    echo "  (Si un paquet n'existe pas sous ce nom : 'nxc' = paquet netexec ; sinon 'crackmapexec'.)"
  fi
else
  echo ""
  printf "${GREEN}== Tout est pret. La Kali est bonne pour le lab. ==${NC}\n"
fi

# rappel: alignement d'horloge avant Kerberos (remplacer <DC>)
echo ""
echo "  Avant d'attaquer : sudo ntpdate <IP_DU_DC>   (sinon KRB_AP_ERR_SKEW)"
