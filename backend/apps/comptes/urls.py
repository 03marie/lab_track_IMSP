from django.urls import include, path
from rest_framework.routers import DefaultRouter
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView

from .views import ChangerMotDePasseView, MoiView, UtilisateurViewSet

router = DefaultRouter()
router.register("utilisateurs", UtilisateurViewSet, basename="utilisateur")

urlpatterns = [
    path("auth/connexion/", TokenObtainPairView.as_view(), name="connexion"),
    path("auth/rafraichir/", TokenRefreshView.as_view(), name="rafraichir"),
    path("auth/moi/", MoiView.as_view(), name="moi"),
    path("auth/mot-de-passe/", ChangerMotDePasseView.as_view(), name="mot-de-passe"),
    path("", include(router.urls)),
]
