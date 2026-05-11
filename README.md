# Atelier Linux Avancé
### M2 Informatique · GitHub Codespaces · Internals · Réseau · Observabilité · Conteneurs

---

> **Public cible :** Étudiants M2 Informatique, niveau Linux confirmé
> **Durée totale :** 25 heures (semestre complet, ~8 séances de 3 h)
> **Environnement :** GitHub Codespaces (Ubuntu 22.04 LTS)
> **Prérequis :** Compte GitHub, shell intermédiaire, notions de C/Python, lecture des pages `man`

---

## Mode d'emploi

Cet atelier est **interactif** : à chaque exercice vous trouverez un bloc de la forme

```text
Votre commande :


Votre résultat :


Interprétation :

```

à compléter **directement dans ce README**. Le rendu final fait office de **rapport de TP** noté.

1. **Forkez** ce dépôt sur votre compte GitHub.
2. Travaillez dans votre fork ; **commitez régulièrement** (au moins un commit par exercice).
3. À la fin du semestre, déposez l'URL de votre fork sur la plateforme de rendu.

> **Conseil :** soignez les blocs `Interprétation` — la note repose en grande partie sur votre compréhension, pas seulement sur la justesse de la commande.

---

## Sommaire

| Module | Thème | Durée |
|--------|-------|-------|
| 0 | Mise en place de l'environnement Codespaces | 30 min |
| 1 | Processus, signaux et systemd | 3 h |
| 2 | Internals : namespaces, cgroups v2, /proc, capabilities | 3 h 30 |
| 3 | Réseau Linux : diagnostic, iptables, durcissement | 3 h |
| 4 | Réseau avancé : nftables, network namespaces, eBPF/XDP | 2 h 30 |
| 5 | Observabilité : strace, perf, bpftrace | 2 h 30 |
| 6 | Conteneurs Docker : images, Compose, sécurité | 3 h |
| 7 | Conteneurs avancés : rootless, Podman, Kubernetes, supply chain | 3 h |
| 8 | Projet intégrateur étendu | 2 h |
| | **Total** | **25 h** |

### Barème indicatif

| Critère | Poids |
|---------|-------|
| Complétude des blocs réponse | 30 % |
| Qualité des interprétations | 35 % |
| Projet intégrateur fonctionnel | 25 % |
| Hygiène git (commits, messages) | 10 % |

---

## Module 0 — Mise en place de l'environnement (30 min)

### Objectifs
- Créer et configurer un Codespace depuis un dépôt GitHub
- Comprendre la structure de l'environnement de travail
- Vérifier les outils disponibles

### 0.1 — Création du Codespace

1. Forker le dépôt de cet atelier
2. Cliquer sur **Code → Codespaces → Create codespace on main**
3. Attendre l'initialisation (environ 2 minutes)

Le dépôt contient un fichier `.devcontainer/devcontainer.json` préconfiguré :

```json
{
  "name": "Atelier Linux M2",
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

# Empreinte matérielle et noyau
uname -a
nproc
free -h
cat /proc/cmdline
```

**Résultat attendu :** Tous les outils sont présents, `sudo whoami` retourne `root`.

#### Question 0.2.a — Identifier la version exacte du noyau et son origine (vanille, Azure, GKE…).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 0.2.b — Combien de vCPUs et combien de RAM le Codespace expose-t-il ? D'où vient cette information (`/proc/cpuinfo`, `lscpu`, cgroup) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 0.2.c — Inspecter `/proc/1/cgroup` et `/proc/1/status`. Le PID 1 du Codespace est-il vraiment `systemd` ? Pourquoi ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

### 0.3 — Première trace dans le dépôt

Avant d'aller plus loin, créez un répertoire `livrables/` à la racine du fork. Vous y déposerez les fichiers produits durant l'atelier (scripts, captures, rapports). Commitez ce répertoire vide avec un fichier `.gitkeep`.

```bash
mkdir -p livrables
touch livrables/.gitkeep
git add livrables/.gitkeep
git commit -m "chore: init livrables/"
```

#### Question 0.3 — Vérifier l'historique avec `git log --oneline -5`. Copier la sortie ci-dessous.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

## Module 1 — Processus, signaux et systemd (3 h)

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

#### Question 1.1.a.1 — Quel est le PID de votre shell courant (`echo $$`) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.a.2 — Quel processus est le parent de votre shell (utilisez `ps -o pid,ppid,comm -p $$` puis remontez la chaîne) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.a.3 — Combien de threads le processus PID 1 utilise-t-il ? (Astuce : `/proc/1/status` champ `Threads`, ou `ps -L`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.a.4 — Trouver le top 3 des processus consommant le plus de mémoire **résidente** (RSS), pas virtuelle.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.a.5 — Lire `/proc/$$/limits`. Quelle est la limite molle de `nofile` (max fichiers ouverts) pour votre shell ? La modifier temporairement à 2048 avec `ulimit -n`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

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

#### Question 1.1.b.1 — Que retourne `ps -o pid,stat,comm -p $PID_SLEEP` quand le processus est en SIGSTOP, puis après SIGCONT ? Recopier les deux sorties.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.b.2 — Lancez un `sleep 60`, suspendez-le avec Ctrl+Z, mettez-le en background avec `bg`, puis ramenez-le en foreground avec `fg`. Expliquer ce qui se passe en termes de signaux.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.b.3 — Pourquoi SIGKILL et SIGSTOP ne peuvent-ils pas être interceptés ? Lire `man 7 signal` et citer le passage pertinent.

```text
Votre résultat :


Interprétation :

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

#### Question 1.1.c.1 — Recopier la sortie complète d'une exécution (démarrage → SIGHUP → SIGTERM).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.c.2 — Modifier le script pour qu'un SIGUSR1 affiche les statistiques courantes (uptime + nombre d'itérations) sans interrompre la boucle. Joindre le patch.

```text
Patch (sortie de git diff) :


Interprétation :

```

#### Question 1.1.c.3 — Que se passe-t-il si le `trap` est défini *après* le démarrage de la boucle infinie ? Tester et expliquer.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 1.1.d — Priorités, nice et ionice

```bash
# Lancer un processus CPU-bound avec une priorité plus basse
nice -n 19 yes > /dev/null &
PID_LOW=$!

# Lancer un autre processus avec priorité par défaut
yes > /dev/null &
PID_DEFAULT=$!

# Observer la répartition CPU
top -p $PID_LOW,$PID_DEFAULT -d 1

# Modifier la priorité d'un processus en cours
sudo renice -n -5 -p $PID_DEFAULT

# Priorité I/O
ionice -c 3 -p $PID_LOW   # idle class

# Nettoyer
kill $PID_LOW $PID_DEFAULT
```

#### Question 1.1.d.1 — Quel pourcentage CPU obtient le processus `nice 19` par rapport au processus par défaut sur 30 secondes ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.1.d.2 — Quelle est la plage valide de `nice` ? Et celle de `renice` accessible à un utilisateur non-root ? (Tester en augmentant puis en abaissant la valeur de nice.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 1.2 — systemd en profondeur (1h45)

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

#### Question 1.2.a.1 — Lister les 5 services les plus lents au démarrage. Pourquoi ce classement n'est-il pas fiable dans un Codespace ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.a.2 — Combien d'unités sont chargées en mémoire au total ? Combien sont en état `failed` ? (Astuce : `systemctl list-units --all --no-legend | wc -l`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.a.3 — Quelle est la cible (`target`) actuelle du système ? Quelle est la cible par défaut au boot ?

```text
Votre commande :


Votre résultat :


Interprétation :

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
Documentation=https://github.com/<org>/atelier-linux-m2
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

#### Question 1.2.b.1 — Que retourne `systemctl show healthcheck.service --property=MemoryCurrent,CPUUsageNSec,MainPID` pendant que le service tourne ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.b.2 — Tuer brutalement le processus avec `kill -9 <MainPID>` puis attendre 10 s. Recopier la sortie de `journalctl -u healthcheck.service -n 20`. Combien de fois s'est-il relancé avant blocage `StartLimit` ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.b.3 — Tenter d'écrire dans `/opt/monitor/test.txt` depuis le service (modifier `ExecStart`). Pourquoi cela échoue-t-il malgré que `nobody` aurait techniquement la permission ? Lier la réponse à `ProtectSystem=strict` et `ReadOnlyPaths`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.b.4 — Lister toutes les options de durcissement encore disponibles avec `systemd-analyze security healthcheck.service`. Quel score obtenez-vous ? Améliorer jusqu'à passer sous 5.0.

```text
Votre commande :


Votre résultat :


Score initial / final :


Interprétation :

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

#### Question 1.2.c.1 — Quel est l'avantage d'un timer systemd par rapport à `cron` pour ce cas ? Citez au moins 3 différences techniques (journalisation, dépendances, persistance).

```text
Votre résultat :


Interprétation :

```

#### Question 1.2.c.2 — Convertir le timer en mode `OnCalendar` pour qu'il s'exécute à HH:00, HH:15, HH:30, HH:45 (toutes les 15 min sur l'horloge). Joindre l'unit modifiée.

```text
Contenu du .timer modifié :


Sortie de `systemctl list-timers` :


Interprétation :

```

#### Question 1.2.c.3 — Tester `Persistent=true`. Que fait cette option ? Dans quel cas est-elle utile ?

```text
Votre résultat :


Interprétation :

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

#### Question 1.2.d.1 — Le journal est-il persistant après redémarrage du Codespace ? Vérifier la configuration dans `/etc/systemd/journald.conf` (champ `Storage=`).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.d.2 — Émettre un message de priorité `warning` depuis votre shell avec `logger`. Le retrouver via `journalctl` filtré par priorité. Joindre les deux commandes.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 1.2.d.3 — Quel est le format binaire utilisé par `systemd-journald` ? Pourquoi pas du texte plat ? Citer 2 avantages.

```text
Votre résultat :


Interprétation :

```

### 1.3 — Socket activation (bonus, 30 min)

systemd peut démarrer un service uniquement quand quelqu'un se connecte au port — économie de ressources et activation paresseuse.

Créer `/etc/systemd/system/healthcheck.socket` :

```ini
[Unit]
Description=Socket d'activation healthcheck

[Socket]
ListenStream=8090
Accept=no

[Install]
WantedBy=sockets.target
```

Adapter le service pour utiliser le socket reçu de systemd (variable `LISTEN_FDS`).

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now healthcheck.socket
ss -tlnp | grep 8090
curl http://localhost:8090/health    # démarre le service à la demande
```

#### Question 1.3 — Vérifier avec `systemctl status healthcheck.service` que le service est passé de `inactive` à `active` lors du premier `curl`. Joindre les deux statuts.

```text
Statut avant curl :


Statut après curl :


Interprétation :

```

> **Checkpoint Module 1 :** Votre service healthcheck tourne, se relance automatiquement en cas d'échec, génère un rapport toutes les minutes, et peut être activé à la demande via socket.

---

## Module 2 — Internals Linux : namespaces, cgroups, /proc (3 h 30)

### Objectifs
- Comprendre les briques kernel qui rendent les conteneurs possibles
- Manipuler manuellement namespaces et cgroups v2 (sans Docker)
- Lire `/proc` et `/sys` comme un humain lit un journal
- Maîtriser les capabilities POSIX et l'isolation via AppArmor

---

### 2.1 — Les 7 namespaces Linux (1 h)

Un *namespace* est une vue cloisonnée d'une ressource kernel. Linux en propose 7 :

| Namespace | Ressource isolée | Flag clone |
|-----------|------------------|------------|
| `mnt` | Points de montage | `CLONE_NEWNS` |
| `pid` | Arbre des PID | `CLONE_NEWPID` |
| `net` | Interfaces, routes, ports | `CLONE_NEWNET` |
| `ipc` | SysV IPC, files de messages | `CLONE_NEWIPC` |
| `uts` | Hostname, domaine | `CLONE_NEWUTS` |
| `user` | UID/GID mapping | `CLONE_NEWUSER` |
| `cgroup` | Vue du cgroup courant | `CLONE_NEWCGROUP` |

#### Exercice 2.1.a — Explorer ses propres namespaces

```bash
# Lister les namespaces du shell courant
ls -l /proc/$$/ns/

# Comparer avec ceux du PID 1
ls -l /proc/1/ns/

# Format : 'type:[inode]'. Même inode = même namespace.
readlink /proc/$$/ns/pid
readlink /proc/1/ns/pid
```

#### Question 2.1.a.1 — Votre shell partage-t-il les mêmes namespaces que PID 1 ? Quels sont les éventuels écarts ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 2.1.b — Créer un UTS namespace isolé

```bash
# Lancer un shell dans un nouveau namespace UTS
sudo unshare --uts bash

# Dans le nouveau shell : modifier le hostname
hostname conteneur-test
hostname

# Dans un AUTRE terminal hors namespace : vérifier
hostname

# Sortir
exit
```

#### Question 2.1.b — Pourquoi le `hostname` reste-t-il inchangé hors du namespace ? Que se passerait-il sans `unshare` ?

```text
Votre résultat :


Interprétation :

```

#### Exercice 2.1.c — PID namespace : créer son propre PID 1

```bash
# Nouveau PID namespace (fork-init + montage de /proc)
sudo unshare --pid --fork --mount-proc bash

# Dans le shell isolé
ps aux         # vous ne voyez que les processus du namespace
echo $$        # devrait être 1 ou 2
sleep 100 &
ps -ef

# Depuis un autre terminal hors namespace : retrouver le sleep
ps -ef | grep sleep   # son PID "réel" est très différent

exit
```

#### Question 2.1.c.1 — Quel est le PID du `sleep` à l'intérieur du namespace ? Quel est son PID vu de l'hôte ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.1.c.2 — Que se passe-t-il si on tue le processus *PID 1* du namespace depuis l'hôte ? Tester.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 2.1.d — Network namespace : routeur en miniature

```bash
# Créer deux namespaces
sudo ip netns add ns1
sudo ip netns add ns2

# Créer une paire veth (câble virtuel)
sudo ip link add veth1 type veth peer name veth2

# Placer chaque extrémité dans un namespace
sudo ip link set veth1 netns ns1
sudo ip link set veth2 netns ns2

# Configurer les IP
sudo ip -n ns1 addr add 10.10.0.1/24 dev veth1
sudo ip -n ns2 addr add 10.10.0.2/24 dev veth2

# Activer les interfaces
sudo ip -n ns1 link set veth1 up
sudo ip -n ns2 link set veth2 up
sudo ip -n ns1 link set lo up
sudo ip -n ns2 link set lo up

# Tester
sudo ip netns exec ns1 ping -c 3 10.10.0.2
```

#### Question 2.1.d.1 — Recopier la sortie du ping. Quelle est la latence ? Pourquoi est-elle de cet ordre ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.1.d.2 — Depuis `ns1`, peut-on joindre Internet (`ping 1.1.1.1`) ? Pourquoi ? Que faudrait-il ajouter pour y arriver (sans le faire) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.1.d.3 — Nettoyer : supprimer les deux namespaces. Vérifier avec `ip netns list` et `ip link`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 2.2 — Cgroups v2 (1 h)

Les *control groups* limitent et comptabilisent les ressources (CPU, mémoire, I/O) consommées par un groupe de processus. Ubuntu 22.04 utilise cgroups **v2** (hiérarchie unifiée).

```bash
# Vérifier le mode cgroup
mount | grep cgroup
stat -fc %T /sys/fs/cgroup/
# Doit retourner 'cgroup2fs'

# Hiérarchie
ls /sys/fs/cgroup/
cat /sys/fs/cgroup/cgroup.controllers
```

#### Exercice 2.2.a — Créer un cgroup et limiter la mémoire

```bash
# Créer un cgroup délégable pour l'utilisateur courant
sudo mkdir -p /sys/fs/cgroup/atelier
echo "+memory +cpu +io" | sudo tee /sys/fs/cgroup/cgroup.subtree_control

# Définir une limite mémoire de 32 Mo
echo $((32 * 1024 * 1024)) | sudo tee /sys/fs/cgroup/atelier/memory.max

# Lancer un shell dans ce cgroup
sudo bash -c "echo $$ > /sys/fs/cgroup/atelier/cgroup.procs; exec bash"

# Dans le shell : tenter d'allouer 64 Mo
python3 -c "x = bytearray(64 * 1024 * 1024); print('OK')"
# Attendu : Killed (OOM)

# Vérifier
cat /sys/fs/cgroup/atelier/memory.events
exit
```

#### Question 2.2.a.1 — Que contient `memory.events` après l'OOM ? Quel champ a augmenté ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.2.a.2 — Quelle différence entre `memory.max` et `memory.high` ? (Lire `Documentation/admin-guide/cgroup-v2.rst` ou `man 7 cgroups`.)

```text
Votre résultat :


Interprétation :

```

#### Exercice 2.2.b — Limiter le CPU

```bash
# CPU max = 20% d'un core (20000 µs sur 100000 µs de période)
echo "20000 100000" | sudo tee /sys/fs/cgroup/atelier/cpu.max

# Lancer un yes CPU-bound dans ce cgroup
sudo bash -c "echo $$ > /sys/fs/cgroup/atelier/cgroup.procs; yes > /dev/null"

# Dans un autre terminal
top -p $(pgrep -f 'yes')
```

#### Question 2.2.b — Quel pourcentage CPU observez-vous ? Pourquoi ce n'est pas exactement 20% ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 2.2.c — Lire les compteurs systemd via cgroups

Tous les services systemd ont un cgroup associé.

```bash
# Trouver le cgroup d'un service
systemctl status healthcheck.service | grep CGroup

# Lire ses compteurs directement
cat /sys/fs/cgroup/system.slice/healthcheck.service/memory.current
cat /sys/fs/cgroup/system.slice/healthcheck.service/cpu.stat
```

#### Question 2.2.c — Comparer la sortie de `systemctl show healthcheck.service --property=MemoryCurrent` avec la lecture directe de `memory.current`. Sont-elles identiques ? Pourquoi ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 2.3 — /proc et /sys, les systèmes de fichiers virtuels (45 min)

`/proc` expose des informations sur les processus et le noyau ; `/sys` expose les devices et drivers. Tout est texte, lisible avec `cat`.

```bash
# Charge système
cat /proc/loadavg

# Mémoire détaillée
cat /proc/meminfo | head -20

# Interruptions par CPU
cat /proc/interrupts | head -10

# Stats détaillées d'un processus
ls /proc/$$/
cat /proc/$$/maps | head -20         # carte mémoire virtuelle
cat /proc/$$/status | grep -E 'Vm|Threads|State'
cat /proc/$$/sched | head -5         # statistiques scheduler

# Paramètres réglables du kernel
ls /proc/sys/net/ipv4/ | head -20
cat /proc/sys/net/ipv4/ip_forward    # 0 ou 1 ?
sudo sysctl -w net.ipv4.ip_forward=1
cat /proc/sys/net/ipv4/ip_forward
```

#### Question 2.3.a — Que représente la 5ᵉ colonne de `/proc/loadavg` ? (Lire `man proc`.)

```text
Votre résultat :


Interprétation :

```

#### Question 2.3.b — Combien d'appels système votre shell a-t-il fait depuis son démarrage ? (Astuce : `/proc/$$/syscall` ou `/proc/$$/stat`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.3.c — Lister 5 paramètres `sysctl` réseau intéressants (avec leur valeur courante et leur effet).

```text
Votre résultat :


| sysctl | valeur | effet |
|--------|--------|-------|
|        |        |       |
|        |        |       |
|        |        |       |
|        |        |       |
|        |        |       |


Interprétation :

```

---

### 2.4 — Capabilities POSIX (45 min)

Au lieu du modèle binaire « root / non-root », Linux découpe les privilèges en ~40 *capabilities*.

```bash
# Capabilities du shell courant
capsh --print

# Capabilities d'un binaire
getcap /usr/bin/ping
getcap /bin/bash

# Lister les capabilities et leur description
capsh --decode=0x00000000a80425fb
```

#### Exercice 2.4.a — Binaire avec capability au lieu de SUID

```bash
# Compiler un mini-binaire qui ouvre un socket privilégié
cat << 'EOF' > /tmp/bind80.c
#include <sys/socket.h>
#include <netinet/in.h>
#include <stdio.h>
#include <unistd.h>
int main() {
    int s = socket(AF_INET, SOCK_STREAM, 0);
    struct sockaddr_in a = {.sin_family=AF_INET, .sin_port=htons(80)};
    if (bind(s, (struct sockaddr*)&a, sizeof(a)) < 0) {
        perror("bind"); return 1;
    }
    printf("bind 80 OK (pid=%d)\n", getpid());
    sleep(30);
    return 0;
}
EOF
gcc /tmp/bind80.c -o /tmp/bind80

# Tenter sans privilège
/tmp/bind80
# Attendu : Permission denied

# Au lieu de SUID, ajouter la capability strictement nécessaire
sudo setcap cap_net_bind_service=+ep /tmp/bind80
getcap /tmp/bind80

# Réessayer
/tmp/bind80
```

#### Question 2.4.a.1 — Le binaire fonctionne-t-il maintenant ? Quelle est la différence de surface d'attaque entre `setcap cap_net_bind_service` et `chmod u+s` (SUID root) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.4.a.2 — Lister tous les binaires SUID du système et leurs capabilities éventuelles. Lesquels vous semblent suspects ou inutiles ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 2.4.b — Drop de capabilities

```bash
# Lancer un shell sans aucune capability
sudo capsh --drop=cap_sys_admin,cap_net_admin,cap_chown -- -c "bash"

# Dans le shell : tenter une opération privilégiée
mount -t tmpfs none /mnt 2>&1
# Attendu : Operation not permitted

exit
```

#### Question 2.4.b — Si on lance un conteneur Docker avec `--cap-drop ALL --cap-add NET_BIND_SERVICE`, à quoi correspond ce ensemble de capabilities (en clair) ?

```text
Votre résultat :


Interprétation :

```

---

### 2.5 — AppArmor (LSM) (30 min)

AppArmor est le module de sécurité (LSM) par défaut sur Ubuntu. Il restreint ce que peut faire un binaire au-delà des permissions Unix.

```bash
# Statut global
sudo aa-status | head -30

# Profils chargés
sudo apparmor_status | grep "profiles are in enforce mode" -A 50 | head -20

# Profil par défaut pour Docker
ls /etc/apparmor.d/ | grep docker

# Lire un profil simple
sudo cat /etc/apparmor.d/usr.bin.man 2>/dev/null | head -40
```

#### Question 2.5.a — Combien de profils sont en mode `enforce` ? Combien en `complain` ? Quelle est la différence ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 2.5.b — Trouver un processus qui tourne sous un profil AppArmor (champ `name` de `aa-status`). Identifier le PID concerné avec `cat /proc/<PID>/attr/current`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

> **Checkpoint Module 2 :** Vous savez créer un mini-conteneur à la main (namespaces + cgroups), lire les compteurs kernel, et expliquer ce que fait Docker sous le capot.

---

## Module 3 — Réseau Linux et sécurité (3 h)

### Objectifs
- Analyser et configurer le réseau Linux avec les outils modernes
- Filtrer le trafic avec iptables
- Détecter les anomalies avec tcpdump et nmap
- Durcir le service SSH et auditer le système

---

### 3.1 — Diagnostic réseau avancé (45 min)

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

#### Question 3.1.a.1 — Quelle est l'interface réseau principale de votre Codespace ? Quel est son MTU ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.1.a.2 — Quelle est la passerelle par défaut ? Quelle métrique ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.1.a.3 — Quels ports TCP sont en écoute sur votre machine ? Pour chacun, identifier le processus.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.1.a.4 — Quel est le ratio de paquets reçus vs. transmis sur votre interface principale ? Que peut-on en déduire ? (Astuce : `ip -s link show <iface>`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 3.1.b — Capture de trafic avec tcpdump

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

#### Question 3.1.b.1 — Combien de paquets capturés pour une seule requête `curl http://localhost:8080/health` ? Identifier les paquets de la poignée de main TCP (SYN, SYN-ACK, ACK) puis la fermeture (FIN).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.1.b.2 — Écrire un filtre BPF capturant **uniquement** le trafic HTTP sortant vers `example.com:80` depuis une IP source spécifique. Joindre la commande.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.1.b.3 — Ouvrir `/tmp/capture.pcap` dans `tshark` (mode CLI Wireshark) et afficher les requêtes HTTP avec leurs URI. (Astuce : `tshark -r ... -Y 'http.request' -T fields -e http.request.uri`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 3.1.c — Scan réseau avec nmap

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

#### Question 3.1.c.1 — Quels services nmap a-t-il détectés sur votre machine ? Comment fait-il pour déterminer la version ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.1.c.2 — Différence entre un scan `-sS` (SYN scan), `-sT` (TCP connect) et `-sU` (UDP). Quand utiliser lequel ? Lequel nécessite root et pourquoi ?

```text
Votre résultat :


Interprétation :

```

#### Question 3.1.c.3 — Lancer un scan agressif sur localhost (`nmap -A -T4 localhost`) et le capturer simultanément avec `tcpdump`. Combien de paquets nmap envoie-t-il au total ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 3.2 — Filtrage réseau avec iptables (45 min)

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

> **Attention :** Dans un Codespace, soyez prudents avec la politique DROP. Si vous vous déconnectez, vous ne pourrez peut-être plus vous reconnecter. Préférez tester d'abord avec `iptables -I INPUT 1 -j ACCEPT` en filet de sécurité, à supprimer ensuite.

#### Question 3.2.a.1 — Recopier la sortie finale de `iptables -L INPUT -n -v --line-numbers`. Combien de paquets ont matché la règle ESTABLISHED jusqu'ici ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.2.a.2 — À quoi sert exactement `conntrack` ? Lister 3 états possibles d'une connexion suivie (`/proc/net/nf_conntrack`).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.2.a.3 — La règle `-m limit --limit 3/min` autorise quoi exactement ? Que se passe-t-il après 3 connexions/minute ? Tester avec une boucle de `nc localhost 22`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 3.2.b — Règles avancées et NAT

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

#### Question 3.2.b.1 — Capturer le trafic avec `tcpdump -i any port 80 or port 8080` pendant un `curl http://localhost:80/health`. Que voit-on ? Le client sait-il qu'il y a eu redirection ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.2.b.2 — Différence entre `REDIRECT` et `DNAT` ? Quand utiliser l'un ou l'autre ?

```text
Votre résultat :


Interprétation :

```

#### Exercice 3.2.c — Mise en place d'un pare-feu complet (script)

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

#### Question 3.2.c.1 — Tester l'anti-SYN-flood en lançant `hping3 -S -p 22 --flood -c 100 localhost` (installer si nécessaire). Combien de paquets sont droppés ? Quel champ d'`iptables -L INPUT -v -n` augmente ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.2.c.2 — Ajouter une règle qui journalise UNIQUEMENT les paquets provenant d'un sous-réseau extérieur (ex. `10.0.0.0/8`) — sans bloquer le trafic. Joindre la règle.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 3.3 — Sécurité système (1h)

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

#### Question 3.3.a.1 — Combien de binaires SUID/SGID trouvez-vous sur le système ? Lister les 5 qui vous semblent les plus risqués et justifier.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.3.a.2 — Existe-t-il un compte autre que `root` avec UID 0 ? Comment vérifier les comptes sans mot de passe ? (`awk -F: '($2 == "") {print}' /etc/shadow` — sudo requis.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.3.a.3 — Lister les fichiers `world-writable` dans `/etc`. Pourquoi est-ce critique s'ils existent ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 3.3.b — Durcissement SSH

Créer une paire de clés et configurer `sshd` de façon sécurisée.

```bash
# Générer une clé ED25519 (plus sécurisé que RSA 2048)
ssh-keygen -t ed25519 -C "atelier-linux-m2" -f ~/.ssh/atelier_ed25519 -N ""

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

#### Question 3.3.b.1 — Quelle est la taille d'une clé publique ED25519 vs. RSA 4096 ? Pourquoi ED25519 est-il préféré aujourd'hui (citer 2 raisons cryptographiques) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.3.b.2 — Pour quelle raison `MaxAuthTries 3` est-il une bonne pratique ? Que se passe-t-il après 3 échecs ?

```text
Votre résultat :


Interprétation :

```

#### Question 3.3.b.3 — Tester la configuration avec `ssh-audit` (`pip install ssh-audit`). Joindre le score obtenu et les recommandations restantes.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 3.3.c — Audit avec auditd

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

#### Question 3.3.c.1 — Recopier la sortie de `ausearch -k passwd_changes`. Quels champs identifient l'utilisateur ayant effectué l'action et le binaire utilisé ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 3.3.c.2 — Écrire une règle auditd qui surveille les écritures dans `/etc/sudoers.d/`. Tester en y créant un fichier et joindre la trace auditd.

```text
Votre commande :


Votre résultat :


Interprétation :

```

> **Checkpoint Module 3 :** Votre pare-feu est en place, SSH est durci, et auditd surveille les activités sensibles.

---

## Module 4 — Réseau avancé : nftables, network namespaces, eBPF (2 h 30)

### Objectifs
- Migrer un firewall iptables vers la syntaxe moderne nftables
- Construire un mini-routeur logiciel avec des network namespaces
- Découvrir le filtrage haute performance avec XDP/eBPF

---

### 4.1 — nftables, le successeur d'iptables (1 h)

Depuis le noyau 3.13, `nftables` remplace `iptables`. Avantages : syntaxe unifiée IPv4/IPv6, mise à jour atomique des règles, sets et maps.

```bash
# Installer
sudo apt-get install -y nftables

# Lister la configuration vide
sudo nft list ruleset

# Créer une table inet (IPv4 + IPv6)
sudo nft add table inet filter

# Créer la chaîne d'entrée
sudo nft 'add chain inet filter input { type filter hook input priority 0; policy drop; }'

# Règles équivalentes au module 3
sudo nft add rule inet filter input iif lo accept
sudo nft add rule inet filter input ct state established,related accept
sudo nft add rule inet filter input tcp dport { 22, 80, 443, 8080 } accept
sudo nft add rule inet filter input icmp type echo-request limit rate 5/second accept
sudo nft add rule inet filter input log prefix \"NFT_DROP: \" level info

# Vérifier
sudo nft list ruleset
```

#### Question 4.1.a.1 — Comparer le nombre de règles nécessaires pour autoriser 4 ports en TCP en `iptables` vs `nftables`. Quel est l'apport des *sets* ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 4.1.a.2 — Utiliser une *map* nftables pour associer port → action (ex. 22 → accept, 80 → drop). Joindre la commande.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 4.1.a.3 — Comment nftables résout-il le problème de la mise à jour atomique de règles que `iptables-restore` ne gérait pas bien ?

```text
Votre résultat :


Interprétation :

```

#### Exercice 4.1.b — Convertir le firewall iptables en nftables

Reprendre `~/scripts/firewall.sh` du Module 3 et le réécrire en pure nftables (`~/scripts/firewall.nft`).

```bash
sudo tee /etc/nftables-atelier.nft > /dev/null << 'EOF'
#!/usr/sbin/nft -f

flush ruleset

table inet filter {
    set allowed_tcp {
        type inet_service
        elements = { 22, 80, 443, 8080 }
    }

    chain input {
        type filter hook input priority filter; policy drop;

        iif lo accept
        ct state established,related accept
        ct state invalid drop

        icmp type echo-request limit rate 2/second accept

        tcp dport @allowed_tcp accept

        # SYN flood mitigation
        tcp flags syn limit rate 25/second burst 50 packets accept

        log prefix "NFT_DROP: " level warn
    }

    chain forward { type filter hook forward priority filter; policy drop; }
    chain output  { type filter hook output  priority filter; policy accept; }
}
EOF

sudo nft -f /etc/nftables-atelier.nft
sudo nft list ruleset
```

#### Question 4.1.b — Vérifier le résultat avec `curl http://localhost:8080/health` et `nmap localhost`. Qu'observe-t-on ? Joindre les deux sorties.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 4.2 — Network namespaces et bridge (1 h)

Construire un mini-réseau de 3 conteneurs sans Docker.

```bash
# Créer 3 namespaces
for ns in nsA nsB nsC; do sudo ip netns add $ns; done

# Créer un bridge
sudo ip link add br0 type bridge
sudo ip link set br0 up
sudo ip addr add 10.20.0.254/24 dev br0

# Pour chaque namespace : créer une veth, attacher au bridge, configurer
for i in 1 2 3; do
    ns="ns$(printf '\\x'$(printf '%02x' $((64+i))))"   # nsA, nsB, nsC
    sudo ip link add veth-h$i type veth peer name veth-c$i
    sudo ip link set veth-h$i master br0
    sudo ip link set veth-h$i up
    sudo ip link set veth-c$i netns $ns
    sudo ip -n $ns addr add 10.20.0.$i/24 dev veth-c$i
    sudo ip -n $ns link set veth-c$i up
    sudo ip -n $ns link set lo up
    sudo ip -n $ns route add default via 10.20.0.254
done

# Tester
sudo ip netns exec nsA ping -c 2 10.20.0.2
sudo ip netns exec nsA ping -c 2 10.20.0.254
```

#### Question 4.2.a — Recopier la sortie des deux pings. Mesurer la latence. Pourquoi celle du bridge est-elle plus basse ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 4.2.b — Activer l'IP forwarding sur l'hôte (`sysctl net.ipv4.ip_forward=1`) et configurer un SNAT pour permettre à `nsA` d'accéder à Internet. Joindre la règle iptables/nftables et le résultat de `ping -c 2 1.1.1.1` depuis `nsA`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 4.2.c — Lancer un mini-HTTP `python3 -m http.server 8000` dans `nsA` et y accéder depuis `nsB` et depuis l'hôte. Joindre les deux sessions `curl`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 4.3 — Introduction à eBPF et XDP (30 min)

eBPF permet d'exécuter du code en bac-à-sable dans le noyau. XDP attache un programme eBPF sur le chemin d'entrée d'une carte réseau pour filtrer à débit maximal (avant l'allocation `sk_buff`).

```bash
# Installer les outils
sudo apt-get install -y bpfcc-tools linux-tools-generic

# Lister les programmes eBPF chargés
sudo bpftool prog show

# Exécuter un programme bcc tout fait : compteur de syscalls par PID
sudo /usr/sbin/syscount-bpfcc -d 5 -p $$

# Lister les sondes disponibles
sudo bpftrace -l 'tracepoint:syscalls:sys_enter_*' | head -20
```

#### Question 4.3.a — Sur 5 secondes, quels sont les 3 syscalls les plus appelés par votre shell ? Tester avec `syscount-bpfcc`.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 4.3.b — Quel est l'intérêt de XDP par rapport à `iptables` pour un firewall haut débit ? (Lire la doc Cilium ou Cloudflare ; citer un chiffre.)

```text
Votre résultat :


Interprétation :

```

#### Question 4.3.c — bpftrace one-liner : compter les connexions TCP entrantes par IP source pendant 30 s avec `tracepoint:sock:inet_sock_set_state`. Joindre le one-liner et le résultat.

```text
Votre commande :


Votre résultat :


Interprétation :

```

> **Checkpoint Module 4 :** Vous avez migré un firewall en nftables, construit un mini-LAN logiciel, et tracé du trafic via eBPF.

---

## Module 5 — Observabilité avancée (2 h 30)

### Objectifs
- Tracer un programme syscall par syscall
- Profiler un binaire pour identifier les hot-paths
- Écrire ses propres scripts bpftrace
- Comprendre la différence entre tracing, profiling et metrics

---

### 5.1 — strace et ltrace (45 min)

`strace` trace les appels système ; `ltrace` trace les appels à des bibliothèques partagées.

```bash
# Tracer une commande simple
strace -f -e trace=openat,read,close ls /etc 2>&1 | head -30

# Statistiques agrégées (top syscalls)
strace -c -f ls /etc/ > /dev/null

# Attacher à un processus existant
PID=$(pgrep -f healthcheck.py | head -1)
sudo strace -p $PID -e trace=network -c &
STRACE_PID=$!
sleep 5
for i in 1 2 3; do curl -s http://localhost:8080/health > /dev/null; done
sudo kill $STRACE_PID
wait

# ltrace : appels à libc
ltrace -c ls /etc/ > /dev/null
```

#### Question 5.1.a.1 — Quel syscall est le plus coûteux en temps cumulé pour `ls /etc/` ? Et en nombre d'appels ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 5.1.a.2 — Pourquoi `strace` ralentit énormément un programme ? (Lire `man 2 ptrace` et expliquer le mécanisme de capture.)

```text
Votre résultat :


Interprétation :

```

#### Question 5.1.a.3 — Tracer `python3 -c "print('hi')"` avec `strace`. Combien de fichiers Python ouvre-t-il au démarrage avant d'imprimer ? Pourquoi tant ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 5.2 — perf : profiling et événements hardware (45 min)

`perf` est l'outil de profiling officiel du kernel, exploitant les PMU (Performance Monitoring Units) du CPU.

```bash
# Activer l'accès non-privilégié (Codespace : peut nécessiter root)
sudo sysctl kernel.perf_event_paranoid=1

# Lister les événements disponibles
perf list | head -30

# Statistiques basiques : nombre d'instructions, branches, cache misses
perf stat -e cycles,instructions,cache-misses,branch-misses sleep 1

# Profil détaillé d'une commande
perf record -g -- python3 -c "
total = 0
for i in range(10_000_000): total += i**2
print(total)
"

# Voir le rapport
perf report --stdio | head -40

# Top en temps réel
sudo perf top
```

#### Question 5.2.a — Combien d'instructions et de cycles `sleep 1` consomme-t-il ? Quel est l'IPC (instructions per cycle) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 5.2.b — Quel symbole (fonction) consomme le plus de CPU dans le programme Python ? Pourquoi ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 5.2.c — Générer un flame graph avec `perf script | stackcollapse-perf.pl | flamegraph.pl > /tmp/flame.svg` (cloner le repo `brendangregg/FlameGraph` si besoin). Joindre une capture ou décrire les zones chaudes observées.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 5.3 — bpftrace : DTrace pour Linux (1 h)

bpftrace permet d'écrire des sondes eBPF en quelques lignes.

```bash
# One-liner : qui ouvre quoi
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_openat { printf("%s -> %s\\n", comm, str(args->filename)); }'
# Ctrl+C après quelques secondes

# Compter les exec() par programme
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { @[comm] = count(); }'

# Latence des read() en histogramme
sudo bpftrace -e '
tracepoint:syscalls:sys_enter_read { @start[tid] = nsecs; }
tracepoint:syscalls:sys_exit_read /@start[tid]/ {
    @latency_ns = hist(nsecs - @start[tid]);
    delete(@start[tid]);
}'
```

Créer un script bpftrace réutilisable `~/scripts/http_latency.bt` qui mesure la latence des appels `accept()` et `close()` sur le port 8080 du service healthcheck.

#### Question 5.3.a — Quel programme ouvre le plus de fichiers pendant 30 s d'utilisation normale du Codespace ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 5.3.b — Histogramme de latence des syscalls `read` sur 30 s. Quelle est la latence médiane ? Quelle queue (p99) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 5.3.c — Différence fondamentale entre `strace`, `perf` et `bpftrace` ? (Mécanisme, overhead, granularité.)

```text
Votre résultat :


| Outil | Mécanisme | Overhead | Cas d'usage |
|-------|-----------|----------|-------------|
| strace |  |  |  |
| perf |  |  |  |
| bpftrace |  |  |  |


Interprétation :

```

> **Checkpoint Module 5 :** Vous savez tracer n'importe quel appel kernel sans recompilation, en production, avec un overhead négligeable.

---

## Module 6 — Conteneurs Docker (3 h)

### Objectifs
- Maîtriser Docker au-delà des commandes de base
- Construire des images optimisées et sécurisées
- Orchestrer des applications multi-conteneurs avec Docker Compose
- Implémenter des bonnes pratiques de sécurité

---

### 6.1 — Docker avancé : images et build (1h)

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

#### Question 6.1.a.1 — Combien de couches contient `python:3.12-slim` ? Quelle est la couche la plus volumineuse ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.1.a.2 — Comparer la taille de `python:3.12-slim`, `python:3.12-alpine` et `python:3.12`. Lequel a la plus petite empreinte ? Quel est le compromis ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 6.1.b — Dockerfile multi-stage optimisé

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

#### Question 6.1.b.1 — Taille finale de l'image `healthcheck:v1.0` ? Combien de couches ? Comparer avec une version mono-stage (sans `AS builder`).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.1.b.2 — Quel est l'utilisateur effectif du conteneur ? Vérifier avec `docker exec healthcheck-app id`. Pourquoi est-ce critique pour la sécurité ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.1.b.3 — Forcer un échec du healthcheck (`docker exec healthcheck-app kill 1`). Observer le redémarrage automatique. Combien de temps avant le passage à `unhealthy` ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.1.b.4 — Que se passe-t-il si vous lancez le conteneur avec `--memory=10m` (limite trop basse) ? Joindre la trace.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 6.1.c — Sécurité des images

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

#### Question 6.1.c.1 — Combien de vulnérabilités HIGH/CRITICAL Trivy détecte-t-il dans `python:3.12-slim` ? Dans `healthcheck:v1.0` ? Dans `healthcheck:distroless` ?

```text
Votre commande :


Votre résultat :


| Image | HIGH | CRITICAL |
|-------|------|----------|
| python:3.12-slim |  |  |
| healthcheck:v1.0 |  |  |
| healthcheck:distroless |  |  |


Interprétation :

```

#### Question 6.1.c.2 — Pourquoi l'image distroless n'a pas de shell (`docker exec healthcheck:distroless sh` échoue) ? Quel impact pour le debug en production ? Citer une alternative (ephemeral debug container).

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.1.c.3 — `trivy image --format table --severity CRITICAL` permet de générer un rapport CI. Stocker la sortie dans `livrables/trivy-report.txt` et committer.

```text
Votre commande :


Votre résultat :


Interprétation :

```

---

### 6.2 — Docker Compose et architecture multi-services (1h)

#### Exercice 6.2.a — Stack monitoring complète

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

#### Question 6.2.a.1 — Tous les conteneurs sont-ils `healthy` ? Joindre `docker compose ps` complet.

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.2.a.2 — Ouvrir Grafana sur http://localhost:3000 (admin/atelier2024), ajouter manuellement un panel qui affiche `up{job="healthcheck"}`. Joindre une capture (déposer dans `livrables/grafana.png`).

```text
Étapes suivies :


Capture jointe (chemin) :


Interprétation :

```

#### Question 6.2.a.3 — Quel est le rôle de la directive `depends_on` ? Garantit-elle que le service en dépendance est *prêt* (et pas seulement démarré) ? Quelle alternative ?

```text
Votre résultat :


Interprétation :

```

#### Exercice 6.2.b — Opérations sur la stack

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

#### Question 6.2.b.1 — Que se passe-t-il vraiment lors d'un `--scale healthcheck=3` ? Comment Docker Compose gère-t-il les ports exposés ? (Indice : il y en a un seul…)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.2.b.2 — Quelle est la différence entre `docker compose down`, `docker compose down -v`, et `docker compose down --rmi all` ? Quand utiliser chacun ?

```text
Votre résultat :


Interprétation :

```

---

### 6.3 — Sécurité Docker et bonnes pratiques (1h)

#### Exercice 6.3.a — Isolation et capabilities

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

#### Question 6.3.a.1 — Décoder le bitmask de `CapEff` avec `capsh --decode=<hex>`. Combien de capabilities Docker ajoute-t-il par défaut ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.3.a.2 — Avec le profil seccomp strict, le service healthcheck fonctionne-t-il ? Si non, quel syscall manque et comment le déterminer ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.3.a.3 — Quelle est la liste exacte des capabilities supprimées par `--cap-drop ALL --cap-add NET_BIND_SERVICE` ? (Comparer avec un conteneur par défaut.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Exercice 6.3.b — Gestion des secrets

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

#### Question 6.3.b.1 — Avec `docker inspect <container>`, retrouver le secret passé en variable d'environnement. Pourquoi est-ce un anti-pattern ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 6.3.b.2 — Lister 3 outils plus robustes pour la gestion de secrets en production (Vault, AWS Secrets Manager…) et leurs garanties (rotation, audit).

```text
Votre résultat :


Interprétation :

```

#### Exercice 6.3.c — Analyse de sécurité avec Trivy et Docker Bench

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

#### Question 6.3.c.1 — Quels sont les 3 « WARN » les plus critiques retournés par Docker Bench ? Comment les corriger ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

> **Checkpoint Module 6 :** Votre stack monitoring est déployée, les conteneurs tournent avec les permissions minimales, et les secrets ne sont pas exposés dans les variables d'environnement.

---

## Module 7 — Conteneurs avancés : rootless, Kubernetes, supply chain (3 h)

### Objectifs
- Exécuter Docker/Podman sans privilèges root
- Déployer un mini-cluster Kubernetes local
- Détecter les comportements anormaux à l'exécution avec Falco
- Construire une chaîne d'approvisionnement logicielle vérifiable (SBOM, signatures)

---

### 7.1 — Rootless containers (Podman et Docker rootless) (45 min)

Les conteneurs *rootless* tournent sous un UID utilisateur réel, sans dameon root. Bénéfice sécurité majeur : une évasion ne donne pas root sur l'hôte.

```bash
# Installer Podman (drop-in replacement Docker)
sudo apt-get install -y podman uidmap

# Vérifier les UID maps subordonnées (essentielles pour user namespace)
cat /etc/subuid
cat /etc/subgid
# Doit montrer : vscode:100000:65536

# Lancer un conteneur rootless
podman run --rm -it alpine sh -c "id; cat /proc/self/uid_map"

# Comparer avec Docker classique
docker run --rm alpine id
```

#### Question 7.1.a.1 — Quel UID l'utilisateur `root` du conteneur Podman a-t-il sur l'hôte ? (Inspecter `/proc/<pid>/uid_map`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.1.a.2 — Lancer un serveur Podman sur le port 80. Cela fonctionne-t-il ? Pourquoi (lié au binding sur port privilégié) ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.1.a.3 — Avantages et limites de rootless. Lister 3 cas où vous le recommanderiez, 1 cas où ce n'est pas adapté.

```text
Votre résultat :


| Cas | Rootless adapté ? | Pourquoi |
|-----|-------------------|----------|
|  |  |  |
|  |  |  |
|  |  |  |
|  |  |  |


Interprétation :

```

---

### 7.2 — Kubernetes local avec kind (1 h)

`kind` (Kubernetes IN Docker) crée un cluster K8s à l'intérieur de conteneurs Docker, parfait pour TP et CI.

```bash
# Installer kind
curl -Lo /tmp/kind https://kind.sigs.k8s.io/dl/v0.20.0/kind-linux-amd64
chmod +x /tmp/kind && sudo mv /tmp/kind /usr/local/bin/

# Installer kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
chmod +x kubectl && sudo mv kubectl /usr/local/bin/

# Créer un cluster 1 control-plane + 2 workers
cat << 'EOF' > /tmp/kind-cluster.yaml
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
nodes:
  - role: control-plane
  - role: worker
  - role: worker
EOF
kind create cluster --config /tmp/kind-cluster.yaml --name atelier

# Vérifier
kubectl cluster-info
kubectl get nodes
kubectl get pods -A
```

Déployer le service healthcheck en K8s :

```yaml
# ~/k8s/healthcheck.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: healthcheck
spec:
  replicas: 3
  selector:
    matchLabels:
      app: healthcheck
  template:
    metadata:
      labels:
        app: healthcheck
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        fsGroup: 10001
      containers:
        - name: healthcheck
          image: healthcheck:v1.0
          imagePullPolicy: IfNotPresent
          ports:
            - containerPort: 8080
          resources:
            requests:
              memory: "32Mi"
              cpu: "50m"
            limits:
              memory: "64Mi"
              cpu: "100m"
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: true
            capabilities:
              drop: ["ALL"]
          livenessProbe:
            httpGet:
              path: /health
              port: 8080
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /health
              port: 8080
            periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: healthcheck
spec:
  selector:
    app: healthcheck
  ports:
    - port: 80
      targetPort: 8080
  type: ClusterIP
```

```bash
# Charger l'image locale dans kind
kind load docker-image healthcheck:v1.0 --name atelier

# Déployer
mkdir -p ~/k8s
# (coller le YAML ci-dessus dans ~/k8s/healthcheck.yaml)
kubectl apply -f ~/k8s/healthcheck.yaml

# Suivi
kubectl get pods -w
kubectl logs -l app=healthcheck --tail=20

# Port-forward pour tester
kubectl port-forward svc/healthcheck 8085:80 &
curl http://localhost:8085/health
```

#### Question 7.2.a.1 — Combien de pods le déploiement crée-t-il ? Sur quels nodes sont-ils placés ? (`kubectl get pods -o wide`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.2.a.2 — Que se passe-t-il si vous supprimez un pod (`kubectl delete pod <nom>`) ? Combien de temps prend le remplacement ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.2.a.3 — Tester un rollout : modifier l'image (par exemple un tag inexistant) avec `kubectl set image deployment/healthcheck healthcheck=healthcheck:broken`. Observer le comportement. Comment K8s protège-t-il du rollout cassé ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.2.a.4 — Quelle est la différence entre `livenessProbe` et `readinessProbe` ? Quel impact sur le routing du Service ?

```text
Votre résultat :


Interprétation :

```

---

### 7.3 — Falco : détection d'anomalies runtime (45 min)

Falco analyse les syscalls (via eBPF ou kernel module) pour alerter sur les comportements suspects (shell dans un conteneur, écriture dans `/etc`, etc.).

```bash
# Installer Falco (mode userspace, sans module kernel pour le Codespace)
curl -fsSL https://falco.org/repo/falcosecurity-packages.asc | sudo gpg --dearmor -o /usr/share/keyrings/falco-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/falco-archive-keyring.gpg] https://download.falco.org/packages/deb stable main" | \
    sudo tee /etc/apt/sources.list.d/falcosecurity.list
sudo apt-get update && sudo apt-get install -y falco

# Lancer en mode userspace (BPF probe)
sudo falco -o engine.kind=ebpf 2>&1 | tee /tmp/falco.log &

# Générer des événements suspects
docker run --rm -it alpine sh -c "cat /etc/shadow"     # rule: read sensitive file
docker run --rm -it alpine sh -c "wget google.com"     # rule: outbound from container

# Arrêter Falco
sudo pkill falco
```

#### Question 7.3.a — Quelle règle Falco a déclenché lors de la lecture de `/etc/shadow` ? (Chercher dans `/tmp/falco.log`.)

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.3.b — Écrire une règle Falco personnalisée qui alerte si un processus dans un conteneur exécute `nmap`. Joindre la règle (fichier YAML) et la trace de déclenchement.

```text
Règle créée :


Trace de déclenchement :


Interprétation :

```

---

### 7.4 — Supply chain : SBOM et signatures (30 min)

```bash
# Installer syft (SBOM) et grype (scanner de vulnérabilités)
curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sudo sh -s -- -b /usr/local/bin
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sudo sh -s -- -b /usr/local/bin

# Générer un SBOM SPDX/CycloneDX
syft healthcheck:v1.0 -o spdx-json > livrables/sbom-healthcheck.json
syft healthcheck:v1.0 -o cyclonedx-xml > livrables/sbom-healthcheck.xml

# Scanner via le SBOM (plus rapide qu'un nouveau scan d'image)
grype sbom:livrables/sbom-healthcheck.json

# Signer une image avec cosign (keyless via OIDC en mode demo)
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo mv cosign-linux-amd64 /usr/local/bin/cosign && sudo chmod +x /usr/local/bin/cosign

# Générer une paire de clés locale
cosign generate-key-pair
# Signer (image locale → besoin d'un registry, on simule avec une digest)
cosign sign --key cosign.key healthcheck:v1.0 || echo "Signature requires a registry — see explanation"
```

#### Question 7.4.a — Combien de paquets le SBOM liste-t-il pour `healthcheck:v1.0` ? Quels sont les 5 paquets avec le plus de vulnérabilités selon grype ?

```text
Votre commande :


Votre résultat :


Interprétation :

```

#### Question 7.4.b — Différence entre SPDX et CycloneDX ? Lequel est le plus adapté à un audit légal ?

```text
Votre résultat :


Interprétation :

```

#### Question 7.4.c — Expliquer le modèle « keyless signing » de cosign (sigstore + Fulcio + Rekor). Quel est l'intérêt par rapport à une clé statique ?

```text
Votre résultat :


Interprétation :

```

> **Checkpoint Module 7 :** Vous savez exécuter des conteneurs sans root, orchestrer avec K8s, détecter les comportements anormaux, et fournir une chaîne d'approvisionnement vérifiable.

---

## Module 8 — Projet intégrateur étendu (2 h)

### Objectifs
Assembler l'ensemble des compétences des modules précédents dans un projet cohérent et fonctionnel.

---

### Énoncé du projet

**Contexte :** Vous êtes ingénieur système dans une startup. On vous demande de mettre en place une infrastructure complète et auditable pour un service web critique.

**Livrable :** Un script `deploy.sh` (à versionner dans `livrables/`) qui :

1. **Prépare l'environnement** : vérifie les prérequis, crée les répertoires nécessaires
2. **Déploie la stack Docker** : application + monitoring (Prometheus + Grafana)
3. **Configure le pare-feu** : applique les règles **nftables** appropriées (et non plus iptables)
4. **Durcit le système** : applique les options systemd de sandboxing, vérifie le score `systemd-analyze security`
5. **Crée un service systemd** : assure le redémarrage automatique de la stack au boot
6. **Met en place la supervision** : timer systemd vérifie l'état des conteneurs/minute
7. **Active Falco** : règles personnalisées pour le runtime
8. **Génère un SBOM signé** : avec syft + cosign (clé locale)
9. **Produit un rapport étendu** `infrastructure_report.md` avec :
   - État de tous les composants
   - Score `systemd-analyze security` de chaque service
   - Captures de cgroup memory/cpu (`/sys/fs/cgroup/...`)
   - Liste des CVE détectées (sortie grype)
   - Capture eBPF sur 30 s (top syscalls vu par les conteneurs)

**Bonus (+25 % de note) :** déployer la même stack en **rootless** ou dans **kind** (K8s local) avec NetworkPolicy.

---

### Guide de réalisation

#### Étape 1 — Script de déploiement principal

> **Note :** le squelette ci-dessous reprend l'architecture du Module 4 original. C'est un *point de départ*. Vous devez l'enrichir avec les nouveaux blocs (nftables, Falco, SBOM, durcissement systemd).

```bash
#!/bin/bash
# deploy.sh — Script de déploiement intégrateur
# Atelier Linux M2 — Module 8

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
| Pare-feu nftables | `sudo nft list ruleset \| grep allowed_tcp` | Set présent |
| Score sécurité systemd | `systemd-analyze security healthcheck` | < 5.0 (« exposed » ou mieux) |
| SBOM signé | `cosign verify-blob --key cosign.pub livrables/sbom-healthcheck.json` | Signature valide |
| Falco actif | `systemctl is-active falco` | `active` |
| Trace eBPF capturée | `ls livrables/bpftrace-*.txt` | Fichier ≥ 100 lignes |

---

### Questions de réflexion finale

#### Question 8.a — Décrire votre architecture finale en 10 lignes maximum, en mettant en avant 3 décisions de design.

```text
Votre résultat :


```

#### Question 8.b — Quelle est la surface d'attaque résiduelle de votre infrastructure ? Lister 3 vecteurs d'attaque possibles et la mitigation que vous avez (ou pourriez) mettre en place.

```text
Votre résultat :


| Vecteur | Probabilité | Impact | Mitigation |
|---------|-------------|--------|------------|
|         |             |        |            |
|         |             |        |            |
|         |             |        |            |


```

#### Question 8.c — Si vous deviez passer cette infrastructure en production (vraie machine, vraie charge), citez 5 changements prioritaires.

```text
Votre résultat :

1.
2.
3.
4.
5.

```

#### Question 8.d — Quel module de l'atelier vous a semblé le plus utile pour votre futur métier ? Pourquoi ? (Réponse personnelle, non notée mais lue.)

```text
Votre résultat :


```

---

## Récapitulatif et ressources

### Ce que vous avez mis en place

```
┌──────────────────────────────────────────────────────────────────────┐
│                     Infrastructure finale                             │
│                                                                       │
│  Kernel-level                                                         │
│  ├── namespaces (mnt/pid/net/user) manipulés à la main                │
│  ├── cgroups v2 (limites mem/cpu/io)                                  │
│  ├── capabilities POSIX (drop ALL + ajouts ciblés)                    │
│  └── AppArmor (profils par binaire)                                   │
│                                                                       │
│  systemd                                                              │
│  ├── healthcheck.service       (API Python, sandboxing complet)       │
│  ├── healthcheck.socket        (activation à la demande)              │
│  ├── monitoring-stack.service  (lance Docker Compose au boot)         │
│  ├── healthwatch.timer         (vérifie les conteneurs/minute)        │
│  └── falco.service             (détection anomalies runtime)          │
│                                                                       │
│  Conteneurs                                                           │
│  ├── healthcheck-app   (port 8080, image distroless, non-root)        │
│  ├── prometheus        (port 9090)                                    │
│  ├── grafana           (port 3000)                                    │
│  └── (bonus) cluster kind 1×control-plane + 2×worker                  │
│                                                                       │
│  Réseau                                                               │
│  ├── nftables           (pare-feu unifié IPv4/IPv6, sets, maps)       │
│  ├── network namespaces (bridge interne, SNAT pour ns externalisés)   │
│  ├── eBPF/XDP           (filtrage haut débit, démo)                   │
│  ├── auditd             (surveillance des accès sensibles)            │
│  └── SSH                (clés ED25519, ciphers durcis, score A)       │
│                                                                       │
│  Observabilité                                                        │
│  ├── strace, perf, bpftrace (tracing/profiling)                       │
│  ├── Prometheus + Grafana    (métriques)                              │
│  └── journalctl              (logs structurés)                        │
│                                                                       │
│  Supply chain                                                         │
│  ├── Trivy   (scan CVE images)                                        │
│  ├── syft    (SBOM SPDX + CycloneDX)                                  │
│  ├── grype   (CVE depuis SBOM)                                        │
│  └── cosign  (signature et vérification d'artefacts)                  │
└──────────────────────────────────────────────────────────────────────┘
```

### Pour aller plus loin

**systemd**
- [systemd.io — Documentation officielle](https://systemd.io)
- `man systemd.service`, `man systemd.timer`, `man systemd.exec`, `man systemd.resource-control`
- `systemd-analyze security` — score de durcissement par service

**Internals kernel**
- *Linux Kernel Development*, Robert Love (référence)
- `Documentation/admin-guide/cgroup-v2.rst` (kernel.org)
- [namespaces(7), cgroups(7), capabilities(7)] — pages `man` exhaustives

**Réseau et sécurité**
- [nftables wiki](https://wiki.nftables.org)
- [Linux Security Hardening Checklist](https://github.com/trimstray/the-practical-linux-hardening-guide)
- [Cilium — Networking & Security via eBPF](https://cilium.io)
- [BPF Performance Tools — Brendan Gregg](http://www.brendangregg.com/bpf-performance-tools-book.html)

**Conteneurs**
- [Docker Security Documentation](https://docs.docker.com/engine/security/)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Trivy — Scanner de vulnérabilités](https://trivy.dev)
- [Podman — Rootless containers](https://podman.io)
- [Kubernetes Pod Security Standards](https://kubernetes.io/docs/concepts/security/pod-security-standards/)

**Observabilité et supply chain**
- [bpftrace tutorial — one-liners](https://github.com/iovisor/bpftrace/blob/master/docs/tutorial_one_liners.md)
- [Sigstore — keyless signing](https://www.sigstore.dev)
- [SLSA framework](https://slsa.dev) — niveaux de chaîne d'approvisionnement

**Outils complémentaires**
- `falco` — Détection d'anomalies runtime dans les conteneurs
- `lynis` — Audit de sécurité Linux complet
- `sysdig` — Surveillance avancée des appels système
- `osquery` — SQL pour interroger l'état d'un système

---

*Atelier Linux Avancé — M2 Informatique — GitHub Codespaces*
*Durée : 25 h | Niveau : Confirmé*
*Rendu : fork du dépôt avec ce README complété + dossier `livrables/`*
