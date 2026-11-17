<p align="center"><img src="assets/banner.svg" alt="lockDock" width="100%"></p>

# lockDock

App de barre de menu macOS qui **empêche le Dock de sauter sur un autre écran** quand le curseur touche le bas d'un écran secondaire.

## Fonctionnement

- Un `CGEventTap` surveille les mouvements du curseur.
- Le curseur est retenu à 4 px du bord bas des écrans secondaires : le Dock, qui se déclenche au contact du bord, ne les voit jamais.
- Le bas de l'écran principal n'est pas touché.
- Icône dans la barre de statut avec un interrupteur Activer/Désactiver et « Quitter ».

## Installation

```bash
swiftc -O DockLock.swift -o DockLock
./DockLock &
```

Au premier lancement, accorder **Accessibilité** à l'app (Réglages Système → Confidentialité et sécurité → Accessibilité), puis relancer.

## Limites

- Dock **en bas** uniquement.
- Le bord bas des écrans secondaires n'est plus pointable (4 px).

## Idées

- Dock à gauche/droite
- Raccourci clavier global pour activer/désactiver
- Lancement au démarrage
- Choix de l'écran qui garde le Dock
- Marge réglable
- Mode « maintenir Option pour autoriser le passage »
