from django.test import TestCase, override_settings
from rest_framework.test import APIClient

from apps.comptes.models import Utilisateur

from .models import Categorie, Equipement, Laboratoire, Mouvement


class BaseAPITest(TestCase):
    @classmethod
    def setUpTestData(cls):
        cls.admin = Utilisateur.objects.create_user("admin1", password="motdepasse-123", role="admin")
        cls.resp_elec = Utilisateur.objects.create_user("resp_elec", password="motdepasse-123", role="responsable")
        cls.technicien = Utilisateur.objects.create_user("tech1", password="motdepasse-123", role="technicien")
        cls.etudiant = Utilisateur.objects.create_user("etu1", password="motdepasse-123", role="etudiant")

        cls.labo_elec = Laboratoire.objects.create(code="ELEC", nom="Électronique")
        cls.labo_info = Laboratoire.objects.create(code="INFO", nom="Informatique")
        cls.labo_elec.responsables.add(cls.resp_elec)
        cls.categorie = Categorie.objects.create(nom="Instruments de mesure")

    def client_de(self, utilisateur):
        client = APIClient()
        client.force_authenticate(utilisateur)
        return client

    def donnees_equipement(self, **extra):
        donnees = {"nom": "Multimètre", "categorie": self.categorie.pk, "laboratoire": self.labo_elec.pk}
        donnees.update(extra)
        return donnees


class CodeEquipementTests(BaseAPITest):
    def test_le_code_est_attribue_automatiquement(self):
        e = Equipement.objects.create(nom="Oscilloscope", categorie=self.categorie, laboratoire=self.labo_elec)
        self.assertEqual(e.code, f"IMSP-EQ-{e.pk:04d}")

    def test_un_code_n_est_jamais_reutilise_apres_suppression(self):
        e1 = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        code1 = e1.code
        e1.delete()
        e2 = Equipement.objects.create(nom="B", categorie=self.categorie, laboratoire=self.labo_elec)
        self.assertNotEqual(e2.code, code1)

    @override_settings(CODE_PREFIXE="LAB-", CODE_LONGUEUR=6)
    def test_prefixe_et_longueur_configurables(self):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        self.assertEqual(e.code, f"LAB-{e.pk:06d}")


class AuthentificationTests(BaseAPITest):
    def test_connexion_renvoie_un_jeton(self):
        r = APIClient().post("/api/v1/auth/connexion/", {"username": "admin1", "password": "motdepasse-123"})
        self.assertEqual(r.status_code, 200)
        self.assertIn("access", r.data)

    def test_mauvais_mot_de_passe(self):
        r = APIClient().post("/api/v1/auth/connexion/", {"username": "admin1", "password": "faux"})
        self.assertEqual(r.status_code, 401)

    def test_api_refusee_sans_jeton(self):
        self.assertEqual(APIClient().get("/api/v1/equipements/").status_code, 401)

    def test_moi_renvoie_le_profil(self):
        r = self.client_de(self.technicien).get("/api/v1/auth/moi/")
        self.assertEqual(r.data["role"], "technicien")

    def test_un_etudiant_n_a_pas_acces_a_l_api_en_v1(self):
        self.assertEqual(self.client_de(self.etudiant).get("/api/v1/equipements/").status_code, 403)


class EquipementAPITests(BaseAPITest):
    def test_responsable_cree_un_equipement_dans_son_labo(self):
        r = self.client_de(self.resp_elec).post("/api/v1/equipements/", self.donnees_equipement())
        self.assertEqual(r.status_code, 201, r.data)
        self.assertTrue(r.data["code"].startswith("IMSP-EQ-"))
        self.assertEqual(r.data["statut"], "disponible")
        mouvement = Mouvement.objects.get(equipement_id=r.data["id"])
        self.assertEqual(mouvement.type, Mouvement.Type.CREATION)
        self.assertEqual(mouvement.auteur, self.resp_elec)

    def test_responsable_ne_peut_pas_creer_dans_un_autre_labo(self):
        r = self.client_de(self.resp_elec).post(
            "/api/v1/equipements/", self.donnees_equipement(laboratoire=self.labo_info.pk)
        )
        self.assertEqual(r.status_code, 403)

    def test_admin_cree_dans_n_importe_quel_labo(self):
        r = self.client_de(self.admin).post(
            "/api/v1/equipements/", self.donnees_equipement(laboratoire=self.labo_info.pk)
        )
        self.assertEqual(r.status_code, 201)

    def test_technicien_lit_mais_n_ecrit_pas(self):
        client = self.client_de(self.technicien)
        self.assertEqual(client.get("/api/v1/equipements/").status_code, 200)
        self.assertEqual(client.post("/api/v1/equipements/", self.donnees_equipement()).status_code, 403)

    def test_code_et_statut_ne_sont_pas_modifiables_par_l_api(self):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        code = e.code
        r = self.client_de(self.admin).patch(
            f"/api/v1/equipements/{e.pk}/", {"code": "PIRATE-1", "statut": "emprunte", "nom": "B"}
        )
        self.assertEqual(r.status_code, 200)
        e.refresh_from_db()
        self.assertEqual((e.code, e.statut, e.nom), (code, "disponible", "B"))

    def test_modification_journalisee(self):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        self.client_de(self.admin).patch(f"/api/v1/equipements/{e.pk}/", {"emplacement": "Armoire A2"})
        m = e.mouvements.get(type=Mouvement.Type.MODIFICATION)
        self.assertIn("emplacement", m.details)

    def test_pas_de_suppression_via_l_api(self):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        self.assertEqual(self.client_de(self.admin).delete(f"/api/v1/equipements/{e.pk}/").status_code, 405)


class RechercheParCodeTests(BaseAPITest):
    def test_scan_retrouve_la_fiche(self):
        e = Equipement.objects.create(nom="Multimètre", categorie=self.categorie, laboratoire=self.labo_elec)
        r = self.client_de(self.technicien).get(f"/api/v1/equipements/par-code/{e.code}/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["nom"], "Multimètre")

    def test_le_code_est_normalise(self):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        r = self.client_de(self.technicien).get(f"/api/v1/equipements/par-code/{e.code.lower()}/")
        self.assertEqual(r.status_code, 200)

    def test_code_inconnu(self):
        r = self.client_de(self.technicien).get("/api/v1/equipements/par-code/IMSP-EQ-9999/")
        self.assertEqual(r.status_code, 404)
        self.assertIn("Aucun équipement", r.data["detail"])


class RetraitTests(BaseAPITest):
    def setUp(self):
        self.e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)

    def test_retrait_avec_motif(self):
        r = self.client_de(self.resp_elec).post(f"/api/v1/equipements/{self.e.pk}/retirer/", {"motif": "Réformé"})
        self.assertEqual(r.status_code, 200)
        self.e.refresh_from_db()
        self.assertEqual(self.e.statut, Equipement.Statut.RETIRE)
        self.assertTrue(self.e.mouvements.filter(type=Mouvement.Type.RETRAIT, details="Réformé").exists())

    def test_motif_obligatoire(self):
        r = self.client_de(self.resp_elec).post(f"/api/v1/equipements/{self.e.pk}/retirer/", {})
        self.assertEqual(r.status_code, 400)

    def test_impossible_si_emprunte(self):
        Equipement.objects.filter(pk=self.e.pk).update(statut=Equipement.Statut.EMPRUNTE)
        r = self.client_de(self.resp_elec).post(f"/api/v1/equipements/{self.e.pk}/retirer/", {"motif": "x"})
        self.assertEqual(r.status_code, 400)

    def test_responsable_d_un_autre_labo_refuse(self):
        autre = Utilisateur.objects.create_user("resp_info", password="motdepasse-123", role="responsable")
        r = self.client_de(autre).post(f"/api/v1/equipements/{self.e.pk}/retirer/", {"motif": "x"})
        self.assertEqual(r.status_code, 403)


class CodesBarresTests(BaseAPITest):
    def setUp(self):
        self.e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)

    def test_image_png(self):
        r = self.client_de(self.technicien).get(f"/api/v1/equipements/{self.e.pk}/code-barres/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r["Content-Type"], "image/png")
        self.assertTrue(r.content.startswith(b"\x89PNG"))

    def test_planche_pdf_par_ids(self):
        r = self.client_de(self.technicien).get(f"/api/v1/equipements/etiquettes/?ids={self.e.pk}")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r["Content-Type"], "application/pdf")
        self.assertTrue(r.content.startswith(b"%PDF"))

    def test_planche_pdf_par_laboratoire(self):
        r = self.client_de(self.technicien).get(f"/api/v1/equipements/etiquettes/?laboratoire={self.labo_elec.pk}")
        self.assertEqual(r.status_code, 200)

    def test_planche_vide_refusee(self):
        r = self.client_de(self.technicien).get(f"/api/v1/equipements/etiquettes/?laboratoire={self.labo_info.pk}")
        self.assertEqual(r.status_code, 400)

    def test_ids_invalides(self):
        r = self.client_de(self.technicien).get("/api/v1/equipements/etiquettes/?ids=abc")
        self.assertEqual(r.status_code, 400)


class StatistiquesTests(BaseAPITest):
    def test_compteurs_par_statut_et_par_labo(self):
        Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        Equipement.objects.create(nom="B", categorie=self.categorie, laboratoire=self.labo_elec,
                                  statut=Equipement.Statut.EMPRUNTE)
        Equipement.objects.create(nom="C", categorie=self.categorie, laboratoire=self.labo_info)
        client = self.client_de(self.technicien)

        r = client.get("/api/v1/equipements/statistiques/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["total"], 3)
        self.assertEqual(r.data["par_statut"]["disponible"], 2)
        self.assertEqual(r.data["par_statut"]["emprunte"], 1)
        self.assertEqual(r.data["par_statut"]["retire"], 0)

        r = client.get(f"/api/v1/equipements/statistiques/?laboratoire={self.labo_info.pk}")
        self.assertEqual(r.data["total"], 1)


class HistoriqueTests(BaseAPITest):
    def test_historique_d_un_equipement(self):
        client = self.client_de(self.admin)
        e_id = client.post("/api/v1/equipements/", self.donnees_equipement()).data["id"]
        r = client.get(f"/api/v1/equipements/{e_id}/historique/")
        self.assertEqual(r.status_code, 200)
        self.assertEqual(r.data["count"], 1)
        self.assertEqual(r.data["results"][0]["type"], "creation")
