"""Configuration Django de LabTrack.

Les valeurs sensibles ou propres à la machine viennent de l'environnement
(ou d'un fichier `.env` placé à côté de manage.py, voir `.env.example`).
"""

import os
from datetime import timedelta
from pathlib import Path

BASE_DIR = Path(__file__).resolve().parent.parent


def _charger_env(chemin: Path) -> None:
    """Charge un fichier .env simple (CLE=valeur) sans écraser l'environnement."""
    if not chemin.exists():
        return
    for ligne in chemin.read_text(encoding="utf-8").splitlines():
        ligne = ligne.strip()
        if not ligne or ligne.startswith("#") or "=" not in ligne:
            continue
        cle, _, valeur = ligne.partition("=")
        os.environ.setdefault(cle.strip(), valeur.strip().strip('"').strip("'"))


_charger_env(BASE_DIR / ".env")


def _bool(nom: str, defaut: bool) -> bool:
    return os.environ.get(nom, str(defaut)).lower() in ("1", "true", "oui", "yes")


def _liste(nom: str, defaut: str = "") -> list[str]:
    return [v.strip() for v in os.environ.get(nom, defaut).split(",") if v.strip()]


# --- Sécurité -----------------------------------------------------------------
DEBUG = _bool("DJANGO_DEBUG", True)

SECRET_KEY = os.environ.get("DJANGO_SECRET_KEY", "")
if not SECRET_KEY:
    if DEBUG:
        SECRET_KEY = "dev-only-insecure-key-ne-jamais-utiliser-en-production"
    else:
        raise RuntimeError("DJANGO_SECRET_KEY doit être défini quand DJANGO_DEBUG=False")

# En démo, le téléphone joint le PC par son IP locale : on accepte tout hôte en DEBUG.
ALLOWED_HOSTS = ["*"] if DEBUG else _liste("DJANGO_ALLOWED_HOSTS", "localhost,127.0.0.1")

# --- Applications -------------------------------------------------------------
INSTALLED_APPS = [
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # Tiers
    "rest_framework",
    "rest_framework_simplejwt",
    "corsheaders",
    "django_filters",
    "drf_spectacular",
    # LabTrack
    "apps.comptes",
    "apps.equipements",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "corsheaders.middleware.CorsMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
]

ROOT_URLCONF = "config.urls"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

# --- Base de données ----------------------------------------------------------
# PostgreSQL uniquement, dans le conteneur `db` du docker-compose (aucune base sur le PC hôte).
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("DB_NAME", "labtrack"),
        "USER": os.environ.get("DB_USER", "labtrack"),
        "PASSWORD": os.environ.get("DB_PASSWORD", ""),
        "HOST": os.environ.get("DB_HOST", "db"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    }
}

# --- Utilisateurs et mots de passe -------------------------------------------
AUTH_USER_MODEL = "comptes.Utilisateur"

AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {"NAME": "django.contrib.auth.password_validation.MinimumLengthValidator"},
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]

# --- Internationalisation -----------------------------------------------------
LANGUAGE_CODE = "fr-fr"
TIME_ZONE = os.environ.get("DJANGO_TIME_ZONE", "Africa/Porto-Novo")
USE_I18N = True
USE_TZ = True

# --- Fichiers statiques et médias --------------------------------------------
STATIC_URL = "static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
MEDIA_URL = "media/"
MEDIA_ROOT = BASE_DIR / "media"

DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --- API REST -----------------------------------------------------------------
REST_FRAMEWORK = {
    "DEFAULT_AUTHENTICATION_CLASSES": (
        "rest_framework_simplejwt.authentication.JWTAuthentication",
    ),
    "DEFAULT_PERMISSION_CLASSES": ("rest_framework.permissions.IsAuthenticated",),
    "DEFAULT_FILTER_BACKENDS": (
        "django_filters.rest_framework.DjangoFilterBackend",
        "rest_framework.filters.SearchFilter",
        "rest_framework.filters.OrderingFilter",
    ),
    "DEFAULT_PAGINATION_CLASS": "rest_framework.pagination.PageNumberPagination",
    "PAGE_SIZE": 50,
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
}

SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(hours=8),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=7),
}

SPECTACULAR_SETTINGS = {
    "TITLE": "LabTrack API",
    "DESCRIPTION": "Gestion et traçabilité des équipements de laboratoire de l'IMSP.",
    "VERSION": "1.0.0",
    "SERVE_INCLUDE_SCHEMA": False,
}

# L'app mobile native n'est pas soumise au CORS ; on l'ouvre en DEBUG pour les tests navigateur.
CORS_ALLOW_ALL_ORIGINS = DEBUG
CORS_ALLOWED_ORIGINS = _liste("CORS_ALLOWED_ORIGINS")

# --- LabTrack -----------------------------------------------------------------
# Préfixe des codes-barres : IMSP-EQ-0001
CODE_PREFIXE = os.environ.get("LABTRACK_CODE_PREFIXE", "IMSP-EQ-")
CODE_LONGUEUR = 4
