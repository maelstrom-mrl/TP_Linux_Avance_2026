# Atelier Linux Avancé — 10h
### M1 Informatique · GitHub Codespaces · Processus & Services · Réseau & Sécurité · Conteneurs Docker

---

> **Public cible :** Étudiants M1 Informatique, niveau Linux confirmé  
> **Durée totale :** 10 heures  
> **Environnement :** GitHub Codespaces (Ubuntu 22.04 LTS)  
> **Prérequis :** Compte GitHub, notions de shell, connaissance des commandes de base

---

## Sommaire

| Module | Thème | Durée |
|--------|-------|-------|
| 0 | Mise en place de l'environnement Codespaces | 30 min |
| 1 | Processus, signaux et systemd | 2h30 |
| 2 | Réseau Linux et sécurité | 2h30 |
| 3 | Conteneurs Docker | 3h |
| 4 | Projet intégrateur | 1h30 |

---

## Module 0 — Mise en place de l'environnement (30 min)

### Objectifs
- Créer et configurer un Codespace depuis un dépôt GitHub
- Comprendre la structure de l'environnement de travail
- Vérifier les outils disponibles

### 0.1 — Création du Codespace

1. Forker le dépôt de l'atelier : `github.com/<org>/atelier-linux-m1`
2. Cliquer sur **Code → Codespaces → Create codespace on main**
3. Attendre l'initialisation (environ 2 minutes)

Le dépôt contient un fichier `.devcontainer/devcontainer.json` préconfiguré :

```json
{
  "name": "Atelier Linux M1",
  "image": "mcr.microsoft.com/devcontainers/base:ubuntu-22.04",
  "features": {
    "ghcr.io/devcontainers/features/docker-in-docker:2": {},
    "ghcr.io/devcontainers/features/common-utils:2": {}
  },
  "postCreateCommand": "sudo apt-get update && sudo apt-get install -y nmap tcpdump iptables net-tools",
  "remoteUser": "vscode"
}
```

> **Note :** Le feature `docker-in-docker` permet d'utiliser Docker à l'intérieur du Codespace.

### 0.2 — Vérification de l'environnement

```bash
# Vérifier la version Ubuntu
lsb_release -a

# Vérifier les outils disponibles
which docker nmap tcpdump systemctl ss ip

# Vérifier les droits sudo
sudo whoami
```

**Résultat attendu :** Tous les outils sont présents, `sudo whoami` retourne `root`.

---

## Module 1 — Processus, signaux et systemd (2h30)

### Objectifs
- Maîtriser la gestion avancée des processus Linux
- Comprendre le cycle de vie des services systemd
- Créer, déboguer et superviser ses propres unités systemd

---

### 1.1 — Gestion avancée des processus (45 min)

#### Théorie : le modèle de processus Linux

Chaque processus Linux possède :
- Un **PID** (Process ID) unique
- Un **PPID** (Parent PID)
- Un **état** : Running (R), Sleeping (S), Zombie (Z), Stopped (T)
- Des **descripteurs de fichiers** hérités du parent

```
init/systemd (PID 1)
├── sshd (PID 523)
│   └── bash (PID 1042)
│       └── ps (PID 1087)
└── cron (PID 847)
```

#### Exercice 1.1.a — Exploration de l'arbre des processus

```bash
# Afficher l'arbre complet avec PIDs
pstree -p

# Afficher les processus avec ressources détaillées
ps aux --sort=-%cpu | head -20

# Surveiller en temps réel (quitter avec 'q')
top -d 1

# Version améliorée si disponible
htop
```

**Questions :**
1. Quel est le PID de votre shell courant ? (`echo $$`)
2. Quel processus est le parent de votre shell ?
3. Combien de threads le processus `systemd` utilise-t-il ?

#### Exercice 1.1.b — Manipulation des signaux

```bash
# Lancer un processus en arrière-plan
sleep 300 &
PID_SLEEP=$!
echo "PID du processus sleep : $PID_SLEEP"

# Lister les jobs du shell courant
jobs -l

# Envoyer SIGSTOP (suspend)
kill -SIGSTOP $PID_SLEEP
ps aux | grep sleep   # État : T (stopped)

# Reprendre avec SIGCONT
kill -SIGCONT $PID_SLEEP
ps aux | grep sleep   # État : S (sleeping)

# Terminer proprement avec SIGTERM
kill -SIGTERM $PID_SLEEP

# Forcer l'arrêt avec SIGKILL (non capturable)
sleep 300 &
kill -SIGKILL $!
```

**Tableau des signaux importants :**

| Signal | Numéro | Description | Capturable |
|--------|--------|-------------|------------|
| SIGHUP | 1 | Rechargement de configuration | Oui |
| SIGINT | 2 | Interruption (Ctrl+C) | Oui |
| SIGQUIT | 3 | Quit avec core dump | Oui |
| SIGKILL | 9 | Arrêt immédiat | **Non** |
| SIGTERM | 15 | Arrêt propre | Oui |
| SIGSTOP | 19 | Suspension | **Non** |
| SIGCONT | 18 | Reprise | Oui |

#### Exercice 1.1.c — Trap et gestion de signaux en Bash

Créer le fichier `~/scripts/signal_demo.sh` :

```bash
#!/bin/bash

cleanup() {
    echo ""
    echo "[$(date +%T)] Signal reçu : nettoyage en cours..."
    rm -f /tmp/signal_demo_*.lock
    echo "[$(date +%T)] Nettoyage terminé. Bye."
    exit 0
}

reload_config() {
    echo "[$(date +%T)] SIGHUP reçu : rechargement de la configuration..."
    # Simuler un rechargement
    sleep 1
    echo "[$(date +%T)] Configuration rechargée."
}

# Installer les gestionnaires de signaux
trap cleanup SIGTERM SIGINT
trap reload_config SIGHUP

LOCKFILE="/tmp/signal_demo_$$.lock"
touch "$LOCKFILE"
echo "[$(date +%T)] Démarrage (PID: $$). Lockfile: $LOCKFILE"
echo "Envoyez SIGHUP pour recharger, SIGTERM/SIGINT pour quitter."

# Boucle principale
counter=0
while true; do
    echo "[$(date +%T)] En cours... (itération $counter)"
    counter=$((counter + 1))
    sleep 5
done
```

```bash
chmod +x ~/scripts/signal_demo.sh

# Terminal 1 : lancer le script
~/scripts/signal_demo.sh

# Terminal 2 : interagir
kill -SIGHUP $(pgrep -f signal_demo.sh)
kill -SIGTERM $(pgrep -f signal_demo.sh)
```

---

### 1.2 — systemd en profondeur (1h15)

#### Théorie : architecture de systemd

systemd est le gestionnaire de services (PID 1) sous Ubuntu. Il organise les services en **unités** (units) de différents types :

| Type | Extension | Description |
|------|-----------|-------------|
| Service | `.service` | Processus démon |
| Timer | `.timer` | Tâche planifiée (remplace cron) |
| Socket | `.socket` | Activation sur connexion réseau |
| Target | `.target` | Groupement d'unités (équivalent runlevel) |
| Mount | `.mount` | Point de montage |

#### Exercice 1.2.a — Exploration de systemd

```bash
# État général du système
systemctl status

# Lister toutes les unités actives
systemctl list-units --type=service --state=running

# Lister les unités en échec
systemctl list-units --state=failed

# Voir l'ordre de démarrage (dépendances)
systemctl list-dependencies multi-user.target

# Temps de démarrage de chaque service
systemd-analyze blame | head -20

# Graphe de démarrage (génère un SVG)
systemd-analyze plot > /tmp/boot.svg
```

#### Exercice 1.2.b — Création d'un service systemd personnalisé

**Objectif :** Créer un service qui expose un endpoint HTTP simple en Python.

Créer le script `/opt/monitor/healthcheck.py` :

```python
#!/usr/bin/env python3
"""Service de healthcheck HTTP minimal."""

import http.server
import json
import os
import time
from datetime import datetime

START_TIME = time.time()

class HealthHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == '/health':
            uptime = int(time.time() - START_TIME)
            data = {
                "status": "ok",
                "uptime_seconds": uptime,
                "pid": os.getpid(),
                "timestamp": datetime.utcnow().isoformat() + "Z"
            }
            body = json.dumps(data, indent=2).encode()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.send_header('Content-Length', len(body))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def log_message(self, fmt, *args):
        # Journalisation vers stdout (capturée par journald)
        print(f"[{datetime.now().strftime('%H:%M:%S')}] {fmt % args}")

if __name__ == '__main__':
    port = int(os.environ.get('HEALTHCHECK_PORT', 8080))
    server = http.server.HTTPServer(('0.0.0.0', port), HealthHandler)
    print(f"Healthcheck server démarré sur le port {port} (PID: {os.getpid()})")
    server.serve_forever()
```

```bash
# Créer les répertoires
sudo mkdir -p /opt/monitor
sudo cp ~/scripts/healthcheck.py /opt/monitor/
sudo chmod +x /opt/monitor/healthcheck.py
```

Créer l'unité systemd `/etc/systemd/system/healthcheck.service` :

```ini
[Unit]
Description=Service de healthcheck HTTP
Documentation=https://github.com/<org>/atelier-linux-m1
After=network.target
Wants=network.target

[Service]
Type=simple
User=nobody
Group=nogroup
WorkingDirectory=/opt/monitor

# Variable d'environnement
Environment=HEALTHCHECK_PORT=8080

# Commande de démarrage
ExecStart=/usr/bin/python3 /opt/monitor/healthcheck.py

# Redémarrage automatique
Restart=on-failure
RestartSec=5s
StartLimitBurst=3
StartLimitIntervalSec=30s

# Sécurité (sandboxing)
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadOnlyPaths=/opt/monitor

# Ressources
MemoryLimit=64M
CPUQuota=10%

[Install]
WantedBy=multi-user.target
```

```bash
# Recharger la configuration systemd
sudo systemctl daemon-reload

# Activer et démarrer le service
sudo systemctl enable healthcheck.service
sudo systemctl start healthcheck.service

# Vérifier le statut
sudo systemctl status healthcheck.service

# Tester l'endpoint
curl http://localhost:8080/health | python3 -m json.tool

# Consulter les logs
sudo journalctl -u healthcheck.service -f
```

#### Exercice 1.2.c — Timer systemd (remplacement de cron)

Créer `/etc/systemd/system/healthcheck-report.service` :

```ini
[Unit]
Description=Rapport périodique du healthcheck
After=healthcheck.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'curl -s http://localhost:8080/health >> /var/log/healthcheck-report.log'
```

Créer `/etc/systemd/system/healthcheck-report.timer` :

```ini
[Unit]
Description=Lance le rapport healthcheck toutes les minutes
Requires=healthcheck-report.service

[Timer]
OnBootSec=10s
OnUnitActiveSec=1min
AccuracySec=1s

[Install]
WantedBy=timers.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now healthcheck-report.timer

# Vérifier les timers actifs
systemctl list-timers

# Attendre et vérifier les logs
sleep 65 && cat /var/log/healthcheck-report.log
```

#### Exercice 1.2.d — Débogage avec journalctl

```bash
# Logs du service avec priorité (0=emerg, 7=debug)
sudo journalctl -u healthcheck.service -p err

# Logs depuis un moment précis
sudo journalctl -u healthcheck.service --since "10 minutes ago"

# Format JSON pour parsing
sudo journalctl -u healthcheck.service -o json | python3 -m json.tool | head -50

# Suivre en temps réel plusieurs unités
sudo journalctl -u healthcheck.service -u healthcheck-report.service -f

# Espace disque utilisé par les journaux
sudo journalctl --disk-usage

# Purger les journaux de plus de 7 jours
sudo journalctl --vacuum-time=7d
```

> **Checkpoint Module 1 :** Votre service healthcheck tourne, se relance automatiquement en cas d'échec, et génère un rapport toutes les minutes via le timer.

---

## Module 2 — Réseau Linux et sécurité (2h30)

### Objectifs
- Analyser et configurer le réseau Linux avec les outils modernes
- Filtrer le trafic avec iptables/nftables
- Détecter les anomalies avec tcpdump et nmap

---

### 2.1 — Diagnostic réseau avancé (45 min)

#### Les outils modernes (`iproute2`)

Les commandes historiques (`ifconfig`, `netstat`, `route`) sont obsolètes. Utiliser leur équivalent moderne :

| Ancienne commande | Nouvelle commande | Description |
|-------------------|-------------------|-------------|
| `ifconfig` | `ip addr` | Interfaces réseau |
| `route -n` | `ip route` | Table de routage |
| `netstat -tuln` | `ss -tuln` | Sockets ouverts |
| `arp -a` | `ip neigh` | Table ARP |

#### Exercice 2.1.a — Analyse des interfaces et routes

```bash
# Toutes les interfaces avec détails
ip -s addr show

# Table de routage
ip route show

# Table ARP/NDP
ip neigh show

# Sockets en écoute (TCP/UDP)
ss -tulnp

# Connexions établies avec processus associés
ss -tupn state established

# Statistiques par protocole
ss -s
```

**Questions :**
1. Quelle est l'interface réseau principale de votre Codespace ?
2. Quelle est la passerelle par défaut ?
3. Quels ports sont en écoute sur votre machine ?

#### Exercice 2.1.b — Capture de trafic avec tcpdump

```bash
# Capturer le trafic HTTP sur toutes les interfaces
sudo tcpdump -i any port 8080 -A -v

# Dans un autre terminal, générer du trafic
for i in $(seq 1 5); do curl -s http://localhost:8080/health > /dev/null; sleep 1; done

# Capturer et sauvegarder en fichier .pcap
sudo tcpdump -i any port 8080 -w /tmp/capture.pcap -c 50

# Analyser le fichier capturé
sudo tcpdump -r /tmp/capture.pcap -A | head -100

# Capturer uniquement les en-têtes TCP (SYN/SYN-ACK)
sudo tcpdump -i any 'tcp[tcpflags] & (tcp-syn|tcp-ack) != 0' -v
```

#### Exercice 2.1.c — Scan réseau avec nmap

```bash
# Scanner votre propre machine
nmap -sV localhost

# Détecter l'OS et les versions de services
nmap -A -T4 localhost

# Scanner une plage de ports précise
nmap -p 1-1024 localhost

# Script de détection de vulnérabilités courantes
nmap --script vuln localhost 2>/dev/null | head -50

# Format de sortie XML pour intégration CI
nmap -oX /tmp/scan_result.xml localhost
cat /tmp/scan_result.xml
```

---

### 2.2 — Filtrage réseau avec iptables (45 min)

#### Théorie : les chaînes netfilter

```
  PREROUTING → FORWARD → POSTROUTING
       ↓
     INPUT → (processus local) → OUTPUT
```

Les trois tables principales :
- **filter** : accepter/rejeter des paquets (INPUT, OUTPUT, FORWARD)
- **nat** : translation d'adresses (PREROUTING, POSTROUTING)
- **mangle** : modifier les paquets

#### Exercice 2.2.a — Règles iptables de base

```bash
# Afficher les règles actuelles
sudo iptables -L -n -v

# Afficher avec numéros de règles
sudo iptables -L INPUT -n -v --line-numbers

# Autoriser les connexions établies (règle fondamentale)
sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

# Autoriser le loopback
sudo iptables -A INPUT -i lo -j ACCEPT

# Autoriser SSH (port 22)
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Autoriser notre service de healthcheck
sudo iptables -A INPUT -p tcp --dport 8080 -j ACCEPT

# Limiter les connexions SSH (anti-brute-force)
sudo iptables -A INPUT -p tcp --dport 22 -m limit --limit 3/min --limit-burst 5 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 22 -j DROP

# Journaliser les paquets rejetés (avec préfixe dans syslog)
sudo iptables -A INPUT -j LOG --log-prefix "IPT_DROP: " --log-level 4

# Politique par défaut : tout rejeter
sudo iptables -P INPUT DROP

# Vérifier
sudo iptables -L INPUT -n -v --line-numbers
```

> **Attention :** Dans un Codespace, soyez prudents avec la politique DROP. Si vous vous déconnectez, vous ne pourrez peut-être plus vous reconnecter.

#### Exercice 2.2.b — Règles avancées et NAT

```bash
# Bloquer une IP spécifique
sudo iptables -I INPUT 1 -s 192.168.1.100 -j DROP

# Rediriger le port 80 vers 8080 (port forwarding local)
sudo iptables -t nat -A PREROUTING -p tcp --dport 80 -j REDIRECT --to-port 8080

# Tester la redirection
curl http://localhost:80/health

# Compteur de paquets par règle
sudo iptables -L INPUT -n -v

# Sauvegarder les règles
sudo iptables-save > /tmp/iptables_rules.v4
cat /tmp/iptables_rules.v4

# Restaurer les règles
sudo iptables-restore < /tmp/iptables_rules.v4

# Remettre à zéro (flush) toutes les règles
sudo iptables -F
sudo iptables -t nat -F
sudo iptables -P INPUT ACCEPT
```

#### Exercice 2.2.c — Mise en place d'un pare-feu complet (script)

Créer `~/scripts/firewall.sh` :

```bash
#!/bin/bash
# Pare-feu iptables pour serveur Linux
# Usage : sudo ./firewall.sh {start|stop|status}

set -euo pipefail

IPT="iptables"
ALLOWED_PORTS_TCP="22 80 443 8080"

fw_start() {
    echo "[*] Application du pare-feu..."

    # Remettre à zéro
    $IPT -F
    $IPT -X
    $IPT -t nat -F
    $IPT -t mangle -F

    # Politiques par défaut
    $IPT -P INPUT DROP
    $IPT -P FORWARD DROP
    $IPT -P OUTPUT ACCEPT

    # Loopback
    $IPT -A INPUT -i lo -j ACCEPT

    # Connexions établies
    $IPT -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

    # ICMP (ping) - limité
    $IPT -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/s -j ACCEPT

    # Ports autorisés
    for port in $ALLOWED_PORTS_TCP; do
        $IPT -A INPUT -p tcp --dport "$port" -j ACCEPT
        echo "  [+] TCP $port autorisé"
    done

    # Anti-scan SYN flood
    $IPT -A INPUT -p tcp ! --syn -m conntrack --ctstate NEW -j DROP
    $IPT -A INPUT -p tcp --syn -m limit --limit 25/s --limit-burst 50 -j ACCEPT

    # Journalisation des rejets
    $IPT -A INPUT -j LOG --log-prefix "FW_DROP: " --log-level 4
    $IPT -A INPUT -j DROP

    echo "[+] Pare-feu actif."
    $IPT -L INPUT -n -v --line-numbers
}

fw_stop() {
    echo "[*] Désactivation du pare-feu..."
    $IPT -F
    $IPT -X
    $IPT -P INPUT ACCEPT
    $IPT -P FORWARD ACCEPT
    $IPT -P OUTPUT ACCEPT
    echo "[+] Pare-feu désactivé."
}

fw_status() {
    echo "=== Règles INPUT ==="
    $IPT -L INPUT -n -v --line-numbers
    echo ""
    echo "=== Règles NAT ==="
    $IPT -t nat -L -n -v
}

case "${1:-status}" in
    start)  fw_start ;;
    stop)   fw_stop ;;
    status) fw_status ;;
    *)      echo "Usage: $0 {start|stop|status}" && exit 1 ;;
esac
```

```bash
chmod +x ~/scripts/firewall.sh
sudo ~/scripts/firewall.sh start
sudo ~/scripts/firewall.sh status
```

---

### 2.3 — Sécurité système (1h)

#### Exercice 2.3.a — Analyse des utilisateurs et permissions

```bash
# Utilisateurs avec shell valide
grep -v '/nologin\|/false' /etc/passwd

# Comptes avec UID 0 (root) non standard
awk -F: '$3 == 0 {print $1}' /etc/passwd

# Fichiers SUID/SGID (vecteurs d'élévation de privilèges)
find / -perm /6000 -type f 2>/dev/null | grep -v proc

# Fichiers world-writable
find /tmp /var /home -perm -o+w -type f 2>/dev/null

# Dernières connexions
last -n 20
lastlog | grep -v 'Never'

# Vérifier les sudoers
sudo cat /etc/sudoers
sudo ls /etc/sudoers.d/
```

#### Exercice 2.3.b — Durcissement SSH

Créer une paire de clés et configurer `sshd` de façon sécurisée.

```bash
# Générer une clé ED25519 (plus sécurisé que RSA 2048)
ssh-keygen -t ed25519 -C "atelier-linux-m1" -f ~/.ssh/atelier_ed25519 -N ""

# Inspecter la clé publique
cat ~/.ssh/atelier_ed25519.pub

# Afficher la configuration SSH actuelle
sudo cat /etc/ssh/sshd_config

# Créer une configuration durcie
sudo tee /etc/ssh/sshd_config.d/hardened.conf << 'EOF'
# Algorithmes sécurisés uniquement
KexAlgorithms curve25519-sha256,diffie-hellman-group16-sha512
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com

# Authentification
PasswordAuthentication no
PubkeyAuthentication yes
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30

# Restrictions
X11Forwarding no
AllowAgentForwarding no
PermitEmptyPasswords no
EOF

# Valider la configuration sans redémarrer
sudo sshd -t && echo "Configuration SSH valide"
```

#### Exercice 2.3.c — Audit avec auditd

```bash
# Installer auditd
sudo apt-get install -y auditd

# Démarrer le service
sudo systemctl start auditd

# Ajouter des règles d'audit
# Surveiller les modifications de /etc/passwd
sudo auditctl -w /etc/passwd -p wa -k passwd_changes

# Surveiller les appels système execve (exécution de programmes)
sudo auditctl -a always,exit -F arch=b64 -S execve -k exec_commands

# Surveiller l'accès aux clés SSH
sudo auditctl -w /home -p x -k home_exec

# Lister les règles actives
sudo auditctl -l

# Générer de l'activité
cat /etc/passwd
sudo useradd -M testuser
sudo userdel testuser

# Consulter les logs d'audit
sudo ausearch -k passwd_changes | head -40
sudo ausearch -k exec_commands -ts recent | tail -30

# Rapport de sécurité
sudo aureport --summary
sudo aureport --failed --summary
```

> **Checkpoint Module 2 :** Votre pare-feu est en place, SSH est durci, et auditd surveille les activités sensibles.

---

## Module 3 — Conteneurs Docker (3h)

### Objectifs
- Maîtriser Docker au-delà des commandes de base
- Construire des images optimisées et sécurisées
- Orchestrer des applications multi-conteneurs avec Docker Compose
- Implémenter des bonnes pratiques de sécurité

---

### 3.1 — Docker avancé : images et build (1h)

#### Exercice 3.1.a — Analyse d'images existantes

```bash
# Vérifier Docker dans le Codespace
docker version
docker info

# Inspecter une image officielle
docker pull python:3.12-slim
docker inspect python:3.12-slim | python3 -m json.tool | head -80

# Voir les couches de l'image
docker history python:3.12-slim

# Analyser la taille des couches
docker history --no-trunc --format "{{.Size}}\t{{.CreatedBy}}" python:3.12-slim

# Comparer tailles d'images
docker images | grep python
```

#### Exercice 3.1.b — Dockerfile multi-stage optimisé

**Objectif :** Containeriser le service healthcheck du Module 1 avec une image minimale et sécurisée.

Créer `~/docker/healthcheck/Dockerfile` :

```dockerfile
# ═══════════════════════════════════════════════════
# STAGE 1 : Builder — installation des dépendances
# ═══════════════════════════════════════════════════
FROM python:3.12-slim AS builder

WORKDIR /build

# Copier et installer les dépendances dans un venv isolé
COPY requirements.txt .
RUN python -m venv /opt/venv && \
    /opt/venv/bin/pip install --no-cache-dir --upgrade pip && \
    /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

# ═══════════════════════════════════════════════════
# STAGE 2 : Runtime — image finale minimale
# ═══════════════════════════════════════════════════
FROM python:3.12-slim AS runtime

# Métadonnées OCI
LABEL org.opencontainers.image.title="Healthcheck Service"
LABEL org.opencontainers.image.version="1.0.0"
LABEL org.opencontainers.image.description="Service HTTP de healthcheck"

# Utilisateur non-root (bonne pratique sécurité)
RUN groupadd --gid 10001 appgroup && \
    useradd --uid 10001 --gid appgroup --shell /bin/false --no-create-home appuser

# Copier le venv du builder
COPY --from=builder /opt/venv /opt/venv

# Copier le code applicatif
WORKDIR /app
COPY --chown=appuser:appgroup healthcheck.py .

# Basculer vers l'utilisateur non-root
USER appuser

# Variables d'environnement
ENV PATH="/opt/venv/bin:$PATH" \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    HEALTHCHECK_PORT=8080

# Port exposé (documentation)
EXPOSE 8080

# Healthcheck Docker natif
HEALTHCHECK --interval=15s --timeout=5s --start-period=10s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"

# Point d'entrée
CMD ["python", "healthcheck.py"]
```

Créer `~/docker/healthcheck/requirements.txt` :

```
# Pas de dépendances externes pour ce service minimal
# (utilise uniquement la stdlib Python)
```

```bash
mkdir -p ~/docker/healthcheck
cp /opt/monitor/healthcheck.py ~/docker/healthcheck/
cd ~/docker/healthcheck

# Construire l'image
docker build -t healthcheck:v1.0 .

# Inspecter l'image construite
docker inspect healthcheck:v1.0

# Comparer avec l'image complète
docker images | grep -E "python|healthcheck"

# Lancer le conteneur
docker run -d --name healthcheck-app \
    -p 8081:8080 \
    --memory=64m \
    --cpus=0.5 \
    healthcheck:v1.0

# Tester
curl http://localhost:8081/health | python3 -m json.tool

# Logs du conteneur
docker logs -f healthcheck-app
```

#### Exercice 3.1.c — Sécurité des images

```bash
# Analyser les vulnérabilités avec Docker Scout (ou Trivy)
# Installer Trivy
curl -sfL https://raw.githubusercontent.com/aquasecurity/trivy/main/contrib/install.sh | sh -s -- -b /usr/local/bin

# Scanner notre image
trivy image healthcheck:v1.0

# Scanner l'image de base
trivy image python:3.12-slim

# Comparer : image distroless (encore plus minimale)
# Modifier le Dockerfile pour utiliser distroless
cat << 'EOF' > ~/docker/healthcheck/Dockerfile.distroless
FROM python:3.12-slim AS builder
WORKDIR /build
RUN python -m venv /opt/venv && /opt/venv/bin/pip install --no-cache-dir --upgrade pip
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM gcr.io/distroless/python3-debian12 AS runtime
COPY --from=builder /opt/venv /opt/venv
COPY healthcheck.py /app/healthcheck.py
WORKDIR /app
ENV PATH="/opt/venv/bin:$PATH"
EXPOSE 8080
CMD ["/app/healthcheck.py"]
EOF

docker build -f Dockerfile.distroless -t healthcheck:distroless .
docker images | grep healthcheck
trivy image healthcheck:distroless
```

---

### 3.2 — Docker Compose et architecture multi-services (1h)

#### Exercice 3.2.a — Stack monitoring complète

**Architecture cible :**

```
┌─────────────────────────────────────────────────────┐
│                   Docker Network                     │
│                                                      │
│  ┌──────────┐   ┌───────────┐   ┌────────────────┐  │
│  │Healthcheck│   │ Prometheus │   │    Grafana     │  │
│  │  :8080   │──▶│  :9090    │──▶│    :3000       │  │
│  └──────────┘   └───────────┘   └────────────────┘  │
│                       │                              │
│                 ┌─────▼──────┐                       │
│                 │  Alertmanager                       │
│                 │  :9093     │                       │
│                 └────────────┘                       │
└─────────────────────────────────────────────────────┘
```

Créer `~/docker/monitoring/docker-compose.yml` :

```yaml
version: '3.9'

networks:
  monitoring:
    driver: bridge
    ipam:
      config:
        - subnet: 172.20.0.0/24

volumes:
  prometheus_data:
  grafana_data:

services:

  # ─── Service applicatif ───────────────────────────────────
  healthcheck:
    build:
      context: ../healthcheck
      dockerfile: Dockerfile
    image: healthcheck:v1.0
    container_name: healthcheck-app
    networks:
      - monitoring
    ports:
      - "8080:8080"
    environment:
      - HEALTHCHECK_PORT=8080
    restart: unless-stopped
    healthcheck:
      test: ["CMD", "python3", "-c",
             "import urllib.request; urllib.request.urlopen('http://localhost:8080/health')"]
      interval: 15s
      timeout: 5s
      retries: 3
    mem_limit: 64m
    cpus: 0.5
    labels:
      - "prometheus.scrape=true"
      - "prometheus.port=8080"

  # ─── Prometheus ──────────────────────────────────────────
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    networks:
      - monitoring
    ports:
      - "9090:9090"
    volumes:
      - prometheus_data:/prometheus
      - ./prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ./prometheus/alerts.yml:/etc/prometheus/alerts.yml:ro
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=7d'
      - '--web.enable-lifecycle'
    restart: unless-stopped
    depends_on:
      - healthcheck

  # ─── Grafana ─────────────────────────────────────────────
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    networks:
      - monitoring
    ports:
      - "3000:3000"
    volumes:
      - grafana_data:/var/lib/grafana
      - ./grafana/datasources.yml:/etc/grafana/provisioning/datasources/ds.yml:ro
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=atelier2024
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_AUTH_ANONYMOUS_ENABLED=false
    restart: unless-stopped
    depends_on:
      - prometheus
```

Créer `~/docker/monitoring/prometheus/prometheus.yml` :

```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []

rule_files:
  - "alerts.yml"

scrape_configs:
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  - job_name: 'healthcheck'
    static_configs:
      - targets: ['healthcheck:8080']
    metrics_path: '/health'
```

Créer `~/docker/monitoring/prometheus/alerts.yml` :

```yaml
groups:
  - name: healthcheck_alerts
    rules:
      - alert: ServiceDown
        expr: up{job="healthcheck"} == 0
        for: 30s
        labels:
          severity: critical
        annotations:
          summary: "Service healthcheck est DOWN"
          description: "Le service healthcheck ne répond plus depuis 30s."
```

Créer `~/docker/monitoring/grafana/datasources.yml` :

```yaml
apiVersion: 1
datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false
```

```bash
mkdir -p ~/docker/monitoring/prometheus ~/docker/monitoring/grafana
cd ~/docker/monitoring

# Démarrer la stack
docker compose up -d

# Suivre les logs
docker compose logs -f

# État des conteneurs
docker compose ps

# Vérifier les healthchecks
docker inspect healthcheck-app | python3 -m json.tool | grep -A5 "Health"
```

#### Exercice 3.2.b — Opérations sur la stack

```bash
# Scaler un service
docker compose up -d --scale healthcheck=3

# Mettre à jour une image sans downtime
docker compose pull prometheus
docker compose up -d --no-deps prometheus

# Inspecter le réseau
docker network inspect monitoring_monitoring

# Voir les ressources consommées
docker stats --no-stream

# Arrêter sans supprimer les volumes
docker compose stop

# Supprimer tout (y compris les volumes)
docker compose down -v
```

---

### 3.3 — Sécurité Docker et bonnes pratiques (1h)

#### Exercice 3.3.a — Isolation et capabilities

```bash
# Voir les capabilities d'un conteneur par défaut
docker run --rm alpine sh -c "cat /proc/1/status | grep CapEff"

# Lancer sans aucune capability (puis ajouter seulement ce qui est nécessaire)
docker run --rm --cap-drop ALL alpine sh -c "cat /proc/1/status | grep CapEff"

# Ajouter seulement NET_BIND_SERVICE (pour écouter sur ports < 1024)
docker run --rm --cap-drop ALL --cap-add NET_BIND_SERVICE alpine sh -c \
    "cat /proc/1/status | grep CapEff"

# Profil seccomp personnalisé (bloquer les appels système dangereux)
cat << 'EOF' > /tmp/seccomp-strict.json
{
  "defaultAction": "SCMP_ACT_ERRNO",
  "architectures": ["SCMP_ARCH_X86_64"],
  "syscalls": [
    {
      "names": ["read", "write", "open", "close", "stat", "fstat", "mmap",
                "mprotect", "munmap", "brk", "exit", "exit_group", "futex",
                "getpid", "gettimeofday", "clock_gettime", "nanosleep",
                "accept", "accept4", "bind", "connect", "listen", "socket",
                "setsockopt", "getsockopt", "sendto", "recvfrom", "getpeername"],
      "action": "SCMP_ACT_ALLOW"
    }
  ]
}
EOF

# Lancer avec le profil seccomp strict
docker run --rm --security-opt seccomp=/tmp/seccomp-strict.json \
    --security-opt no-new-privileges \
    --read-only \
    --tmpfs /tmp \
    healthcheck:v1.0
```

#### Exercice 3.3.b — Gestion des secrets

```bash
# Mauvaise pratique : passer un secret en variable d'environnement
docker run -e DB_PASSWORD="secret123" alpine env | grep DB_PASSWORD

# Meilleure pratique : utiliser Docker secrets (avec Swarm ou fichier)
echo "mot_de_passe_super_secret" | docker secret create db_password - 2>/dev/null \
    || echo "Swarm non initialisé, utilisation de fichier"

# Alternative : monter un fichier secret en lecture seule
echo "mot_de_passe_super_secret" > /tmp/db_password.txt
chmod 600 /tmp/db_password.txt

docker run --rm \
    -v /tmp/db_password.txt:/run/secrets/db_password:ro \
    alpine sh -c "cat /run/secrets/db_password && ls -la /run/secrets/"

# Dans le code, lire depuis le fichier plutôt que l'env
cat << 'EOF' > /tmp/read_secret.py
import os

def get_secret(name):
    """Lire un secret depuis /run/secrets/ ou l'environnement."""
    secret_path = f"/run/secrets/{name}"
    if os.path.exists(secret_path):
        with open(secret_path) as f:
            return f.read().strip()
    return os.environ.get(name.upper())

db_password = get_secret("db_password")
print(f"Secret récupéré : {db_password[:3]}***")
EOF

docker run --rm \
    -v /tmp/db_password.txt:/run/secrets/db_password:ro \
    -v /tmp/read_secret.py:/app/read_secret.py:ro \
    python:3.12-slim python /app/read_secret.py
```

#### Exercice 3.3.c — Analyse de sécurité avec Trivy et Docker Bench

```bash
# Scan de l'image
trivy image --severity HIGH,CRITICAL healthcheck:v1.0

# Scan du système hôte Docker
trivy host

# Docker Bench for Security (audit des configurations)
docker run --rm \
    -v /var/lib:/var/lib:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /etc:/etc:ro \
    --pid host \
    --net host \
    --cap-add audit_control \
    docker/docker-bench-security 2>/dev/null | head -80
```

> **Checkpoint Module 3 :** Votre stack monitoring est déployée, les conteneurs tournent avec les permissions minimales, et les secrets ne sont pas exposés dans les variables d'environnement.

---

## Module 4 — Projet intégrateur (1h30)

### Objectifs
Assembler l'ensemble des compétences des modules précédents dans un projet cohérent et fonctionnel.

---

### Énoncé du projet

**Contexte :** Vous êtes ingénieur système dans une startup. On vous demande de mettre en place une infrastructure de déploiement d'une application web simple, avec supervision, sécurité et haute disponibilité basique.

**Livrable :** Un script `deploy.sh` qui :

1. **Prépare l'environnement** : vérifie les prérequis, crée les répertoires nécessaires
2. **Déploie la stack Docker** : application + monitoring
3. **Configure le pare-feu** : applique les règles iptables appropriées
4. **Crée un service systemd** : assure le redémarrage automatique de Docker Compose au boot
5. **Met en place la supervision** : crée un timer systemd qui vérifie toutes les minutes que tous les conteneurs sont healthy, et envoie une alerte si ce n'est pas le cas
6. **Génère un rapport** : produit un fichier `infrastructure_report.txt` avec l'état de tous les composants

---

### Guide de réalisation

#### Étape 1 — Script de déploiement principal

```bash
#!/bin/bash
# deploy.sh — Script de déploiement intégrateur
# Atelier Linux M1 — Module 4

set -euo pipefail

LOG_FILE="/var/log/deploy.log"
REPORT_FILE="$HOME/infrastructure_report.txt"
COMPOSE_DIR="$HOME/docker/monitoring"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"; }
err() { log "ERREUR: $*"; exit 1; }
ok()  { log "OK: $*"; }

# ─── Prérequis ───────────────────────────────────────────────────────────────
check_prerequisites() {
    log "Vérification des prérequis..."
    local missing=()
    for cmd in docker docker-compose curl nmap iptables systemctl; do
        command -v "$cmd" &>/dev/null || missing+=("$cmd")
    done
    [[ ${#missing[@]} -gt 0 ]] && err "Outils manquants : ${missing[*]}"
    ok "Tous les prérequis sont satisfaits"
}

# ─── Déploiement Docker ──────────────────────────────────────────────────────
deploy_stack() {
    log "Déploiement de la stack Docker..."
    cd "$COMPOSE_DIR"
    docker compose down --remove-orphans 2>/dev/null || true
    docker compose up -d --build
    
    # Attendre que les conteneurs soient healthy
    local timeout=60
    local elapsed=0
    while [[ $elapsed -lt $timeout ]]; do
        local unhealthy
        unhealthy=$(docker compose ps --format json 2>/dev/null | \
            python3 -c "
import sys, json
data = [json.loads(l) for l in sys.stdin if l.strip()]
print(len([s for s in data if s.get('Health','') not in ('healthy','')]))
" 2>/dev/null || echo "0")
        [[ "$unhealthy" == "0" ]] && { ok "Stack déployée et healthy"; return 0; }
        sleep 5
        elapsed=$((elapsed + 5))
        log "Attente des conteneurs... ($elapsed/$timeout s)"
    done
    err "Timeout : certains conteneurs ne sont pas healthy"
}

# ─── Pare-feu ────────────────────────────────────────────────────────────────
configure_firewall() {
    log "Configuration du pare-feu..."
    sudo iptables -F && sudo iptables -X
    sudo iptables -P INPUT DROP
    sudo iptables -P FORWARD DROP
    sudo iptables -P OUTPUT ACCEPT
    sudo iptables -A INPUT -i lo -j ACCEPT
    sudo iptables -A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    for port in 22 8080 3000 9090; do
        sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT
    done
    sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 2/s -j ACCEPT
    ok "Pare-feu configuré"
}

# ─── Service systemd ─────────────────────────────────────────────────────────
create_systemd_service() {
    log "Création du service systemd..."
    sudo tee /etc/systemd/system/monitoring-stack.service > /dev/null << EOF
[Unit]
Description=Stack de monitoring Docker Compose
After=docker.service
Requires=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=${COMPOSE_DIR}
ExecStart=/usr/bin/docker compose up -d
ExecStop=/usr/bin/docker compose down
TimeoutStartSec=120

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable monitoring-stack.service
    ok "Service systemd créé et activé"
}

# ─── Supervision par timer ───────────────────────────────────────────────────
create_healthwatch() {
    log "Mise en place de la supervision..."
    sudo tee /usr/local/bin/healthwatch.sh > /dev/null << 'SCRIPT'
#!/bin/bash
REPORT="/tmp/healthwatch_$(date +%Y%m%d_%H%M%S).txt"
FAILED=0

check_container() {
    local name=$1
    local status
    status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "absent")
    echo "[$name] : $status" >> "$REPORT"
    [[ "$status" != "healthy" ]] && FAILED=$((FAILED+1))
}

for container in healthcheck-app prometheus grafana; do
    check_container "$container"
done

if [[ $FAILED -gt 0 ]]; then
    logger -t healthwatch -p user.crit "ALERTE: $FAILED conteneur(s) non-healthy"
    cat "$REPORT"
fi
SCRIPT
    sudo chmod +x /usr/local/bin/healthwatch.sh

    sudo tee /etc/systemd/system/healthwatch.service > /dev/null << 'EOF'
[Unit]
Description=Vérification de santé des conteneurs
[Service]
Type=oneshot
ExecStart=/usr/local/bin/healthwatch.sh
EOF

    sudo tee /etc/systemd/system/healthwatch.timer > /dev/null << 'EOF'
[Unit]
Description=Timer healthwatch — toutes les minutes
[Timer]
OnBootSec=30s
OnUnitActiveSec=1min
[Install]
WantedBy=timers.target
EOF

    sudo systemctl daemon-reload
    sudo systemctl enable --now healthwatch.timer
    ok "Timer de supervision actif"
}

# ─── Rapport final ───────────────────────────────────────────────────────────
generate_report() {
    log "Génération du rapport..."
    {
        echo "═══════════════════════════════════════════════"
        echo "  RAPPORT D'INFRASTRUCTURE — $(date)"
        echo "═══════════════════════════════════════════════"
        echo ""
        echo "── Système ────────────────────────────────────"
        uname -a
        echo ""
        echo "── Conteneurs ─────────────────────────────────"
        docker compose -f "$COMPOSE_DIR/docker-compose.yml" ps
        echo ""
        echo "── Ports en écoute ────────────────────────────"
        ss -tulnp | grep -E '8080|9090|3000'
        echo ""
        echo "── Services systemd ───────────────────────────"
        systemctl is-active monitoring-stack healthwatch.timer healthcheck 2>/dev/null
        echo ""
        echo "── Pare-feu (INPUT) ───────────────────────────"
        sudo iptables -L INPUT -n --line-numbers
        echo ""
        echo "── URLs d'accès ───────────────────────────────"
        echo "  Healthcheck : http://localhost:8080/health"
        echo "  Prometheus  : http://localhost:9090"
        echo "  Grafana     : http://localhost:3000 (admin/atelier2024)"
    } > "$REPORT_FILE"
    ok "Rapport généré : $REPORT_FILE"
    cat "$REPORT_FILE"
}

# ─── Main ────────────────────────────────────────────────────────────────────
main() {
    log "=== Démarrage du déploiement ==="
    check_prerequisites
    deploy_stack
    configure_firewall
    create_systemd_service
    create_healthwatch
    generate_report
    log "=== Déploiement terminé avec succès ==="
}

main "$@"
```

#### Étape 2 — Exécution et validation

```bash
chmod +x ~/deploy.sh
sudo ~/deploy.sh

# Vérifications finales
curl http://localhost:8080/health
curl http://localhost:9090/-/ready
systemctl list-timers | grep health
sudo iptables -L INPUT -n --line-numbers
cat ~/infrastructure_report.txt
```

#### Critères de validation

| Critère | Commande de vérification | Résultat attendu |
|---------|--------------------------|------------------|
| Service healthcheck actif | `curl http://localhost:8080/health` | JSON avec `"status": "ok"` |
| Prometheus opérationnel | `curl http://localhost:9090/-/ready` | HTTP 200 |
| Grafana accessible | `curl http://localhost:3000/api/health` | JSON `{"database": "ok"}` |
| Pare-feu actif | `sudo iptables -L INPUT -n` | Politique DROP, règles présentes |
| Service systemd activé | `systemctl is-enabled monitoring-stack` | `enabled` |
| Timer actif | `systemctl is-active healthwatch.timer` | `active` |
| Journalisation | `sudo journalctl -u healthcheck -n 10` | Logs présents |

---

## Récapitulatif et ressources

### Ce que vous avez mis en place

```
┌─────────────────────────────────────────────────────────────────┐
│                     Infrastructure finale                        │
│                                                                  │
│  systemd                                                         │
│  ├── healthcheck.service  (API Python)                           │
│  ├── monitoring-stack.service  (démarre Docker Compose au boot)  │
│  └── healthwatch.timer  (vérifie les conteneurs/minute)          │
│                                                                  │
│  Docker                                                          │
│  ├── healthcheck-app  (port 8080)                                │
│  ├── prometheus        (port 9090)                               │
│  └── grafana           (port 3000)                               │
│                                                                  │
│  Réseau                                                          │
│  ├── iptables  (pare-feu, ports 22/8080/9090/3000)               │
│  ├── auditd    (surveillance des accès sensibles)                │
│  └── SSH       (clés ED25519, configuration durcie)              │
└─────────────────────────────────────────────────────────────────┘
```

### Pour aller plus loin

**systemd**
- [systemd.io — Documentation officielle](https://systemd.io)
- `man systemd.service`, `man systemd.timer`, `man journalctl`

**Réseau et sécurité**
- [nftables wiki](https://wiki.nftables.org) — Le successeur d'iptables
- [Linux Security Hardening Checklist](https://github.com/trimstray/the-practical-linux-hardening-guide)

**Docker**
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Trivy — Scanner de vulnérabilités](https://trivy.dev)

**Outils complémentaires**
- `falco` — Détection d'anomalies runtime dans les conteneurs
- `lynis` — Audit de sécurité Linux complet
- `sysdig` — Surveillance avancée des appels système

---

*Atelier Linux Avancé — M1 Informatique — GitHub Codespaces*  
*Durée : 10h | Niveau : Confirmé*
