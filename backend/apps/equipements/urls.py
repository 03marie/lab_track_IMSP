from django.urls import include, path
from rest_framework.routers import DefaultRouter

from .views import CategorieViewSet, EquipementViewSet, LaboratoireViewSet

router = DefaultRouter()
router.register("laboratoires", LaboratoireViewSet, basename="laboratoire")
router.register("categories", CategorieViewSet, basename="categorie")
router.register("equipements", EquipementViewSet, basename="equipement")

urlpatterns = [path("", include(router.urls))]
