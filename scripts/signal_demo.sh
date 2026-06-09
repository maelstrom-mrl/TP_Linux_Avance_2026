#!/bin/bash

# Enregistrer l'heure de démarrage pour le calcul de l'uptime
START_TIME=$(date +%s)

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

# Nouvelle fonction pour afficher les statistiques
show_stats() {
    local now=$(date +%s)
    local uptime=$((now - START_TIME))
    echo ""
    echo "--- [$(date +%T)] STATISTIQUES (SIGUSR1) ---"
    echo "Uptime              : ${uptime} secondes"
    echo "Nombre d'itérations : $counter"
    echo "----------------------------------------"
}

LOCKFILE="/tmp/signal_demo_$$.lock"
touch "$LOCKFILE"
echo "[$(date +%T)] Démarrage (PID: $$). Lockfile: $LOCKFILE"
echo "Envoyez SIGHUP (recharger), SIGUSR1 (stats), SIGTERM/SIGINT (quitter)."

# Boucle principale
counter=0
while true; do
    echo "[$(date +%T)] En cours... (itération $counter)"
    counter=$((counter + 1))
    sleep 5
done

# Installer les gestionnaires de signaux
trap cleanup SIGTERM SIGINT
trap reload_config SIGHUP
trap show_stats SIGUSR1
