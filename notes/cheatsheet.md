# Cheatsheet — Ma boîte à outils (commandes de base)

> Rappel : périmètre **autorisé uniquement** (lab, CTF, mandat écrit).
> Remplace `CIBLE` par l'IP/host autorisé, `RESEAU` par la plage (ex. `10.0.0.0/24`).

---

## Phase 1 — nmap (reconnaissance réseau)
```bash
nmap -sn RESEAU                      # qui est vivant ? (ping scan)
nmap -sC -sV -oA recon/nmap CIBLE    # ports + services + scripts, sortie dans recon/
nmap -p- CIBLE                       # scan de TOUS les ports (long)
```

## Phase 2 — ffuf (énumération web)
```bash
# Découverte de répertoires/fichiers cachés
ffuf -u http://CIBLE/FUZZ -w /usr/share/wordlists/dirb/common.txt

# Avec extensions et filtrage des 404
ffuf -u http://CIBLE/FUZZ -w wordlist.txt -e .php,.txt,.html -mc 200,301,302
```
> Astuce : lance d'abord `whatweb http://CIBLE` pour connaître la techno.

## Phase 3 — wireshark (écoute / capture)
```bash
wireshark &                          # interface graphique
# En ligne de commande (tshark) :
tshark -i eth0 -w captures/dump.pcap # capture vers un fichier
```
> Filtres utiles dans l'UI : `http`, `ip.addr == CIBLE`, `tcp.port == 80`.
> ⚠️ Sur l'infra Proxmox de l'école : si rien n'est capturé, demander au formateur
> (config réseau/bridge du lab) — ne pas toucher à l'hyperviseur.

## Phase 4 — john (cassage de hash, hors-ligne)
```bash
hashid 'LE_HASH'                     # 1) identifier le type de hash
john --wordlist=/usr/share/wordlists/rockyou.txt loot/hashes.txt   # 2) casser
john --show loot/hashes.txt          # 3) afficher les mots de passe trouvés
```
> Les hashes vont dans `loot/` — **jamais** committé.

## Phase 5 — hydra (attaque en ligne)
```bash
# Brute-force SSH avec une liste de mots de passe
hydra -l admin -P /usr/share/wordlists/rockyou.txt ssh://CIBLE

# FTP, avec liste d'utilisateurs ET de mots de passe
hydra -L users.txt -P pass.txt ftp://CIBLE
```

## Phase 6 — enum4linux-ng (partages / SMB)
```bash
enum4linux-ng -A CIBLE               # énumération complète
smbclient -L //CIBLE/ -N            # lister les partages (session nulle)
```

## Phase 7 — linpeas (post-exploitation, sur la CIBLE)
```bash
# Une fois un accès obtenu sur la machine Linux cible :
./linpeas.sh | tee loot/linpeas-CIBLE.txt   # scanne les pistes d'escalade
```
> linpeas est dans `~/tools/`. Transfère-le sur la cible puis exécute-le.

---

## Réflexe git (à chaque fin d'action)
```bash
git add notes/ recon/ web/           # jamais 'loot/' (ignoré de toute façon)
git commit -m "recon: ports CIBLE + hypothèses"
git push
```
