from rest_framework import serializers

from .models import Categorie, Equipement, Laboratoire, Mouvement


class LaboratoireSerializer(serializers.ModelSerializer):
    nb_equipements = serializers.IntegerField(source="equipements.count", read_only=True)

    class Meta:
        model = Laboratoire
        fields = ["id", "code", "nom", "localisation", "responsables", "nb_equipements"]


class CategorieSerializer(serializers.ModelSerializer):
    class Meta:
        model = Categorie
        fields = ["id", "nom", "description"]


class EquipementSerializer(serializers.ModelSerializer):
    categorie_nom = serializers.CharField(source="categorie.nom", read_only=True)
    laboratoire_nom = serializers.CharField(source="laboratoire.nom", read_only=True)
    etat_libelle = serializers.CharField(source="get_etat_display", read_only=True)
    statut_libelle = serializers.CharField(source="get_statut_display", read_only=True)

    class Meta:
        model = Equipement
        fields = [
            "id", "code", "nom",
            "categorie", "categorie_nom", "laboratoire", "laboratoire_nom",
            "emplacement", "marque", "modele", "numero_serie", "date_acquisition",
            "description", "photo",
            "etat", "etat_libelle", "statut", "statut_libelle",
            "cree_le", "modifie_le",
        ]
        # Le code est attribué par le système ; le statut évolue par les opérations
        # (emprunt, retour, maintenance, retrait), jamais par une simple modification.
        read_only_fields = ["id", "code", "statut", "cree_le", "modifie_le"]


class MouvementSerializer(serializers.ModelSerializer):
    type_libelle = serializers.CharField(source="get_type_display", read_only=True)
    auteur_nom = serializers.SerializerMethodField()

    class Meta:
        model = Mouvement
        fields = ["id", "type", "type_libelle", "auteur", "auteur_nom", "details", "date"]

    def get_auteur_nom(self, obj) -> str:
        return str(obj.auteur) if obj.auteur else ""
