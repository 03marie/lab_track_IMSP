from django.contrib.auth.models import AbstractUser
from django.db import models


class Utilisateur(AbstractUser):
    """Compte LabTrack. Les rôles pilotent les permissions de l'API."""

    class Role(models.TextChoices):
        ADMIN = "admin", "Administrateur"
        RESPONSABLE = "responsable", "Responsable de laboratoire"
        TECHNICIEN = "technicien", "Technicien"
        ENSEIGNANT = "enseignant", "Enseignant"
        ETUDIANT = "etudiant", "Étudiant"

    role = models.CharField("rôle", max_length=20, choices=Role.choices, default=Role.ETUDIANT)
    matricule = models.CharField("matricule", max_length=50, blank=True)
    telephone = models.CharField("téléphone", max_length=30, blank=True)

    class Meta:
        verbose_name = "utilisateur"
        verbose_name_plural = "utilisateurs"
        ordering = ["last_name", "first_name", "username"]

    def __str__(self) -> str:
        return self.nom_complet or self.username

    @property
    def nom_complet(self) -> str:
        return self.get_full_name().strip()

    @property
    def est_admin(self) -> bool:
        return self.is_superuser or self.role == self.Role.ADMIN

    @property
    def est_responsable(self) -> bool:
        return self.role == self.Role.RESPONSABLE

    @property
    def est_technicien(self) -> bool:
        return self.role == self.Role.TECHNICIEN

    @property
    def peut_gerer_equipements(self) -> bool:
        """Admin ou responsable : crée/modifie les équipements, valide les opérations."""
        return self.est_admin or self.est_responsable

    @property
    def est_personnel(self) -> bool:
        """Utilise l'application mobile en v1 (admin, responsable, technicien)."""
        return self.est_admin or self.role in (self.Role.RESPONSABLE, self.Role.TECHNICIEN)
