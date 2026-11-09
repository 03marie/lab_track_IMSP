// Modèles : traduction des réponses JSON de l'API en objets Dart typés.

class Utilisateur {
  const Utilisateur({
    required this.id,
    required this.username,
    required this.prenom,
    required this.nom,
    required this.role,
    required this.roleLibelle,
    this.email = '',
    this.matricule = '',
    this.telephone = '',
  });

  final int id;
  final String username;
  final String prenom;
  final String nom;
  final String role;
  final String roleLibelle;
  final String email;
  final String matricule;
  final String telephone;

  String get nomComplet => [prenom, nom].where((s) => s.isNotEmpty).join(' ').trim().isEmpty
      ? username
      : [prenom, nom].where((s) => s.isNotEmpty).join(' ');

  String get initiales {
    final parties = nomComplet.split(' ').where((s) => s.isNotEmpty).take(2);
    return parties.map((p) => p[0].toUpperCase()).join();
  }

  bool get peutGerer => role == 'admin' || role == 'responsable';

  factory Utilisateur.fromJson(Map<String, dynamic> j) => Utilisateur(
    id: j['id'] as int,
    username: j['username'] as String,
    prenom: (j['first_name'] ?? '') as String,
    nom: (j['last_name'] ?? '') as String,
    role: j['role'] as String,
    roleLibelle: (j['role_libelle'] ?? j['role']) as String,
    email: (j['email'] ?? '') as String,
    matricule: (j['matricule'] ?? '') as String,
    telephone: (j['telephone'] ?? '') as String,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'first_name': prenom,
    'last_name': nom,
    'role': role,
    'role_libelle': roleLibelle,
    'email': email,
    'matricule': matricule,
    'telephone': telephone,
  };
}

class Equipement {
  const Equipement({
    required this.id,
    required this.code,
    required this.nom,
    required this.categorieNom,
    required this.laboratoireId,
    required this.laboratoireNom,
    required this.etat,
    required this.statut,
    this.emplacement = '',
    this.marque = '',
    this.modele = '',
    this.numeroSerie = '',
    this.description = '',
    this.dateAcquisition,
    this.photo,
    this.creeLe,
  });

  final int id;
  final String code;
  final String nom;
  final String categorieNom;
  final int laboratoireId;
  final String laboratoireNom;
  final String etat;
  final String statut;
  final String emplacement;
  final String marque;
  final String modele;
  final String numeroSerie;
  final String description;
  final DateTime? dateAcquisition;
  final String? photo;
  final DateTime? creeLe;

  String get marqueModele => [marque, modele].where((s) => s.isNotEmpty).join(' · ');

  factory Equipement.fromJson(Map<String, dynamic> j) => Equipement(
    id: j['id'] as int,
    code: (j['code'] ?? '') as String,
    nom: j['nom'] as String,
    categorieNom: (j['categorie_nom'] ?? '') as String,
    laboratoireId: j['laboratoire'] as int,
    laboratoireNom: (j['laboratoire_nom'] ?? '') as String,
    etat: j['etat'] as String,
    statut: j['statut'] as String,
    emplacement: (j['emplacement'] ?? '') as String,
    marque: (j['marque'] ?? '') as String,
    modele: (j['modele'] ?? '') as String,
    numeroSerie: (j['numero_serie'] ?? '') as String,
    description: (j['description'] ?? '') as String,
    dateAcquisition: DateTime.tryParse((j['date_acquisition'] ?? '') as String),
    photo: j['photo'] as String?,
    creeLe: DateTime.tryParse((j['cree_le'] ?? '') as String)?.toLocal(),
  );
}

class Mouvement {
  const Mouvement({required this.id, required this.type, required this.auteur, required this.details, required this.date});

  final int id;
  final String type;
  final String auteur;
  final String details;
  final DateTime date;

  factory Mouvement.fromJson(Map<String, dynamic> j) => Mouvement(
    id: j['id'] as int,
    type: j['type'] as String,
    auteur: (j['auteur_nom'] ?? '') as String,
    details: (j['details'] ?? '') as String,
    date: DateTime.parse(j['date'] as String).toLocal(),
  );
}

class Laboratoire {
  const Laboratoire({
    required this.id,
    required this.code,
    required this.nom,
    required this.localisation,
    required this.nbEquipements,
  });

  final int id;
  final String code;
  final String nom;
  final String localisation;
  final int nbEquipements;

  factory Laboratoire.fromJson(Map<String, dynamic> j) => Laboratoire(
    id: j['id'] as int,
    code: j['code'] as String,
    nom: j['nom'] as String,
    localisation: (j['localisation'] ?? '') as String,
    nbEquipements: (j['nb_equipements'] ?? 0) as int,
  );
}

class Statistiques {
  const Statistiques({required this.total, required this.parStatut});

  final int total;
  final Map<String, int> parStatut;

  int operator [](String statut) => parStatut[statut] ?? 0;

  factory Statistiques.fromJson(Map<String, dynamic> j) => Statistiques(
    total: j['total'] as int,
    parStatut: (j['par_statut'] as Map<String, dynamic>).map((k, v) => MapEntry(k, v as int)),
  );
}

/// Page de résultats paginés de DRF.
class PageResultats<T> {
  const PageResultats({required this.total, required this.elements, required this.suivante});

  final int total;
  final List<T> elements;
  final bool suivante;

  factory PageResultats.fromJson(Map<String, dynamic> j, T Function(Map<String, dynamic>) convertir) => PageResultats(
    total: j['count'] as int,
    elements: (j['results'] as List).cast<Map<String, dynamic>>().map(convertir).toList(),
    suivante: j['next'] != null,
  );
}
