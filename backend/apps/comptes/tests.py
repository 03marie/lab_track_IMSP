import os
import shutil
import tempfile
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from PIL import Image
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

    def test_le_profil_indique_les_laboratoires_geres(self):
        from apps.equipements.models import Laboratoire

        labo = Laboratoire.objects.create(code="ELEC", nom="Électronique")
        labo.responsables.add(self.resp)
        r = self.client_de(self.resp).get("/api/v1/auth/moi/")
        self.assertEqual(r.data["laboratoires_geres"], [labo.pk])
        self.assertEqual(self.client_de(self.tech).get("/api/v1/auth/moi/").data["laboratoires_geres"], [])


def image_test(nom="photo.jpg", taille=(40, 40), couleur="blue", format="JPEG"):
    tampon = BytesIO()
    Image.new("RGB", taille, couleur).save(tampon, format=format)
    return SimpleUploadedFile(nom, tampon.getvalue(), content_type=f"image/{format.lower()}")


class ProfilTests(TestCase):
    def setUp(self):
        self.dossier = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dossier, ignore_errors=True)
        reglage = override_settings(MEDIA_ROOT=self.dossier)
        reglage.enable()
        self.addCleanup(reglage.disable)
        self.u = Utilisateur.objects.create_user("koffi", password="motdepasse-123", role="responsable",
                                                 first_name="Koffi", last_name="Mensah", matricule="R-01")
        self.client = APIClient()
        self.client.force_authenticate(self.u)

    def test_le_profil_n_a_pas_de_photo_au_depart(self):
        self.assertIsNone(self.client.get("/api/v1/auth/moi/").data["photo"])

    def test_modification_des_coordonnees(self):
        r = self.client.patch("/api/v1/auth/moi/", {"email": "koffi@imsp.bj", "telephone": "0197000000"})
        self.assertEqual(r.status_code, 200, r.data)
        self.u.refresh_from_db()
        self.assertEqual((self.u.email, self.u.telephone), ("koffi@imsp.bj", "0197000000"))

    def test_nom_role_et_matricule_ne_sont_pas_modifiables_par_soi_meme(self):
        r = self.client.patch("/api/v1/auth/moi/", {"role": "admin", "first_name": "Pirate", "matricule": "X", "is_superuser": True})
        self.assertEqual(r.status_code, 200)
        self.u.refresh_from_db()
        self.assertEqual((self.u.role, self.u.first_name, self.u.matricule, self.u.is_superuser), ("responsable", "Koffi", "R-01", False))

    def test_envoi_d_une_photo(self):
        r = self.client.patch("/api/v1/auth/moi/", {"photo": image_test()}, format="multipart")
        self.assertEqual(r.status_code, 200, r.data)
        self.assertTrue(r.data["photo"].endswith(".jpg"))
        self.assertIn("/profils/", r.data["photo"])
        self.u.refresh_from_db()
        self.assertTrue(os.path.exists(self.u.photo.path))

    def test_remplacer_la_photo_supprime_l_ancienne(self):
        self.client.patch("/api/v1/auth/moi/", {"photo": image_test("a.jpg")}, format="multipart")
        self.u.refresh_from_db()
        ancien = self.u.photo.path
        self.client.patch("/api/v1/auth/moi/", {"photo": image_test("b.jpg", couleur="red")}, format="multipart")
        self.u.refresh_from_db()
        self.assertNotEqual(self.u.photo.path, ancien)
        self.assertFalse(os.path.exists(ancien))
        self.assertTrue(os.path.exists(self.u.photo.path))

    def test_deux_envois_donnent_deux_adresses_differentes(self):
        a = self.client.patch("/api/v1/auth/moi/", {"photo": image_test("p.jpg")}, format="multipart").data["photo"]
        b = self.client.patch("/api/v1/auth/moi/", {"photo": image_test("p.jpg")}, format="multipart").data["photo"]
        self.assertNotEqual(a, b)

    def test_fichier_qui_n_est_pas_une_image_refuse(self):
        faux = SimpleUploadedFile("virus.jpg", b"ceci n'est pas une image", content_type="image/jpeg")
        r = self.client.patch("/api/v1/auth/moi/", {"photo": faux}, format="multipart")
        self.assertEqual(r.status_code, 400)

    def test_photo_trop_lourde_refusee(self):
        gros = SimpleUploadedFile("gros.jpg", image_test().read() + b"0" * (5 * 1024 * 1024 + 1), content_type="image/jpeg")
        r = self.client.patch("/api/v1/auth/moi/", {"photo": gros}, format="multipart")
        self.assertEqual(r.status_code, 400)
        self.assertIn("5 Mo", str(r.data["photo"]))

    def test_suppression_de_la_photo(self):
        self.client.patch("/api/v1/auth/moi/", {"photo": image_test()}, format="multipart")
        self.u.refresh_from_db()
        chemin = self.u.photo.path
        r = self.client.delete("/api/v1/auth/moi/photo/")
        self.assertEqual(r.status_code, 200)
        self.assertIsNone(r.data["photo"])
        self.assertFalse(os.path.exists(chemin))

    def test_la_photo_apparait_dans_la_liste_des_utilisateurs(self):
        self.client.patch("/api/v1/auth/moi/", {"photo": image_test()}, format="multipart")
        r = self.client.get("/api/v1/utilisateurs/")
        moi = next(x for x in r.data["results"] if x["username"] == "koffi")
        self.assertIn("/profils/", moi["photo"])

    def test_profil_refuse_sans_connexion(self):
        self.assertEqual(APIClient().patch("/api/v1/auth/moi/", {"email": "x@y.z"}).status_code, 401)
