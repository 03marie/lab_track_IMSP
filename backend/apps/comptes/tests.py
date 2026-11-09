from django.test import TestCase
from rest_framework.test import APIClient

from .models import Utilisateur


class UtilisateursAPITests(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.admin = Utilisateur.objects.create_user("admin1", password="motdepasse-123", role="admin")
        cls.resp = Utilisateur.objects.create_user("resp1", password="motdepasse-123", role="responsable")
        cls.tech = Utilisateur.objects.create_user("tech1", password="motdepasse-123", role="technicien")

    def client_de(self, utilisateur):
        client = APIClient()
        client.force_authenticate(utilisateur)
        return client

    def creation(self, **extra):
        donnees = {"username": "nouveau", "password": "Un-Bon-Mot-De-Passe-9", "role": "etudiant",
                   "first_name": "Awa", "last_name": "Diallo", "matricule": "E123"}
        donnees.update(extra)
        return donnees

    def test_admin_cree_un_utilisateur_et_le_mot_de_passe_est_hache(self):
        r = self.client_de(self.admin).post("/api/v1/utilisateurs/", self.creation())
        self.assertEqual(r.status_code, 201, r.data)
        self.assertNotIn("password", r.data)
        u = Utilisateur.objects.get(username="nouveau")
        self.assertTrue(u.check_password("Un-Bon-Mot-De-Passe-9"))
        self.assertNotEqual(u.password, "Un-Bon-Mot-De-Passe-9")

    def test_mot_de_passe_faible_refuse(self):
        r = self.client_de(self.admin).post("/api/v1/utilisateurs/", self.creation(password="12345678"))
        self.assertEqual(r.status_code, 400)

    def test_technicien_ne_peut_pas_creer(self):
        r = self.client_de(self.tech).post("/api/v1/utilisateurs/", self.creation())
        self.assertEqual(r.status_code, 403)

    def test_technicien_peut_lister(self):
        self.assertEqual(self.client_de(self.tech).get("/api/v1/utilisateurs/").status_code, 200)

    def test_responsable_ne_cree_pas_d_administrateur(self):
        r = self.client_de(self.resp).post("/api/v1/utilisateurs/", self.creation(role="admin"))
        self.assertEqual(r.status_code, 403)

    def test_responsable_ne_modifie_pas_un_administrateur(self):
        r = self.client_de(self.resp).patch(f"/api/v1/utilisateurs/{self.admin.pk}/", {"telephone": "0102"})
        self.assertEqual(r.status_code, 403)

    def test_desactivation(self):
        r = self.client_de(self.admin).post(f"/api/v1/utilisateurs/{self.tech.pk}/desactiver/")
        self.assertEqual(r.status_code, 200)
        self.tech.refresh_from_db()
        self.assertFalse(self.tech.is_active)

    def test_on_ne_se_desactive_pas_soi_meme(self):
        r = self.client_de(self.admin).post(f"/api/v1/utilisateurs/{self.admin.pk}/desactiver/")
        self.assertEqual(r.status_code, 400)

    def test_compte_desactive_ne_peut_plus_se_connecter(self):
        Utilisateur.objects.filter(pk=self.tech.pk).update(is_active=False)
        r = APIClient().post("/api/v1/auth/connexion/", {"username": "tech1", "password": "motdepasse-123"})
        self.assertEqual(r.status_code, 401)

    def test_changement_de_mot_de_passe(self):
        client = self.client_de(self.tech)
        r = client.post("/api/v1/auth/mot-de-passe/", {"ancien": "faux", "nouveau": "Nouveau-Mdp-2026!"})
        self.assertEqual(r.status_code, 400)
        r = client.post("/api/v1/auth/mot-de-passe/", {"ancien": "motdepasse-123", "nouveau": "Nouveau-Mdp-2026!"})
        self.assertEqual(r.status_code, 204)
        self.tech.refresh_from_db()
        self.assertTrue(self.tech.check_password("Nouveau-Mdp-2026!"))
