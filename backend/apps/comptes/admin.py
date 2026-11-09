from django.contrib import admin
from django.contrib.auth.admin import UserAdmin

from .models import Utilisateur


@admin.register(Utilisateur)
class UtilisateurAdmin(UserAdmin):
    list_display = ("username", "nom_complet", "role", "matricule", "is_active")
    list_filter = ("role", "is_active")
    search_fields = ("username", "first_name", "last_name", "matricule")
    fieldsets = UserAdmin.fieldsets + (
        ("LabTrack", {"fields": ("role", "matricule", "telephone")}),
    )
    add_fieldsets = UserAdmin.add_fieldsets + (
        ("LabTrack", {"fields": ("role", "matricule", "telephone")}),
    )
