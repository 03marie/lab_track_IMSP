from rest_framework.permissions import SAFE_METHODS, BasePermission


class EstPersonnel(BasePermission):
    """Admin, responsable ou technicien (les utilisateurs de l'app mobile en v1)."""

    message = "Accès réservé au personnel des laboratoires."

    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.est_personnel)


class EstAdminOuResponsable(BasePermission):
    message = "Action réservée à l'administrateur ou au responsable de laboratoire."

    def has_permission(self, request, view):
        u = request.user
        return bool(u and u.is_authenticated and u.peut_gerer_equipements)


class LectureSeulePourPersonnelEcritureGestionnaire(BasePermission):
    """Lecture : tout le personnel. Écriture : admin ou responsable."""

    message = "Seuls l'administrateur et le responsable peuvent modifier ces données."

    def has_permission(self, request, view):
        u = request.user
        if not (u and u.is_authenticated and u.est_personnel):
            return False
        if request.method in SAFE_METHODS:
            return True
        return u.peut_gerer_equipements
