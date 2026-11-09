from django.contrib.auth.password_validation import validate_password
from rest_framework import serializers

from .models import Utilisateur


class UtilisateurSerializer(serializers.ModelSerializer):
    role_libelle = serializers.CharField(source="get_role_display", read_only=True)
    nom_complet = serializers.CharField(read_only=True)

    class Meta:
        model = Utilisateur
        fields = [
            "id", "username", "first_name", "last_name", "nom_complet", "email",
            "role", "role_libelle", "matricule", "telephone", "is_active",
        ]
        read_only_fields = ["id", "is_active"]


class UtilisateurCreationSerializer(UtilisateurSerializer):
    """Création par un administrateur (mot de passe en écriture seule)."""

    password = serializers.CharField(write_only=True, min_length=8)

    class Meta(UtilisateurSerializer.Meta):
        fields = UtilisateurSerializer.Meta.fields + ["password"]

    def validate_password(self, valeur):
        validate_password(valeur)
        return valeur

    def create(self, validated_data):
        mot_de_passe = validated_data.pop("password")
        utilisateur = Utilisateur(**validated_data)
        utilisateur.set_password(mot_de_passe)
        utilisateur.save()
        return utilisateur


class ChangementMotDePasseSerializer(serializers.Serializer):
    ancien = serializers.CharField(write_only=True)
    nouveau = serializers.CharField(write_only=True, min_length=8)

    def validate_nouveau(self, valeur):
        validate_password(valeur, self.context["request"].user)
        return valeur

    def validate_ancien(self, valeur):
        if not self.context["request"].user.check_password(valeur):
            raise serializers.ValidationError("Ancien mot de passe incorrect.")
        return valeur
