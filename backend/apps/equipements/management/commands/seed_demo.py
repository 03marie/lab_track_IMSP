"""Données de démonstration : comptes de test, laboratoires, catégories et équipements.

Usage : python manage.py seed_demo --mot-de-passe <mdp>
Idempotent : relancer la commande ne crée pas de doublons.
"""

from django.core.management.base import BaseCommand, CommandError

from apps.comptes.models import Utilisateur
from apps.equipements.models import Categorie, Equipement, Laboratoire, Mouvement, enregistrer_mouvement

COMPTES = [
    # (identifiant, prénom, nom, rôle, matricule)
    ("admin", "Admin", "IMSP", Utilisateur.Role.ADMIN, ""),
    ("resp.elec", "Koffi", "Mensah", Utilisateur.Role.RESPONSABLE, ""),
    ("resp.info", "Aïcha", "Bello", Utilisateur.Role.RESPONSABLE, ""),
    ("tech1", "Yves", "Hounkpè", Utilisateur.Role.TECHNICIEN, ""),
    ("etu1", "Awa", "Diallo", Utilisateur.Role.ETUDIANT, "IMSP-2026-001"),
    ("etu2", "Jean", "Agbodjan", Utilisateur.Role.ETUDIANT, "IMSP-2026-002"),
    ("ens1", "Prof.", "Dossou", Utilisateur.Role.ENSEIGNANT, ""),
]

LABORATOIRES = [
    ("ELEC", "Laboratoire d'électronique", "Bâtiment B, salle 12", ["resp.elec"]),
    ("INFO", "Laboratoire d'informatique", "Bâtiment A, salle 3", ["resp.info"]),
]

CATEGORIES = ["Instruments de mesure", "Ordinateurs", "Cartes de développement", "Optique", "Outillage"]

EQUIPEMENTS = [
    # (nom, catégorie, labo, marque, modèle, emplacement)
    ("Multimètre numérique", "Instruments de mesure", "ELEC", "Fluke", "117", "Armoire A2"),
    ("Multimètre numérique", "Instruments de mesure", "ELEC", "Fluke", "117", "Armoire A2"),
    ("Oscilloscope 100 MHz", "Instruments de mesure", "ELEC", "Rigol", "DS1104", "Paillasse 1"),
    ("Alimentation stabilisée", "Instruments de mesure", "ELEC", "Hantek", "HDP", "Paillasse 2"),
    ("Arduino Uno", "Cartes de développement", "ELEC", "Arduino", "Uno R3", "Armoire A3"),
    ("Arduino Uno", "Cartes de développement", "ELEC", "Arduino", "Uno R3", "Armoire A3"),
    ("ESP32 DevKit", "Cartes de développement", "ELEC", "Espressif", "DevKitC", "Armoire A3"),
    ("Fer à souder", "Outillage", "ELEC", "Weller", "WE1010", "Armoire A1"),
    ("Ordinateur portable", "Ordinateurs", "INFO", "HP", "ProBook 450", "Armoire B1"),
    ("Ordinateur portable", "Ordinateurs", "INFO", "HP", "ProBook 450", "Armoire B1"),
    ("Ordinateur de bureau", "Ordinateurs", "INFO", "Dell", "OptiPlex 3080", "Salle 3, poste 1"),
    ("Raspberry Pi 4", "Cartes de développement", "INFO", "Raspberry", "Pi 4B 4 Go", "Armoire B2"),
    ("Microscope binoculaire", "Optique", "ELEC", "Motic", "BA210", "Armoire A4"),
]


class Command(BaseCommand):
    help = "Crée des comptes, laboratoires, catégories et équipements de démonstration."

    def add_arguments(self, parser):
        parser.add_argument("--mot-de-passe", required=True,
                            help="Mot de passe attribué aux comptes de démonstration créés.")

    def handle(self, *args, **options):
        mot_de_passe = options["mot_de_passe"]
        if len(mot_de_passe) < 8:
            raise CommandError("Le mot de passe doit contenir au moins 8 caractères.")

        comptes = {}
        for identifiant, prenom, nom, role, matricule in COMPTES:
            utilisateur, cree = Utilisateur.objects.get_or_create(
                username=identifiant,
                defaults={"first_name": prenom, "last_name": nom, "role": role, "matricule": matricule},
            )
            if cree:
                utilisateur.set_password(mot_de_passe)
                if role == Utilisateur.Role.ADMIN:
                    utilisateur.is_staff = utilisateur.is_superuser = True
                utilisateur.save()
            comptes[identifiant] = utilisateur

        laboratoires = {}
        for code, nom, localisation, responsables in LABORATOIRES:
            labo, _ = Laboratoire.objects.get_or_create(
                code=code, defaults={"nom": nom, "localisation": localisation}
            )
            labo.responsables.add(*[comptes[r] for r in responsables])
            laboratoires[code] = labo

        categories = {nom: Categorie.objects.get_or_create(nom=nom)[0] for nom in CATEGORIES}

        crees = 0
        if not Equipement.objects.exists():
            for nom, categorie, labo, marque, modele, emplacement in EQUIPEMENTS:
                equipement = Equipement.objects.create(
                    nom=nom, categorie=categories[categorie], laboratoire=laboratoires[labo],
                    marque=marque, modele=modele, emplacement=emplacement,
                )
                enregistrer_mouvement(equipement, Mouvement.Type.CREATION, comptes["admin"], "Données de démonstration.")
                crees += 1

        self.stdout.write(self.style.SUCCESS(
            f"Démo prête : {len(comptes)} comptes, {len(laboratoires)} laboratoires, "
            f"{crees} équipements créés ({Equipement.objects.count()} au total)."
        ))
