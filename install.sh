#!/usr/bin/env bash
# =====================================================================
#  install.sh — Poste d'auditeur M1 (Debian)
#  Installe la boîte à outils : 1 outil par phase de la kill chain.
#  Idempotent : relançable sans casser ce qui est déjà installé.
# =====================================================================
#  Usage :   chmod +x install.sh && ./install.sh
#  (le script demandera le mot de passe sudo)
# ---------------------------------------------------------------------
#  CADRE LÉGAL : outils à double usage. Emploi UNIQUEMENT sur périmètre
#  autorisé (lab de formation, CTF, mission avec mandat écrit).
#  Art. 323-1 et suivants du Code pénal.
# =====================================================================

set -euo pipefail

# --- Couleurs pour lisibilité ---
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[+]${NC} $*"; }
warn()  { echo -e "${YELLOW}[!]${NC} $*"; }
err()   { echo -e "${RED}[x]${NC} $*"; }

# --- Vérif : on est bien sur Debian/Ubuntu (apt présent) ---
if ! command -v apt-get >/dev/null 2>&1; then
  err "apt-get introuvable. Ce script est prévu pour Debian/Ubuntu."
  exit 1
fi

info "Mise à jour de l'index des paquets..."
sudo apt-get update -y

# =====================================================================
#  1) Paquets disponibles dans les dépôts Debian (apt)
# =====================================================================
#  Phase 1 recon      -> nmap
#  Phase 2 web        -> ffuf
#  Phase 3 capture    -> wireshark (+ tshark en CLI)
#  Phase 4 hash       -> john (john the ripper)
#  Phase 5 en ligne   -> hydra
#  Phase 6 SMB        -> smbclient (base) ; enum4linux-ng via pipx plus bas
#  + outils d'appoint utiles : hashid, whatweb, dig, curl, git
# ---------------------------------------------------------------------
APT_PKGS=(
  git
  nmap
  ffuf
  wireshark
  tshark
  john
  hydra
  smbclient
  hashid
  whatweb
  dnsutils        # fournit 'dig'
  curl
  pipx
)

info "Installation des paquets apt : ${APT_PKGS[*]}"
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${APT_PKGS[@]}"

# =====================================================================
#  2) pipx — outils Python (isolés, propres, mis à jour facilement)
# =====================================================================
info "Configuration de pipx..."
pipx ensurepath >/dev/null 2>&1 || true
export PATH="$HOME/.local/bin:$PATH"

#  Phase 6 SMB : enum4linux-ng (version moderne, maintenue)
if ! command -v enum4linux-ng >/dev/null 2>&1; then
  info "Installation de enum4linux-ng (pipx)..."
  pipx install enum4linux-ng || warn "enum4linux-ng : échec pipx, à installer manuellement."
else
  info "enum4linux-ng déjà présent."
fi

# =====================================================================
#  3) linpeas — Phase 7 post-exploitation (script, pas un paquet)
# =====================================================================
#  On le télécharge dans ~/tools/ ; il se lance sur la CIBLE, hors-ligne.
TOOLS_DIR="$HOME/tools"
mkdir -p "$TOOLS_DIR"
if [ ! -f "$TOOLS_DIR/linpeas.sh" ]; then
  info "Téléchargement de linpeas.sh dans $TOOLS_DIR ..."
  if curl -fsSL "https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh" \
       -o "$TOOLS_DIR/linpeas.sh"; then
    chmod +x "$TOOLS_DIR/linpeas.sh"
    info "linpeas.sh prêt."
  else
    warn "Téléchargement linpeas échoué (réseau/allowlist ?). À récupérer manuellement."
  fi
else
  info "linpeas.sh déjà présent."
fi

# =====================================================================
#  4) Dictionnaire de base : rockyou (pour john, Phase 4)
# =====================================================================
if [ -f /usr/share/wordlists/rockyou.txt.gz ] && [ ! -f /usr/share/wordlists/rockyou.txt ]; then
  info "Décompression de rockyou.txt ..."
  sudo gunzip -k /usr/share/wordlists/rockyou.txt.gz || warn "rockyou : décompression échouée."
fi

# =====================================================================
#  5) Vérification finale — chaque phase répond-elle présent ?
# =====================================================================
echo
info "================ VÉRIFICATION DE L'ARSENAL ================"
check() {
  if command -v "$1" >/dev/null 2>&1; then
    echo -e "  ${GREEN}OK${NC}   $2 ($1)"
  else
    echo -e "  ${RED}MANQUE${NC} $2 ($1)"
  fi
}
check nmap           "Phase 1 — Reconnaissance réseau"
check ffuf           "Phase 2 — Énumération web"
check wireshark      "Phase 3 — Écoute / capture"
check john           "Phase 4 — Cassage de hash"
check hydra          "Phase 5 — Attaque en ligne"
check enum4linux-ng  "Phase 6 — Partages / SMB"
[ -f "$TOOLS_DIR/linpeas.sh" ] \
  && echo -e "  ${GREEN}OK${NC}   Phase 7 — Post-exploit (linpeas.sh dans ~/tools)" \
  || echo -e "  ${RED}MANQUE${NC} Phase 7 — linpeas.sh"
echo -e "${GREEN}[+]${NC} =========================================================="
echo
info "Terminé. Si un outil manque : relance le script, ou installe-le à la main."
warn "Rappel : usage sur périmètre AUTORISÉ uniquement (lab, CTF, mandat écrit)."
