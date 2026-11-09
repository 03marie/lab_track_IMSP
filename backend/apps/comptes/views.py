from drf_spectacular.utils import extend_schema
from rest_framework import status, viewsets
from rest_framework.decorators import action
from rest_framework.exceptions import PermissionDenied
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Utilisateur
from .permissions import EstAdminOuResponsable, EstPersonnel
from .serializers import (
    ChangementMotDePasseSerializer,
    UtilisateurCreationSerializer,
    UtilisateurSerializer,
)


class MoiView(APIView):
    """Profil de l'utilisateur connecté."""

    @extend_schema(responses=UtilisateurSerializer)
    def get(self, request):
        return Response(UtilisateurSerializer(request.user).data)


class ChangerMotDePasseView(APIView):
    @extend_schema(request=ChangementMotDePasseSerializer, responses={204: None})
    def post(self, request):
        s = ChangementMotDePasseSerializer(data=request.data, context={"request": request})
        s.is_valid(raise_exception=True)
        request.user.set_password(s.validated_data["nouveau"])
        request.user.save(update_fields=["password"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class UtilisateurViewSet(viewsets.ModelViewSet):
    """Gestion des comptes.

    - Lecture : personnel (pour choisir un emprunteur depuis l'app).
    - Création/modification : admin ou responsable.
    - Suppression : désactivée, on désactive le compte (`is_active`) pour garder l'historique.
    """

    queryset = Utilisateur.objects.all()
    filterset_fields = ["role", "is_active"]
    search_fields = ["username", "first_name", "last_name", "matricule"]
    http_method_names = ["get", "post", "patch", "head", "options"]

    def get_serializer_class(self):
        if self.action == "create":
            return UtilisateurCreationSerializer
        return UtilisateurSerializer

    def get_permissions(self):
        if self.action in ("list", "retrieve"):
            return [EstPersonnel()]
        return [EstAdminOuResponsable()]

    def perform_create(self, serializer):
        # Un responsable ne peut pas créer d'administrateur.
        if serializer.validated_data.get("role") == Utilisateur.Role.ADMIN and not self.request.user.est_admin:
            raise PermissionDenied("Seul un administrateur peut créer un administrateur.")
        serializer.save()

    def perform_update(self, serializer):
        if not self.request.user.est_admin and (
            serializer.validated_data.get("role") == Utilisateur.Role.ADMIN
            or serializer.instance.role == Utilisateur.Role.ADMIN
        ):
            raise PermissionDenied("Seul un administrateur peut modifier un administrateur.")
        serializer.save()

    @action(detail=True, methods=["post"], permission_classes=[EstAdminOuResponsable])
    def desactiver(self, request, pk=None):
        utilisateur = self.get_object()
        if utilisateur == request.user:
            return Response({"detail": "Vous ne pouvez pas désactiver votre propre compte."},
                            status=status.HTTP_400_BAD_REQUEST)
        utilisateur.is_active = False
        utilisateur.save(update_fields=["is_active"])
        return Response(UtilisateurSerializer(utilisateur).data)
