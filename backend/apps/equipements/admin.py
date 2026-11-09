from django.contrib import admin
from django.http import HttpResponse

from . import codes_barres
from .models import Categorie, Equipement, Laboratoire, Mouvement, enregistrer_mouvement


@admin.register(Laboratoire)
class LaboratoireAdmin(admin.ModelAdmin):
    list_display = ("code", "nom", "localisation")
    search_fields = ("code", "nom")
    filter_horizontal = ("responsables",)


@admin.register(Categorie)
class CategorieAdmin(admin.ModelAdmin):
    list_display = ("nom", "description")
    search_fields = ("nom",)


class MouvementInline(admin.TabularInline):
    model = Mouvement
    extra = 0
    can_delete = False
    fields = ("date", "type", "auteur", "details")
    readonly_fields = fields

    def has_add_permission(self, request, obj=None):
        return False


@admin.action(description="Imprimer les étiquettes (PDF) des équipements sélectionnés")
def imprimer_etiquettes(modeladmin, request, queryset):
    equipements = list(queryset.select_related("laboratoire").order_by("code")[:500])
    reponse = HttpResponse(codes_barres.pdf_etiquettes(equipements), content_type="application/pdf")
    reponse["Content-Disposition"] = 'inline; filename="etiquettes-labtrack.pdf"'
    return reponse


@admin.register(Equipement)
class EquipementAdmin(admin.ModelAdmin):
    list_display = ("code", "nom", "categorie", "laboratoire", "etat", "statut")
    list_filter = ("laboratoire", "categorie", "etat", "statut")
    search_fields = ("code", "nom", "marque", "modele", "numero_serie")
    readonly_fields = ("code", "cree_le", "modifie_le")
    actions = [imprimer_etiquettes]
    inlines = [MouvementInline]

    def save_model(self, request, obj, form, change):
        super().save_model(request, obj, form, change)
        if not change:
            enregistrer_mouvement(obj, Mouvement.Type.CREATION, request.user, "Créé depuis l'administration.")
        elif form.changed_data:
            enregistrer_mouvement(obj, Mouvement.Type.MODIFICATION, request.user,
                                  "Champs modifiés (admin) : " + ", ".join(sorted(form.changed_data)))


@admin.register(Mouvement)
class MouvementAdmin(admin.ModelAdmin):
    """Journal en lecture seule."""

    list_display = ("date", "equipement", "type", "auteur")
    list_filter = ("type",)
    search_fields = ("equipement__code", "equipement__nom", "details")
    date_hierarchy = "date"

    def has_add_permission(self, request):
        return False

    def has_change_permission(self, request, obj=None):
        return False

    def has_delete_permission(self, request, obj=None):
        return False
