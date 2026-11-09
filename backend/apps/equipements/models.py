from django.conf import settings
from django.db import models, transaction


class Laboratoire(models.Model):
    code = models.CharField("code", max_length=20, unique=True)
    nom = models.CharField("nom", max_length=150)
    localisation = models.CharField("localisation", max_length=200, blank=True)
    responsables = models.ManyToManyField(
        settings.AUTH_USER_MODEL,
        verbose_name="responsables",
        related_name="laboratoires_geres",
        blank=True,
    )

    class Meta:
        verbose_name = "laboratoire"
        verbose_name_plural = "laboratoires"
        ordering = ["nom"]

    def __str__(self) -> str:
        return self.nom


class Categorie(models.Model):
    nom = models.CharField("nom", max_length=100, unique=True)
    description = models.TextField("description", blank=True)

    class Meta:
        verbose_name = "catégorie"
        verbose_name_plural = "catégories"
        ordering = ["nom"]

    def __str__(self) -> str:
        return self.nom


class Equipement(models.Model):
    class Etat(models.TextChoices):
        BON = "bon", "Bon état"
        USE = "use", "Usé"
        DEFECTUEUX = "defectueux", "Défectueux"
        HORS_SERVICE = "hors_service", "Hors service"

    class Statut(models.TextChoices):
        DISPONIBLE = "disponible", "Disponible"
        EMPRUNTE = "emprunte", "Emprunté"
        EN_MAINTENANCE = "en_maintenance", "En maintenance"
        RETIRE = "retire", "Retiré"

    # Identifiant lu par le scan (Code 128). Attribué automatiquement, jamais réutilisé.
    code = models.CharField("code-barres", max_length=40, unique=True, null=True, blank=True, editable=False)
    nom = models.CharField("nom", max_length=200)
    categorie = models.ForeignKey(
        Categorie, verbose_name="catégorie", on_delete=models.PROTECT, related_name="equipements"
    )
    laboratoire = models.ForeignKey(
        Laboratoire, verbose_name="laboratoire", on_delete=models.PROTECT, related_name="equipements"
    )
    emplacement = models.CharField("emplacement", max_length=150, blank=True)
    marque = models.CharField("marque", max_length=100, blank=True)
    modele = models.CharField("modèle", max_length=100, blank=True)
    numero_serie = models.CharField("numéro de série", max_length=100, blank=True)
    date_acquisition = models.DateField("date d'acquisition", null=True, blank=True)
    description = models.TextField("description", blank=True)
    photo = models.ImageField("photo", upload_to="equipements/", blank=True)
    etat = models.CharField("état", max_length=20, choices=Etat.choices, default=Etat.BON)
    statut = models.CharField("statut", max_length=20, choices=Statut.choices, default=Statut.DISPONIBLE)
    cree_le = models.DateTimeField("créé le", auto_now_add=True)
    modifie_le = models.DateTimeField("modifié le", auto_now=True)

    class Meta:
        verbose_name = "équipement"
        verbose_name_plural = "équipements"
        ordering = ["code"]

    def __str__(self) -> str:
        return f"{self.code or '—'} · {self.nom}"

    @classmethod
    def formater_code(cls, pk: int) -> str:
        return f"{settings.CODE_PREFIXE}{pk:0{settings.CODE_LONGUEUR}d}"

    def save(self, *args, **kwargs):
        # Le code dérive de la clé primaire : unique sans condition de concurrence
        # et jamais réattribué après suppression.
        if self.code:
            return super().save(*args, **kwargs)
        with transaction.atomic():
            super().save(*args, **kwargs)
            self.code = self.formater_code(self.pk)
            super().save(update_fields=["code"])

    @property
    def est_disponible(self) -> bool:
        return self.statut == self.Statut.DISPONIBLE and self.etat != self.Etat.HORS_SERVICE


class Mouvement(models.Model):
    """Journal d'historique d'un équipement. Écrit par le système, jamais modifié."""

    class Type(models.TextChoices):
        CREATION = "creation", "Création"
        MODIFICATION = "modification", "Modification"
        EMPRUNT = "emprunt", "Emprunt"
        RETOUR = "retour", "Retour"
        PANNE = "panne", "Panne déclarée"
        REPARATION = "reparation", "Réparation"
        INVENTAIRE = "inventaire", "Inventaire"
        RETRAIT = "retrait", "Retrait"

    equipement = models.ForeignKey(Equipement, on_delete=models.CASCADE, related_name="mouvements")
    type = models.CharField("type", max_length=20, choices=Type.choices)
    auteur = models.ForeignKey(
        settings.AUTH_USER_MODEL, on_delete=models.SET_NULL, null=True, blank=True, related_name="+"
    )
    details = models.TextField("détails", blank=True)
    date = models.DateTimeField("date", auto_now_add=True)

    class Meta:
        verbose_name = "mouvement"
        verbose_name_plural = "mouvements"
        ordering = ["-date", "-id"]

    def __str__(self) -> str:
        return f"{self.date:%d/%m/%Y %H:%M} · {self.get_type_display()} · {self.equipement.code}"


def enregistrer_mouvement(equipement: Equipement, type: str, auteur=None, details: str = "") -> Mouvement:
    """Point d'entrée unique pour alimenter l'historique."""
    return Mouvement.objects.create(equipement=equipement, type=type, auteur=auteur, details=details)
