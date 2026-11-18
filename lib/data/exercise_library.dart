class Exercise {
  final String id;
  final String name;
  final String muscle;
  final String machine;

  const Exercise(this.id, this.name, this.muscle, this.machine);

  /// Video standard: ricerca YouTube dell'esecuzione corretta.
  String get standardVideoUrl =>
      'https://www.youtube.com/results?search_query=${Uri.encodeComponent('$name esecuzione corretta')}';
}

const machineTypes = [
  'Bilanciere',
  'Manubri',
  'Macchina',
  'Cavi',
  'Multipower',
  'Corpo libero',
  'Kettlebell',
  'Elastici',
];

const exerciseLibrary = <Exercise>[
  // Petto
  Exercise('panca_piana', 'Panca piana', 'Petto', 'Bilanciere'),
  Exercise('panca_inclinata', 'Panca inclinata', 'Petto', 'Bilanciere'),
  Exercise('panca_declinata', 'Panca declinata', 'Petto', 'Bilanciere'),
  Exercise('distensioni_manubri', 'Distensioni con manubri', 'Petto', 'Manubri'),
  Exercise('distensioni_inclinate_manubri', 'Distensioni inclinate con manubri', 'Petto', 'Manubri'),
  Exercise('croci_manubri', 'Croci con manubri', 'Petto', 'Manubri'),
  Exercise('chest_press', 'Chest press', 'Petto', 'Macchina'),
  Exercise('pectoral_machine', 'Pectoral machine', 'Petto', 'Macchina'),
  Exercise('croci_cavi', 'Croci ai cavi', 'Petto', 'Cavi'),
  Exercise('panca_multipower', 'Panca al multipower', 'Petto', 'Multipower'),
  Exercise('piegamenti', 'Piegamenti', 'Petto', 'Corpo libero'),
  Exercise('dip_parallele', 'Dip alle parallele', 'Petto', 'Corpo libero'),
  // Dorso
  Exercise('trazioni', 'Trazioni alla sbarra', 'Dorso', 'Corpo libero'),
  Exercise('trazioni_assistite', 'Trazioni assistite', 'Dorso', 'Macchina'),
  Exercise('lat_machine', 'Lat machine presa larga', 'Dorso', 'Cavi'),
  Exercise('lat_machine_inversa', 'Lat machine presa inversa', 'Dorso', 'Cavi'),
  Exercise('pulley_basso', 'Pulley basso', 'Dorso', 'Cavi'),
  Exercise('rematore_bilanciere', 'Rematore con bilanciere', 'Dorso', 'Bilanciere'),
  Exercise('rematore_manubrio', 'Rematore con manubrio', 'Dorso', 'Manubri'),
  Exercise('t_bar_row', 'T-bar row', 'Dorso', 'Bilanciere'),
  Exercise('low_row', 'Low row', 'Dorso', 'Macchina'),
  Exercise('pullover_cavi', 'Pullover ai cavi', 'Dorso', 'Cavi'),
  Exercise('stacco_terra', 'Stacco da terra', 'Dorso', 'Bilanciere'),
  Exercise('hyperextension', 'Hyperextension', 'Dorso', 'Corpo libero'),
  // Spalle
  Exercise('military_press', 'Military press', 'Spalle', 'Bilanciere'),
  Exercise('lento_avanti_manubri', 'Lento avanti con manubri', 'Spalle', 'Manubri'),
  Exercise('shoulder_press', 'Shoulder press', 'Spalle', 'Macchina'),
  Exercise('alzate_laterali', 'Alzate laterali', 'Spalle', 'Manubri'),
  Exercise('alzate_laterali_cavi', 'Alzate laterali ai cavi', 'Spalle', 'Cavi'),
  Exercise('alzate_frontali', 'Alzate frontali', 'Spalle', 'Manubri'),
  Exercise('alzate_posteriori', 'Alzate posteriori', 'Spalle', 'Manubri'),
  Exercise('reverse_fly', 'Reverse fly', 'Spalle', 'Macchina'),
  Exercise('face_pull', 'Face pull', 'Spalle', 'Cavi'),
  Exercise('tirate_mento', 'Tirate al mento', 'Spalle', 'Bilanciere'),
  Exercise('scrollate', 'Scrollate con manubri', 'Spalle', 'Manubri'),
  // Braccia
  Exercise('curl_bilanciere', 'Curl con bilanciere', 'Bicipiti', 'Bilanciere'),
  Exercise('curl_manubri', 'Curl con manubri', 'Bicipiti', 'Manubri'),
  Exercise('curl_martello', 'Curl a martello', 'Bicipiti', 'Manubri'),
  Exercise('curl_panca_scott', 'Curl alla panca Scott', 'Bicipiti', 'Bilanciere'),
  Exercise('curl_cavi', 'Curl ai cavi', 'Bicipiti', 'Cavi'),
  Exercise('french_press', 'French press', 'Tricipiti', 'Bilanciere'),
  Exercise('pushdown_cavi', 'Pushdown ai cavi', 'Tricipiti', 'Cavi'),
  Exercise('estensioni_sopra_testa', 'Estensioni sopra la testa', 'Tricipiti', 'Manubri'),
  Exercise('panca_presa_stretta', 'Panca presa stretta', 'Tricipiti', 'Bilanciere'),
  Exercise('kickback', 'Kickback', 'Tricipiti', 'Manubri'),
  // Gambe
  Exercise('squat', 'Squat', 'Gambe', 'Bilanciere'),
  Exercise('front_squat', 'Front squat', 'Gambe', 'Bilanciere'),
  Exercise('squat_multipower', 'Squat al multipower', 'Gambe', 'Multipower'),
  Exercise('goblet_squat', 'Goblet squat', 'Gambe', 'Kettlebell'),
  Exercise('leg_press', 'Leg press', 'Gambe', 'Macchina'),
  Exercise('hack_squat', 'Hack squat', 'Gambe', 'Macchina'),
  Exercise('affondi_manubri', 'Affondi con manubri', 'Gambe', 'Manubri'),
  Exercise('bulgarian_split_squat', 'Bulgarian split squat', 'Gambe', 'Manubri'),
  Exercise('leg_extension', 'Leg extension', 'Gambe', 'Macchina'),
  Exercise('leg_curl_sdraiato', 'Leg curl sdraiato', 'Femorali', 'Macchina'),
  Exercise('leg_curl_seduto', 'Leg curl seduto', 'Femorali', 'Macchina'),
  Exercise('stacco_rumeno', 'Stacco rumeno', 'Femorali', 'Bilanciere'),
  Exercise('stacco_gambe_tese_manubri', 'Stacco a gambe tese con manubri', 'Femorali', 'Manubri'),
  Exercise('hip_thrust', 'Hip thrust', 'Glutei', 'Bilanciere'),
  Exercise('abductor', 'Abductor machine', 'Glutei', 'Macchina'),
  Exercise('adductor', 'Adductor machine', 'Gambe', 'Macchina'),
  Exercise('slanci_cavi', 'Slanci ai cavi', 'Glutei', 'Cavi'),
  Exercise('kettlebell_swing', 'Kettlebell swing', 'Glutei', 'Kettlebell'),
  Exercise('calf_in_piedi', 'Calf raise in piedi', 'Polpacci', 'Macchina'),
  Exercise('calf_seduto', 'Calf raise seduto', 'Polpacci', 'Macchina'),
  // Core
  Exercise('plank', 'Plank', 'Addome', 'Corpo libero'),
  Exercise('crunch', 'Crunch', 'Addome', 'Corpo libero'),
  Exercise('crunch_cavi', 'Crunch ai cavi', 'Addome', 'Cavi'),
  Exercise('leg_raise', 'Leg raise alla sbarra', 'Addome', 'Corpo libero'),
  Exercise('russian_twist', 'Russian twist', 'Addome', 'Corpo libero'),
  Exercise('pallof_press', 'Pallof press', 'Addome', 'Elastici'),
  Exercise('ab_wheel', 'Ab wheel', 'Addome', 'Corpo libero'),
];

Exercise? exerciseById(String id) {
  for (final e in exerciseLibrary) {
    if (e.id == id) return e;
  }
  return null;
}
