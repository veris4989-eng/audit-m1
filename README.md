# audit-m1 — Poste d'auditeur

Dépôt de mission pour la semaine **Kill Chain** (M1 Cybersécurité).
Il versionne ma **méthode**, mon **journal de bord**, mes **scripts** — jamais de secret ni de donnée réelle.

> ⚖️ **Cadre légal** — Outils à double usage. Emploi **exclusivement sur périmètre autorisé** :
> lab de formation, CTF, ou mission avec mandat écrit. Art. 323-1 et suivants du Code pénal.
> **Aucun** identifiant, loot, capture ou donnée réelle n'est versionné. Dépôt **privé**.

---

## Ma boîte à outils — 1 outil par phase

| Phase | Outil | Rôle |
|------|-------|------|
| 1 — Reconnaissance réseau | **nmap** | Hôtes vivants, ports ouverts, services |
| 2 — Énumération web | **ffuf** | Répertoires / fichiers cachés |
| 3 — Écoute / capture | **wireshark** | Capturer et analyser le trafic |
| 4 — Cassage de hash | **john** | Cassage hors-ligne (CPU, marche partout) |
| 5 — Attaque en ligne | **hydra** | Brute-force de services (SSH, FTP…) |
| 6 — Partages / SMB | **enum4linux-ng** | Énumération Windows / partages |
| 7 — Post-exploitation | **linpeas** | Pistes d'escalade de privilèges Linux |

Outils d'appoint installés aussi : `hashid` (identifier un hash), `whatweb` (techno d'un site), `dig`, `curl`.

---

## Installation du poste

```bash
chmod +x install.sh
./install.sh
```

Le script est **idempotent** (relançable) et se termine par une vérification :
chaque phase doit répondre **OK**.

---

## Structure du dépôt

```
audit-m1/
├── README.md      # ce fichier
├── .gitignore     # anti-secrets / loot
├── install.sh     # installe la boîte à outils
├── recon/         # mardi — découverte réseau, ports, OSINT
├── web/           # mardi — énumération applicative
├── crack/         # jeudi — cassage de hash (hors-ligne)
├── ad/            # « Le Pont » — Active Directory
├── pivot/         # « Le Pont » — tunneling, rebond
├── notes/         # journal de bord + cheatsheets
├── reports/       # rapport de vendredi (données sensibles ignorées)
├── scripts/       # scripts perso
├── wordlists/     # dictionnaires (gros fichiers ignorés par git)
└── loot/          # JAMAIS versionné — hashes, dumps, captures
```

---

## Discipline de travail

- **Dépôt privé + 2FA** activée sur le compte GitHub.
- **Committer petit et souvent**, message qui dit *quoi* et *pourquoi*.
- Un **journal horodaté** dans `notes/` : commande → résultat → preuve → conclusion.
- Avant chaque `push` : passer un scanner de secrets — `gitleaks detect --source . -v`.
