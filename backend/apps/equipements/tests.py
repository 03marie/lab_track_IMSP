import shutil
import tempfile
from io import BytesIO

from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import TestCase, override_settings
from PIL import Image
from rest_framework.test import APIClient

from apps.comptes.models import Utilisateur

from .models import Categorie, Equipement, Laboratoire, Mouvement, enregistrer_mouvement


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


class SuppressionLaboratoireTests(BaseAPITest):
    def test_admin_supprime_un_laboratoire_vide(self):
        r = self.client_de(self.admin).delete(f"/api/v1/laboratoires/{self.labo_info.pk}/")
        self.assertEqual(r.status_code, 204)
        self.assertFalse(Laboratoire.objects.filter(pk=self.labo_info.pk).exists())

    def test_laboratoire_non_vide_refuse_avec_message(self):
        Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        r = self.client_de(self.admin).delete(f"/api/v1/laboratoires/{self.labo_elec.pk}/")
        self.assertEqual(r.status_code, 409)
        self.assertIn("contient encore 1 équipement", r.data["detail"])
        self.assertTrue(Laboratoire.objects.filter(pk=self.labo_elec.pk).exists())

    def test_les_equipements_retires_comptent_dans_le_refus(self):
        Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec,
                                  statut=Equipement.Statut.RETIRE)
        r = self.client_de(self.admin).delete(f"/api/v1/laboratoires/{self.labo_elec.pk}/")
        self.assertEqual(r.status_code, 409)
        self.assertIn("1 retiré", r.data["detail"])

    def test_un_responsable_ne_supprime_pas_de_laboratoire(self):
        r = self.client_de(self.resp_elec).delete(f"/api/v1/laboratoires/{self.labo_info.pk}/")
        self.assertEqual(r.status_code, 403)

    def test_creation_normalise_le_code_en_majuscules(self):
        r = self.client_de(self.admin).post(
            "/api/v1/laboratoires/", {"code": " chim ", "nom": "Chimie", "localisation": "Bât. C"}
        )
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data["code"], "CHIM")

    def test_nb_equipements_ignore_les_retires(self):
        Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec)
        Equipement.objects.create(nom="B", categorie=self.categorie, laboratoire=self.labo_elec,
                                  statut=Equipement.Statut.RETIRE)
        r = self.client_de(self.technicien).get("/api/v1/laboratoires/")
        elec = next(l for l in r.data["results"] if l["code"] == "ELEC")
        self.assertEqual(elec["nb_equipements"], 1)


class SuppressionEquipementTests(BaseAPITest):
    def creer(self, **extra):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec, **extra)
        enregistrer_mouvement(e, Mouvement.Type.CREATION, self.resp_elec, "créé")
        return e

    def test_equipement_jamais_utilise_supprime_definitivement(self):
        e = self.creer()
        r = self.client_de(self.resp_elec).delete(f"/api/v1/equipements/{e.pk}/")
        self.assertEqual(r.status_code, 204)
        self.assertFalse(Equipement.objects.filter(pk=e.pk).exists())

    def test_une_modification_ne_compte_pas_comme_historique(self):
        e = self.creer()
        enregistrer_mouvement(e, Mouvement.Type.MODIFICATION, self.resp_elec, "emplacement")
        r = self.client_de(self.resp_elec).delete(f"/api/v1/equipements/{e.pk}/")
        self.assertEqual(r.status_code, 204)

    def test_equipement_qui_a_servi_est_refuse_et_conserve(self):
        e = self.creer()
        enregistrer_mouvement(e, Mouvement.Type.EMPRUNT, self.resp_elec, "prêté")
        r = self.client_de(self.resp_elec).delete(f"/api/v1/equipements/{e.pk}/")
        self.assertEqual(r.status_code, 409)
        self.assertIn("Retirez-le du parc", r.data["detail"])
        self.assertTrue(Equipement.objects.filter(pk=e.pk).exists())

    def test_equipement_emprunte_est_refuse(self):
        e = self.creer(statut=Equipement.Statut.EMPRUNTE)
        r = self.client_de(self.admin).delete(f"/api/v1/equipements/{e.pk}/")
        self.assertEqual(r.status_code, 409)

    def test_responsable_d_un_autre_labo_refuse(self):
        e = self.creer()
        autre = Utilisateur.objects.create_user("resp_info", password="motdepasse-123", role="responsable")
        self.assertEqual(self.client_de(autre).delete(f"/api/v1/equipements/{e.pk}/").status_code, 403)

    def test_technicien_ne_supprime_pas(self):
        e = self.creer()
        self.assertEqual(self.client_de(self.technicien).delete(f"/api/v1/equipements/{e.pk}/").status_code, 403)


class EquipementsRetiresTests(BaseAPITest):
    def setUp(self):
        self.actif = Equipement.objects.create(nom="Actif", categorie=self.categorie, laboratoire=self.labo_elec)
        self.retire = Equipement.objects.create(nom="Retiré", categorie=self.categorie, laboratoire=self.labo_elec,
                                                statut=Equipement.Statut.RETIRE)
        self.client = self.client_de(self.technicien)

    def test_la_liste_masque_les_retires_par_defaut(self):
        r = self.client.get("/api/v1/equipements/")
        self.assertEqual([e["nom"] for e in r.data["results"]], ["Actif"])

    def test_on_les_retrouve_avec_le_filtre_statut(self):
        r = self.client.get("/api/v1/equipements/?statut=retire")
        self.assertEqual([e["nom"] for e in r.data["results"]], ["Retiré"])

    def test_la_fiche_d_un_retire_reste_consultable(self):
        self.assertEqual(self.client.get(f"/api/v1/equipements/{self.retire.pk}/").status_code, 200)
        self.assertEqual(self.client.get(f"/api/v1/equipements/par-code/{self.retire.code}/").status_code, 200)

    def test_les_etiquettes_d_un_labo_ignorent_les_retires(self):
        r = self.client.get(f"/api/v1/equipements/etiquettes/?laboratoire={self.labo_elec.pk}")
        self.assertEqual(r.status_code, 200)

    def test_etiquette_d_un_retire_possible_par_id(self):
        r = self.client.get(f"/api/v1/equipements/etiquettes/?ids={self.retire.pk}")
        self.assertEqual(r.status_code, 200)

    def test_total_exclut_les_retires_mais_ils_sont_comptes_a_part(self):
        r = self.client.get("/api/v1/equipements/statistiques/")
        self.assertEqual(r.data["total"], 1)
        self.assertEqual(r.data["par_statut"]["retire"], 1)


class FormulaireMobileTests(BaseAPITest):
    """Reproduit exactement ce qu'envoie l'application mobile : un formulaire multipart."""

    def setUp(self):
        self.dossier = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, self.dossier, ignore_errors=True)
        reglage = override_settings(MEDIA_ROOT=self.dossier)
        reglage.enable()
        self.addCleanup(reglage.disable)

    def champs(self, **extra):
        champs = {
            "nom": "Multimètre", "categorie": self.categorie.pk, "laboratoire": self.labo_elec.pk,
            "emplacement": "", "marque": "", "modele": "", "numero_serie": "", "description": "",
            "date_acquisition": "",   # l'app envoie une chaîne vide quand la date n'est pas renseignée
        }
        champs.update(extra)
        return champs

    def photo(self):
        tampon = BytesIO()
        Image.new("RGB", (30, 30), "green").save(tampon, format="JPEG")
        return SimpleUploadedFile("photo_1.jpg", tampon.getvalue(), content_type="image/jpeg")

    def test_creation_multipart_sans_date_ni_photo(self):
        r = self.client_de(self.resp_elec).post("/api/v1/equipements/", self.champs(), format="multipart")
        self.assertEqual(r.status_code, 201, r.data)
        self.assertIsNone(r.data["date_acquisition"])
        self.assertTrue(r.data["code"].startswith("IMSP-EQ-"))

    def test_creation_multipart_avec_date_et_photo(self):
        r = self.client_de(self.resp_elec).post(
            "/api/v1/equipements/", self.champs(date_acquisition="2024-03-14", photo=self.photo()), format="multipart"
        )
        self.assertEqual(r.status_code, 201, r.data)
        self.assertEqual(r.data["date_acquisition"], "2024-03-14")
        self.assertIn("/equipements/", r.data["photo"])

    def test_modification_multipart_efface_la_date(self):
        e = Equipement.objects.create(nom="A", categorie=self.categorie, laboratoire=self.labo_elec, date_acquisition="2024-01-01")
        r = self.client_de(self.admin).patch(f"/api/v1/equipements/{e.pk}/", self.champs(nom="B"), format="multipart")
        self.assertEqual(r.status_code, 200, r.data)
        e.refresh_from_db()
        self.assertEqual(e.nom, "B")
        self.assertIsNone(e.date_acquisition)

    def test_nom_vide_refuse_avec_message_sur_le_champ(self):
        r = self.client_de(self.resp_elec).post("/api/v1/equipements/", self.champs(nom=""), format="multipart")
        self.assertEqual(r.status_code, 400)
        self.assertIn("nom", r.data)

    def test_creation_puis_etiquette_pdf_comme_dans_l_app(self):
        client = self.client_de(self.resp_elec)
        cree = client.post("/api/v1/equipements/", self.champs(), format="multipart").data
        pdf = client.get(f"/api/v1/equipements/etiquettes/?ids={cree['id']}")
        self.assertEqual(pdf.status_code, 200)
        self.assertTrue(pdf.content.startswith(b"%PDF"))
