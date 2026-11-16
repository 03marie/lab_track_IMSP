from django.db.models import Count, ProtectedError
from django.http import HttpResponse
from django.shortcuts import get_object_or_404
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import APIException, PermissionDenied, ValidationError
from rest_framework.response import Response

from apps.comptes.permissions import LectureSeulePourPersonnelEcritureGestionnaire

from . import codes_barres
from .models import Categorie, Equipement, Laboratoire, Mouvement, enregistrer_mouvement
from .serializers import (
    CategorieSerializer,
    EquipementSerializer,
    LaboratoireSerializer,
    MouvementSerializer,
)


class Conflit(APIException):
    """409 : l'action est refusée à cause de l'état actuel des données (historique, contenu…)."""

    status_code = status.HTTP_409_CONFLICT
    default_detail = "Cette action est impossible dans l'état actuel."
    default_code = "conflit"


class LaboratoireViewSet(viewsets.ModelViewSet):
    """Laboratoires. Création, modification et suppression réservées à l'administrateur."""

    queryset = Laboratoire.objects.prefetch_related("equipements")
    serializer_class = LaboratoireSerializer
    permission_classes = [LectureSeulePourPersonnelEcritureGestionnaire]
    search_fields = ["code", "nom"]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def _reserver_admin(self):
        if not self.request.user.est_admin:
            raise PermissionDenied("Seul un administrateur gère les laboratoires.")

    def perform_create(self, serializer):
        self._reserver_admin()
        serializer.save()

    def perform_update(self, serializer):
        self._reserver_admin()
        serializer.save()

    def destroy(self, request, *args, **kwargs):
        self._reserver_admin()
        labo = self.get_object()
        total = labo.equipements.count()
        if total:
            retires = labo.equipements.filter(statut=Equipement.Statut.RETIRE).count()
            detail = f"Ce laboratoire contient encore {total} équipement{'s' if total > 1 else ''}"
            if retires:
                detail += f" (dont {retires} retiré{'s' if retires > 1 else ''} du parc)"
            raise Conflit(detail + ". Supprimez ou déplacez-les avant de supprimer le laboratoire.")
        labo.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class CategorieViewSet(viewsets.ModelViewSet):
    queryset = Categorie.objects.all()
    serializer_class = CategorieSerializer
    permission_classes = [LectureSeulePourPersonnelEcritureGestionnaire]
    search_fields = ["nom"]
    http_method_names = ["get", "post", "patch", "head", "options"]


class EquipementViewSet(viewsets.ModelViewSet):
    """Équipements.

    Lecture : tout le personnel (un retour peut concerner un autre laboratoire).
    Écriture : admin, ou responsable pour les équipements de ses laboratoires.
    Suppression définitive : seulement si l'équipement n'a jamais servi (créé par erreur).
    Sinon il est *retiré* du parc : il disparaît des listes mais son historique est conservé.
    """

    queryset = Equipement.objects.select_related("categorie", "laboratoire")
    serializer_class = EquipementSerializer
    permission_classes = [LectureSeulePourPersonnelEcritureGestionnaire]
    filterset_fields = ["laboratoire", "categorie", "statut", "etat"]
    search_fields = ["code", "nom", "marque", "modele", "numero_serie", "emplacement"]
    ordering_fields = ["code", "nom", "cree_le"]
    http_method_names = ["get", "post", "patch", "delete", "head", "options"]

    def get_queryset(self):
        queryset = super().get_queryset()
        # Les équipements retirés du parc n'apparaissent que si on les demande (?statut=retire),
        # ou quand on consulte directement une fiche.
        params = self.request.query_params
        liste = self.action == "list" or (self.action == "etiquettes" and "ids" not in params)
        if liste and "statut" not in params:
            queryset = queryset.exclude(statut=Equipement.Statut.RETIRE)
        return queryset

    # --- Contrôle d'accès par laboratoire -------------------------------------
    def _verifier_laboratoire(self, laboratoire):
        utilisateur = self.request.user
        if utilisateur.est_admin:
            return
        if not utilisateur.laboratoires_geres.filter(pk=laboratoire.pk).exists():
            raise PermissionDenied("Vous ne gérez pas ce laboratoire.")

    def perform_create(self, serializer):
        self._verifier_laboratoire(serializer.validated_data["laboratoire"])
        equipement = serializer.save()
        enregistrer_mouvement(equipement, Mouvement.Type.CREATION, self.request.user,
                              f"Enregistré dans {equipement.laboratoire.nom}.")

    def perform_update(self, serializer):
        ancien = serializer.instance
        self._verifier_laboratoire(ancien.laboratoire)
        if "laboratoire" in serializer.validated_data:
            self._verifier_laboratoire(serializer.validated_data["laboratoire"])
        champs_modifies = [
            nom for nom, valeur in serializer.validated_data.items()
            if getattr(ancien, nom) != valeur
        ]
        equipement = serializer.save()
        if champs_modifies:
            enregistrer_mouvement(equipement, Mouvement.Type.MODIFICATION, self.request.user,
                                  "Champs modifiés : " + ", ".join(sorted(champs_modifies)))

    def destroy(self, request, *args, **kwargs):
        """Suppression définitive d'un équipement qui n'a jamais servi."""
        equipement = self.get_object()
        self._verifier_laboratoire(equipement.laboratoire)
        a_servi = equipement.mouvements.exclude(
            type__in=[Mouvement.Type.CREATION, Mouvement.Type.MODIFICATION]
        ).exists()
        if equipement.statut != Equipement.Statut.DISPONIBLE or a_servi:
            raise Conflit(
                "Cet équipement a un historique (emprunt, panne, inventaire ou retrait) : il ne peut pas "
                "être supprimé définitivement. Retirez-le du parc pour le masquer en gardant sa traçabilité."
            )
        try:
            equipement.delete()
        except ProtectedError:
            raise Conflit("Cet équipement est référencé par d'autres enregistrements : retirez-le du parc.")
        return Response(status=status.HTTP_204_NO_CONTENT)

    # --- Recherche par scan ---------------------------------------------------
    @action(detail=False, methods=["get"], url_path=r"par-code/(?P<code>[^/]+)")
    def par_code(self, request, code=None):
        """Retrouve un équipement à partir du contenu du code-barres scanné."""
        equipement = Equipement.objects.select_related("categorie", "laboratoire").filter(
            code=code.strip().upper()
        ).first()
        if equipement is None:
            return Response(
                {"detail": f"Aucun équipement ne correspond au code « {code} »."},
                status=status.HTTP_404_NOT_FOUND,
            )
        return Response(self.get_serializer(equipement).data)

    @action(detail=False, methods=["get"])
    def statistiques(self, request):
        """Compteurs par statut (accepte les mêmes filtres que la liste, ex. `?laboratoire=1`)."""
        par_statut = {valeur: 0 for valeur in Equipement.Statut.values}
        lignes = self.filter_queryset(self.get_queryset()).order_by().values("statut").annotate(n=Count("id"))
        for ligne in lignes:
            par_statut[ligne["statut"]] = ligne["n"]
        # `total` = parc en service : les équipements retirés sont comptés à part (par_statut.retire).
        en_service = sum(n for statut, n in par_statut.items() if statut != Equipement.Statut.RETIRE)
        return Response({"total": en_service, "par_statut": par_statut})

    # --- Historique et étiquettes --------------------------------------------
    @action(detail=True, methods=["get"])
    def historique(self, request, pk=None):
        mouvements = self.get_object().mouvements.select_related("auteur")
        page = self.paginate_queryset(mouvements)
        return self.get_paginated_response(MouvementSerializer(page, many=True).data)

    @action(detail=True, methods=["get"], url_path="code-barres")
    def code_barres(self, request, pk=None):
        """Image PNG du code-barres de l'équipement."""
        equipement = self.get_object()
        return HttpResponse(codes_barres.png_code128(equipement.code), content_type="image/png")

    @action(detail=False, methods=["get"])
    def etiquettes(self, request):
        """Planche d'étiquettes PDF.

        Paramètres : `ids=1,2,3` ou `laboratoire=<id>` (filtres habituels acceptés),
        `saut=<n>` pour sauter n emplacements d'une feuille déjà entamée.
        """
        ids = request.query_params.get("ids")
        if ids:
            try:
                liste_ids = [int(i) for i in ids.split(",") if i.strip()]
            except ValueError:
                raise ValidationError({"ids": "Liste d'identifiants invalide."})
            queryset = self.get_queryset().filter(pk__in=liste_ids)
        else:
            queryset = self.filter_queryset(self.get_queryset())
        try:
            saut = int(request.query_params.get("saut", 0))
        except ValueError:
            raise ValidationError({"saut": "Doit être un entier."})

        equipements = list(queryset.order_by("code")[:500])
        if not equipements:
            raise ValidationError("Aucun équipement à imprimer.")
        reponse = HttpResponse(codes_barres.pdf_etiquettes(equipements, saut), content_type="application/pdf")
        reponse["Content-Disposition"] = 'inline; filename="etiquettes-labtrack.pdf"'
        return reponse

    @action(detail=True, methods=["post"])
    def retirer(self, request, pk=None):
        """Retire l'équipement du parc (réformé, perdu, donné...) sans effacer son historique."""
        equipement = self.get_object()
        self._verifier_laboratoire(equipement.laboratoire)
        if equipement.statut == Equipement.Statut.EMPRUNTE:
            raise ValidationError("Cet équipement est actuellement emprunté : enregistrez d'abord son retour.")
        if equipement.statut == Equipement.Statut.RETIRE:
            raise ValidationError("Cet équipement est déjà retiré.")
        motif = str(request.data.get("motif", "")).strip()
        if not motif:
            raise ValidationError({"motif": "Le motif du retrait est obligatoire."})
        equipement.statut = Equipement.Statut.RETIRE
        equipement.save(update_fields=["statut", "modifie_le"])
        enregistrer_mouvement(equipement, Mouvement.Type.RETRAIT, request.user, motif)
        return Response(self.get_serializer(equipement).data)
