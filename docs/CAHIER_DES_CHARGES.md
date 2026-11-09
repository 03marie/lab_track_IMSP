# LabTrack — Cahier des charges

Application mobile de gestion et de traçabilité des équipements de laboratoire de l'IMSP,
basée sur la lecture de codes-barres (Code 128) par la caméra du téléphone.

> Document de pilotage : on le met à jour à chaque étape terminée (cocher les cases).

---

## 1. Contexte et objectif

- L'IMSP gère ses équipements (inventaire, emprunts, retours, pannes) sur papier ou oralement :
  pertes d'information, retours difficiles à tracer, inventaires longs.
- **Objectif** : dématérialiser ces procédures avec une application mobile qui identifie
  chaque équipement par scan de son code-barres et conserve un historique fiable.
- **Livrable du mois** : un prototype fonctionnel démontrable à l'IMSP (concours de
  simplification administrative), puis déploiement sur un vrai serveur si le projet intéresse.

## 2. Contraintes

| Contrainte | Décision |
|---|---|
| Pas de serveur à l'IMSP | Le PC du porteur du projet sert de serveur (Wi-Fi local) pour la démo |
| Scan sans matériel supplémentaire | Application mobile **native** (Flutter), caméra du téléphone |
| Délai | ~4 semaines pour la v1 |
| Format du code | **Code 128**, contenu = identifiant seul (`IMSP-EQ-0001`) ; le détail reste en base |
| Plateforme mobile | Android d'abord ; iPhone hors v1 |

## 3. Architecture technique

```
 Téléphone Android (Flutter)  ──HTTP/JSON (JWT)──►  PC serveur : Django + DRF  ──►  PostgreSQL (conteneur)
   - scan Code 128 (mobile_scanner)                   - API REST /api/v1/                 
   - écrans métier                                    - Django Admin (back-office PC)
                                                      - génération codes-barres + PDF étiquettes
```

- **Backend** : Python 3.11, Django 5.2, Django REST Framework, SimpleJWT, drf-spectacular
  (documentation OpenAPI), django-filter, python-barcode, reportlab, Pillow.
- **Déploiement** : Docker Compose (PostgreSQL, Django via gunicorn, nginx pour statiques/médias) ;
  le même fichier sert pour le PC de démo puis pour le futur serveur de l'IMSP.
- **Base** : PostgreSQL, **uniquement dans Docker** (aucune base ni dépendance serveur installée sur le PC hôte).
  Développement, tests et démo passent tous par `docker compose`.
- **Mobile** : Flutter 3.x, `mobile_scanner`, `dio` (HTTP), Riverpod 3 (état), go_router, stockage sécurisé du jeton.
- **Identité visuelle** : « Nuit d'encre & Aurore » — fond encre, dégradé signature iris → aqua, touches d'or ;
  police Plus Jakarta Sans intégrée ; thèmes sombre (par défaut) et clair.
- **Réseau démo** : Django lancé sur `0.0.0.0:8000`, téléphone et PC sur le même Wi-Fi,
  l'app pointe vers l'IP du PC (HTTP clair autorisé sur le réseau local pour la démo).

## 4. Acteurs et rôles

| Rôle | Droits principaux |
|---|---|
| Administrateur | Tout : comptes, laboratoires, catégories, équipements, paramètres |
| Responsable de laboratoire | Équipements de son/ses labo(s), valide emprunts/retours, lance les inventaires |
| Technicien | Reçoit les pannes, enregistre les interventions, remet en service |
| Enseignant | Consulte les équipements, demande du matériel (v2) |
| Étudiant | Consulte son historique, demande un emprunt (v2) |

**v1** : Administrateur, Responsable, Technicien utilisent l'app. Enseignants/étudiants sont
emprunteurs enregistrés dans le système, mais passent par le responsable.

## 5. Modèle de données

| Entité | Champs clés |
|---|---|
| `User` | username, nom, rôle, matricule, téléphone, laboratoires gérés |
| `Laboratoire` | code, nom, localisation, responsable |
| `Categorie` | nom, description |
| `Equipement` | **code** (unique, auto `IMSP-EQ-0001`), nom, catégorie, laboratoire, emplacement, marque, modèle, n° de série, date d'acquisition, **état** (bon / usé / défectueux / hors service), **statut** (disponible / emprunté / en maintenance / retiré), photo |
| `Mouvement` | équipement, type (création, emprunt, retour, panne, réparation, inventaire, modification), auteur, date, détails — **journal d'audit immuable** |
| `Emprunt` | équipement, emprunteur, validé par, dates (emprunt, retour prévu, retour réel), état au retour, statut |
| `Inventaire` / `LigneInventaire` | laboratoire, ouvert par, dates, statut ; lignes : équipement scanné, résultat (trouvé / manquant / inconnu) |
| `Panne` / `Intervention` | équipement, déclarant, description, photo, priorité, statut, technicien ; interventions : actions, dates, résultat |

Règles : un équipement n'a qu'**un** emprunt actif ; un équipement `emprunté`, `en maintenance`
ou `retiré` ne peut pas être emprunté ; chaque changement de statut crée un `Mouvement`.

## 6. Fonctionnalités v1

### F1 — Authentification et rôles
- Connexion par identifiant/mot de passe → jeton JWT (access + refresh).
- Permissions par rôle sur chaque endpoint.

### F2 — Équipements et codes-barres
- CRUD équipements, catégories, laboratoires (admin/responsable).
- Génération automatique du code unique à la création.
- Image Code 128 par équipement (PNG) ; **planche d'étiquettes PDF** (plusieurs par feuille A4) ;
  réimpression d'une étiquette sans créer un nouvel équipement.
- **Recherche par scan** : `GET /equipements/par-code/<code>/` → fiche complète + statut + emprunt en cours.

### F3 — Emprunts et retours
- Créer un emprunt (scan équipement + choix emprunteur + date de retour prévue).
- Enregistrer un retour (scan, état constaté ; si anomalie → ouvre une panne).
- Liste des emprunts en cours et en retard.

### F4 — Inventaire par scan
- Ouvrir un inventaire pour un laboratoire, ajouter les équipements scannés.
- Clôture : rapport d'écarts (trouvés / manquants / inconnus).

### F5 — Pannes et maintenance
- Déclarer une panne (scan, description, photo), suivi par le technicien jusqu'à la remise en service.

### F6 — Tableau de bord et rapports
- Compteurs : disponibles / empruntés / en maintenance / en retard, par laboratoire.
- Export des rapports d'inventaire et d'emprunts (PDF/CSV).

### F7 — Journal d'historique
- Historique consultable par équipement (qui, quoi, quand).

## 7. Hors périmètre v1 (phases suivantes)

Mode hors-ligne avec synchronisation, notifications push, comptes étudiants/enseignants avec
demandes en ligne, iPhone, détection d'anomalies et prévision des pannes (IA).
Les **alertes de retard** simples (calcul serveur) sont incluses en v1.

## 8. Exigences non fonctionnelles

- Toutes les actions sensibles sont journalisées (F7).
- Mots de passe hachés (Django), jetons à durée limitée, `SECRET_KEY` et `DEBUG` via l'environnement.
- Réponses API en français pour les messages d'erreur métier ; dates en fuseau local.
- Tests automatisés sur les règles métier critiques (emprunt, retour, inventaire).
- API documentée automatiquement (`/api/docs/`).

## 9. Plan de réalisation

### Phase A — Backend (semaine 1 à début semaine 2)
- [x] A1. Cahier des charges
- [x] A2. Projet Django, configuration par environnement, apps `comptes`, `equipements`
- [x] A3. Modèles utilisateurs/rôles, laboratoires, catégories, équipements, mouvements
- [x] A4. Django Admin configuré
- [x] A5. Génération codes-barres Code 128, PNG par équipement, planche PDF
- [x] A6. Auth JWT + API équipements (liste, détail, **recherche par code**) + permissions
- [x] A7. Tests + documentation OpenAPI
- [x] A7b. Conteneurisation Docker Compose (PostgreSQL + Django/gunicorn + nginx), données de démo, endpoint `statistiques`
- [ ] A8. App `emprunts` (F3)
- [ ] A9. App `inventaires` (F4)
- [ ] A10. App `maintenance` (F5)
- [ ] A11. Tableau de bord et rapports (F6)

### Phase B — Mobile Flutter (semaines 2 à 3)
- [x] B1. Projet Flutter, client API (JWT + renouvellement auto), connexion, configuration du serveur, système de design
- [x] B2. Écran de scan (Code 128) + fiche équipement + liste avec recherche/filtres — *à tester sur téléphone réel*
- [ ] B3. Emprunts et retours
- [ ] B4. Inventaire par scan
- [ ] B5. Pannes avec photo
- [x] B6. Tableau de bord, laboratoires, profil (thème sombre/clair)

### Phase C — Démo (semaine 4)
- [ ] C1. Jeu de données réaliste (équipements réels d'un labo pilote), impression des étiquettes
- [ ] C2. Mise en réseau du PC serveur (IP fixe, pare-feu, script de lancement)
- [ ] C3. Tests sur de vrais équipements, mesure des gains de temps
- [ ] C4. Dossier du concours et scénario de démonstration

## 10. Critères de réussite de la démo

1. Un équipement est créé, son étiquette imprimée et collée.
2. Scan → la fiche s'affiche en moins de 2 secondes.
3. Un emprunt puis un retour sont enregistrés et visibles dans l'historique.
4. Un inventaire d'un labo produit un rapport d'écarts correct.
5. Une panne déclarée avec photo est suivie jusqu'à la remise en service.
