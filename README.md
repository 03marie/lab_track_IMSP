# LabTrack

Gestion et traçabilité des équipements de laboratoire de l'IMSP (scan de codes-barres Code 128).
Plan complet et avancement : [docs/CAHIER_DES_CHARGES.md](docs/CAHIER_DES_CHARGES.md).

```
backend/    API Django + Django Admin        deploy/   configuration nginx
mobile/     application Flutter (Android)    docs/     cahier des charges
```

## Lancer le serveur (PC de démo) avec Docker

```bash
cp .env.example .env          # puis éditer DJANGO_SECRET_KEY et DB_PASSWORD
docker compose up -d --build
docker compose exec web python manage.py createsuperuser        # ou données de démo :
docker compose exec web python manage.py seed_demo --mot-de-passe 'UnMotDePasseSolide!'
```

- API et documentation : `http://<IP-du-PC>:8000/api/docs/`
- Administration (PC) : `http://<IP-du-PC>:8000/admin/`
- Le téléphone et le PC doivent être sur le même réseau ; l'application mobile pointe vers `http://<IP-du-PC>:8000`.
- IP du PC : `hostname -I`. Si le téléphone n'y accède pas, ouvrir le port dans le pare-feu (`sudo ufw allow 8000/tcp`).
- Arrêt : `docker compose down` (les données restent dans les volumes ; `down -v` les efface).
- Sauvegarde de la base : `docker compose exec db pg_dump -U labtrack labtrack > sauvegarde.sql`

## Développement (tout reste dans Docker)

```bash
# Code monté dans le conteneur + rechargement automatique
docker compose -f docker-compose.yml -f docker-compose.dev.yml up -d --build

docker compose exec web python manage.py test apps                    # tests
docker compose exec web python manage.py makemigrations               # migrations
docker compose logs -f web                                            # journaux
```

Aucune base de données n'est installée sur le PC : PostgreSQL tourne dans le conteneur `db`
(données conservées dans le volume `pgdata`).

## Application mobile (Flutter)

```bash
cd mobile
flutter pub get
flutter run                      # téléphone Android branché en USB (débogage USB activé)
flutter build apk --release --target-platform android-arm64   # APK de production (~27 Mo, arm64) :
                                 # build/app/outputs/flutter-apk/app-release.apk
flutter test                     # tests
flutter test --update-goldens apercus/   # captures d'écran de revue → apercus/captures/
```

Au premier lancement, toucher la pastille « Configurer le serveur » sous le formulaire et saisir
l'IP du PC (ex. `192.168.1.20:8000`), puis « Tester ».

## Principaux endpoints (`/api/v1/`)

| Méthode | URL | Rôle |
|---|---|---|
| POST | `auth/connexion/` | Obtient les jetons JWT |
| GET | `auth/moi/` | Profil connecté |
| GET | `equipements/par-code/<code>/` | **Fiche d'un équipement à partir du code scanné** |
| GET/POST/PATCH | `equipements/` | Liste, création, modification |
| GET | `equipements/<id>/code-barres/` | Image PNG du code-barres |
| GET | `equipements/etiquettes/?ids=1,2` ou `?laboratoire=1` | Planche d'étiquettes PDF |
| GET | `equipements/<id>/historique/` | Journal de l'équipement |
| GET | `equipements/statistiques/` | Compteurs par statut (filtrable par laboratoire) |
| POST | `equipements/<id>/retirer/` | Retire du parc (motif obligatoire) |
| GET/POST/PATCH | `utilisateurs/`, `laboratoires/`, `categories/` | Référentiels |
