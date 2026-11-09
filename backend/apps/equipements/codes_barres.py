"""Génération des codes-barres Code 128 : image PNG d'un équipement et planches d'étiquettes PDF."""

from io import BytesIO

import barcode
from barcode.writer import ImageWriter
from reportlab.graphics.barcode import code128
from reportlab.lib.pagesizes import A4
from reportlab.lib.units import mm
from reportlab.pdfgen import canvas

# Planche A4 : 3 colonnes x 8 lignes = 24 étiquettes (63,5 x 33,9 mm, format courant).
COLONNES, LIGNES = 3, 8
LARGEUR_ETIQUETTE, HAUTEUR_ETIQUETTE = 63.5 * mm, 33.9 * mm


def png_code128(code: str) -> bytes:
    """Image PNG du code-barres (avec le texte lisible dessous)."""
    rendu = barcode.get("code128", code, writer=ImageWriter())
    tampon = BytesIO()
    rendu.write(tampon, options={"module_height": 14.0, "quiet_zone": 4.0, "font_size": 9, "text_distance": 3.0})
    return tampon.getvalue()


def pdf_etiquettes(equipements, colonne_depart: int = 0) -> bytes:
    """Planche(s) A4 d'étiquettes : nom, laboratoire et code-barres vectoriel Code 128.

    `colonne_depart` permet de réutiliser une feuille déjà entamée (nombre d'emplacements à sauter).
    """
    tampon = BytesIO()
    page = canvas.Canvas(tampon, pagesize=A4)
    largeur_page, hauteur_page = A4
    marge_x = (largeur_page - COLONNES * LARGEUR_ETIQUETTE) / 2
    marge_y = (hauteur_page - LIGNES * HAUTEUR_ETIQUETTE) / 2

    emplacement = max(colonne_depart, 0)
    for equipement in equipements:
        if emplacement and emplacement % (COLONNES * LIGNES) == 0:
            page.showPage()
        position = emplacement % (COLONNES * LIGNES)
        ligne, colonne = divmod(position, COLONNES)
        x = marge_x + colonne * LARGEUR_ETIQUETTE
        y = hauteur_page - marge_y - (ligne + 1) * HAUTEUR_ETIQUETTE
        _dessiner_etiquette(page, equipement, x, y)
        emplacement += 1

    page.save()
    return tampon.getvalue()


def _dessiner_etiquette(page, equipement, x: float, y: float) -> None:
    marge = 3 * mm
    page.setFont("Helvetica-Bold", 7)
    page.drawString(x + marge, y + HAUTEUR_ETIQUETTE - 5 * mm, f"IMSP · {equipement.laboratoire.nom}"[:38])
    page.setFont("Helvetica", 7)
    page.drawString(x + marge, y + HAUTEUR_ETIQUETTE - 9 * mm, equipement.nom[:42])

    largeur_utile = LARGEUR_ETIQUETTE - 2 * marge
    # barWidth choisi pour tenir dans l'étiquette (Code 128 : ~11 modules par caractère + démarrage/arrêt).
    nb_modules = 11 * len(equipement.code) + 35
    largeur_barre = min(0.5 * mm, largeur_utile / nb_modules)
    barres = code128.Code128(
        equipement.code, barHeight=14 * mm, barWidth=largeur_barre, humanReadable=True, quiet=False
    )
    barres.drawOn(page, x + marge + (largeur_utile - barres.width) / 2, y + 3 * mm)
