import 'package:flutter/material.dart';

enum InstrumentType {
  rainGauge,
  maxMinThermometer,
  riverGauge,
  hygrometer,
  awsAutomaticStation,
}

extension InstrumentTypeExtension on InstrumentType {
  String get displayName {
    switch (this) {
      case InstrumentType.rainGauge:
        return 'Standard Rain Gauge';
      case InstrumentType.maxMinThermometer:
        return 'Max-Min Thermometer';
      case InstrumentType.riverGauge:
        return 'River Level Gauge';
      case InstrumentType.hygrometer:
        return 'Hygrometer (Humidity)';
      case InstrumentType.awsAutomaticStation:
        return 'Automatic Weather Station (AWS)';
    }
  }

  String get prefix {
    switch (this) {
      case InstrumentType.rainGauge:
        return 'RG';
      case InstrumentType.maxMinThermometer:
        return 'TM';
      case InstrumentType.riverGauge:
        return 'RL';
      case InstrumentType.hygrometer:
        return 'HM';
      case InstrumentType.awsAutomaticStation:
        return 'AWS';
    }
  }

  List<String> get allowedParameters {
    switch (this) {
      case InstrumentType.rainGauge:
        return ['rainfall'];
      case InstrumentType.maxMinThermometer:
        return ['maxTemp', 'minTemp'];
      case InstrumentType.riverGauge:
        return ['riverLevel'];
      case InstrumentType.hygrometer:
        return ['humidity'];
      case InstrumentType.awsAutomaticStation:
        return ['rainfall', 'maxTemp', 'minTemp', 'humidity', 'riverLevel'];
    }
  }
}

enum StationCategory {
  manual,
  aws,
}

enum ApprovalStatus {
  pending,
  approved,
  rejected,
}

enum UserRole {
  admin,
  officer,
  volunteer,
  citizen,
}

enum UserCategory {
  adminHq,
  districtOfficer,
  schoolStudent,
  farmer,
  fisherman,
  ngoVolunteer,
  generalPublic,
}

extension UserCategoryExtension on UserCategory {
  String get label {
    switch (this) {
      case UserCategory.adminHq:
        return 'Admin HQ (KSDMA Headquarters)';
      case UserCategory.districtOfficer:
        return 'District Disaster Officer';
      case UserCategory.schoolStudent:
        return 'School Student';
      case UserCategory.farmer:
        return 'Farmer';
      case UserCategory.fisherman:
        return 'Fisherman';
      case UserCategory.ngoVolunteer:
        return 'NGO Volunteer';
      case UserCategory.generalPublic:
        return 'General Public';
    }
  }
}

class KsdmaUser {
  final String userId;
  final String fullName;
  final String mobileNumber;
  final String email;
  final UserRole role;
  final UserCategory category;
  final String district;
  final String taluk;
  final String gramaPanchayat;
  final String village;
  int streakDays;
  int maxStreak;
  int totalObservations;
  int todayReadings;
  DateTime? lastObservationDate;
  String badgeTier; // BRONZE, SILVER, GOLD
  String? avatarUrl;

  KsdmaUser({
    required this.userId,
    required this.fullName,
    required this.mobileNumber,
    required this.email,
    this.role = UserRole.volunteer,
    required this.category,
    this.district = '',
    this.taluk = '',
    this.gramaPanchayat = '',
    this.village = '',
    this.streakDays = 0,
    this.maxStreak = 0,
    this.totalObservations = 0,
    this.todayReadings = 0,
    this.lastObservationDate,
    this.badgeTier = 'BRONZE',
    this.avatarUrl,
  });
}

class KsdmaStation {
  final String stationId;
  final String ownerUserId;
  final String ownerName;
  final UserCategory ownerCategory;
  final StationCategory category;
  final InstrumentType instrumentType;
  final String deviceMake;
  final String measurementLocation;
  final String? devicePhotoUrl;
  final double latitude;
  final double longitude;
  final String district;
  final String taluk;
  final String gramaPanchayat;
  final String village;
  ApprovalStatus approvalStatus;
  final String rejectionReason; // Reason when Admin rejects a station registration
  final DateTime createdAt;

  KsdmaStation({
    required this.stationId,
    required this.ownerUserId,
    required this.ownerName,
    required this.ownerCategory,
    required this.category,
    required this.instrumentType,
    required this.deviceMake,
    required this.measurementLocation,
    this.devicePhotoUrl,
    required this.latitude,
    required this.longitude,
    required this.district,
    required this.taluk,
    required this.gramaPanchayat,
    required this.village,
    this.approvalStatus = ApprovalStatus.pending,
    this.rejectionReason = '',
    required this.createdAt,
  });
}

class KsdmaObservation {
  final String observationId;
  final String stationId;
  final String submittedByUserId;
  final DateTime observationDate;
  final TimeOfDay observationTime;
  final DateTime submissionTimestamp;
  final String source; // WEB_FORM, CSV_BULK_UPLOAD

  final double? rainfallMm;
  final double? maxTemperatureC;
  final double? minTemperatureC;
  final double? riverWaterLevelM;
  final double? humidityPercent; // Maximum Humidity
  final double? avgHumidityPercent; // Average Humidity

  final bool isEdited;

  // Moderation state
  bool isRemoved;
  String? removalReason; // OUTLIER, DUPLICATE, WRONG_UNIT, UNREALISTIC_SPIKE
  String? removedByAdminId;

  KsdmaObservation({
    required this.observationId,
    required this.stationId,
    required this.submittedByUserId,
    required this.observationDate,
    required this.observationTime,
    required this.submissionTimestamp,
    this.source = 'WEB_FORM',
    this.rainfallMm,
    this.maxTemperatureC,
    this.minTemperatureC,
    this.riverWaterLevelM,
    this.humidityPercent,
    this.avgHumidityPercent,
    this.isEdited = false,
    this.isRemoved = false,
    this.removalReason,
    this.removedByAdminId,
  });
}

/// Official Kerala Administrative Hierarchy & PostGIS Coordinates Boundary Validator
class KeralaAdminData {
  static const Map<String, Map<String, List<String>>> hierarchy = {
    'Alappuzha': {
      'Ambalappuzha': ['Ambalappuzha North', 'Ambalappuzha South', 'Punnapra North', 'Punnapra South', 'Purakkad'],
      'Chengannur': ['Ala', 'Budhanoor', 'Cheriyanad', 'Ennakkad', 'Mannar', 'Mulakuzha', 'Palamel', 'Puliyoor', 'Venmony'],
      'Cherthala': ['Arookutty', 'Aroor', 'Chennam Pallippuram', 'Cherthala South', 'Ezhupunna', 'Kadakkarappally', 'Kanjikkuzhi', 'Kodamthuruth', 'Kuthiathode', 'Mararikulam North', 'Panavally', 'Pattanakkad', 'Thaikattussery', 'Thuravoor', 'Vayalar'],
      'Karthikappally': ['Arattupuzha', 'Cheppad', 'Cheruthana', 'Chingoli', 'Haripad', 'Kandalloor', 'Karthikappally', 'Kumarapuram', 'Mavelikkara', 'Muthukulam', 'Narakathara', 'Pallippad', 'Pathiyoor', 'Thrikkunnapuzha', 'Veeyapuram'],
      'Kuttanad': ['Champakulam', 'Edathua', 'Kainakary', 'Kavalam', 'Muttar', 'Nedumudi', 'Neelamperoor', 'Pulinkunnoo', 'Ramankary', 'Thakazhy', 'Veliyanad'],
      'Mavelikkara': ['Chennithala', 'Cheppad', 'Chunakkara', 'Kanjipadam', 'Kattanam', 'Mavelikkara Thekkekara', 'Nooranad', 'Palamel', 'Thamarakkulam', 'Thekkekara', 'Thazhakara', 'Vallikunnam'],
    },
    'Ernakulam': {
      'Aluva': ['Aluva', 'Chengamanad', 'Choornikkara', 'Edathala', 'Kanjoor', 'Keezhmad', 'Nedumbassery', 'Sreemoolanagaram', 'Vazhakulam'],
      'Kanayannur': ['Cheranalloor', 'Choornikkara', 'Edappally', 'Elamkunnapuzha', 'Kadamakkudy', 'Kalamassery', 'Mulavukad', 'Thrikkakara'],
      'Kochi': ['Chellanam', 'Kumbalangi', 'Kumbalam', 'Njarakkal', 'Nayarambalam', 'Pallippuram'],
      'Kothamangalam': ['Kavalangad', 'Keerampara', 'Kothamangalam', 'Kuttampuzha', 'Mulamthuruthy', 'Pindimana', 'Pothanicad', 'Varappetty'],
      'Kunnathunad': ['Asamannoor', 'Kizhakambalam', 'Kottappady', 'Kunnathunad', 'Mazhuvannoor', 'Okkal', 'Poothrikka', 'Rayamangalam', 'Vengoor'],
      'Muvattupuzha': ['Arakuzha', 'Avaoly', 'Enanalloor', 'Kalloorkkad', 'Manjalloor', 'Marady', 'Paipra', 'Palakuzha', 'Valakom', 'Vazhakulam'],
      'Paravur': ['Chendamangalam', 'Ezhikkara', 'Kottuvally', 'Kunnukara', 'Moothakunnam', 'North Paravur', 'Puthenvelikkara', 'Varapuzha'],
    },
    'Idukki': {
      'Devikulam': ['Adimali', 'Bisonvalley', 'Chinnakanal', 'Devikulam', 'Kanthalloor', 'Kattappana', 'Mankulam', 'Marayoor', 'Munnar', 'Pallivasal', 'Vattavada'],
      'Idukki': ['Arakulam', 'Idukki-Kanjikuzhy', 'Kamakshy', 'Kudayathoor', 'Mariyapuram', 'Vathikudy', 'Vazhathope'],
      'Peerumade': ['Elappara', 'Kokkayar', 'Kumily', 'Manjumala', 'Peermade', 'Peruvanthanam', 'Vandiperiyar'],
      'Thodupuzha': ['Alakode', 'Devarshola', 'Karimannoor', 'Karimkunnam', 'Kodikulam', 'Kumaramangalam', 'Manakkad', 'Muttom', 'Purapuzha', 'Udumbannoor', 'Vannappuram'],
      'Udumbanchola': ['Chakkupallam', 'Erattayar', 'Karunapuram', 'Kattappana', 'Nedumkandam', 'Pambadumpara', 'Rajakkad', 'Rajakumari', 'Senapathy', 'Vandanmedu'],
    },
    'Kannur': {
      'Iritty': ['Aralam', 'Ayyankunnu', 'Iritty', 'Keezhur-Chavassery', 'Koodali', 'Kottiyoor', 'Muzhakkunnu', 'Payam', 'Payyavoor', 'Peravoor', 'Ulikkal'],
      'Kannur': ['Anjarakandy', 'Azhikode', 'Chelora', 'Cherukunnu', 'Cheruthazham', 'Chirakkal', 'Elayavoor', 'Kadambur', 'Kalliasseri', 'Kannapuram', 'Koluvally', 'Mattool', 'Munderi', 'Peralasseri', 'Valapattanam'],
      'Payyannur': ['Cherupuzha', 'Eramam-Kuttoor', 'Kadannappalli-Panapuzha', 'Kankole-Alapadamba', 'Karivellur-Peralam', 'Mathil', 'Payyannur', 'Peringome-Vayakkara', 'Ramanthali'],
      'Taliparamba': ['Alakode', 'Anthoor', 'Chaparapadavu', 'Chengalai', 'Irikkur', 'Kurumathur', 'Kuttiattoor', 'Mayyil', 'Naduvil', 'Pariyaram', 'Pattuvam', 'Sreekandapuram', 'Taliparamba', 'Udayagiri'],
      'Thalassery': ['Chokli', 'Dharmadam', 'Eranjoli', 'Kadirur', 'Kottayam-Malabar', 'Kuthuparamba', 'Mangattidam', 'Mokeri', 'Munderi', 'New Mahe', 'Panoor', 'Pattiom', 'Peralasseri', 'Peringalam', 'Pinarayi', 'Triprangottur'],
    },
    'Kasaragod': {
      'Hosdurg': ['Ajanoor', 'Kanhangad', 'Madikai', 'Manjeswaram', 'Pallikkere', 'Pullur-Periya', 'Udma'],
      'Kasargod': ['Badiadka', 'Bedadka', 'Chengala', 'Delampady', 'Karadka', 'Kumbadaje', 'Madhur', 'Mogral Puthur', 'Muliyar', 'Ummalathoor'],
      'Manjeshwaram': ['Enmakaje', 'Kumble', 'Manjeshwaram', 'Mangalpady', 'Meenja', 'Paivalike', 'Puthige', 'Vorkady'],
      'Vellarikundu': ['Balal', 'East Eleri', 'Kallar', 'Kinanoor-Karinthalam', 'Kodom-Belur', 'Panathady', 'West Eleri'],
    },
    'Kollam': {
      'Karunagappally': ['Alappad', 'Clappana', 'Kulasekharapuram', 'Oachira', 'Panmana', 'Thazhava', 'Thevalakkara'],
      'Kollam': ['Adichanalloor', 'Chathannoor', 'Elampalloor', 'Eravipuram', 'Kalluvathukkal', 'Mayyanad', 'Meenad', 'Nedumpana', 'Panayam', 'Perinad', 'Thrikkaruva', 'Thrikkovilvattom'],
      'Kottarakkara': ['Chadayamangalam', 'Elamad', 'Ezhukone', 'Itdiva', 'Kadakkal', 'Kallada', 'Kareepra', 'Kottarakkara', 'Kummil', 'Kulakkada', 'Mylom', 'Neduvathoor', 'Nilamel', 'Odanavattom', 'Pavithreswaram', 'Pooyappally', 'Veliyam', 'Vettikavala'],
      'Kunnathur': ['Kunnathur', 'Mynagappally', 'Poruvazhy', 'Sasthamkotta', 'Sooranad North', 'Sooranad South', 'West Kallada'],
      'Pathanapuram': ['Alanalloor', 'Aryankavu', 'Kulathupuzha', 'Melila', 'Pathanapuram', 'Pattazhy', 'Pattazhy Vadakkekara', 'Piravanthoor', 'Thalavoor', 'Thenmala', 'Vilakkudy'],
      'Punalur': ['Anchal', 'Aryankavu', 'Edamulackal', 'Eroor', 'Karavaloor', 'Kulathupuzha', 'Punalur', 'Thenmala', 'Yeroor'],
    },
    'Kottayam': {
      'Changanasserry': ['Changanasserry', 'Kanganazha', 'Karukachal', 'Kurichi', 'Madappally', 'Nedumkunnam', 'Paippad', 'Thrikkodithanam', 'Vazhappally'],
      'Kanjirappally': ['Anikkad', 'Elikulam', 'Kanjirappally', 'Koovappally', 'Manimala', 'Mundakayam', 'Parathode', 'Vazhoor'],
      'Kottayam': ['Aimanam', 'Akalakunnam', 'Ayarkunnam', 'Erumely', 'Kallara', 'Kottayam', 'Kumarakom', 'Manarcad', 'Meenachil', 'Neendoor', 'Pambady', 'Panachikkad', 'Puthuppally', 'Thiruvarpu', 'Vijayapuram'],
      'Meenachil': ['Bharananganam', 'Elackad', 'Erattupetta', 'Kadaplamattom', 'Kadanad', 'Kanakkary', 'Karoor', 'Kidangoor', 'Kozhuvanal', 'Lalam', 'Meenachil', 'Melukavu', 'Moonnilavu', 'Mutholy', 'Pala', 'Poonjar', 'Poonjar Thekkekara', 'Ramapuram', 'Teekoy'],
      'Vaikom': ['Chembu', 'Kallara', 'Kothanalloor', 'Kulasekharamangalam', 'Kavalam', 'Manjoor', 'Maravanthuruthu', 'Mulakulam', 'Njeezhoor', 'T V Puram', 'Thalayolaparambu', 'Thalayazham', 'Udayanapuram', 'Vaikom', 'Vechoor'],
    },
    'Kozhikode': {
      'Kozhikode': ['Balussery', 'Chelannur', 'Chengottukavu', 'Cheruvannur-Nallalam', 'Elathur', 'Kakkodi', 'Kakkur', 'Karakkurissi', 'Karuvanthuruthy', 'Kozhikode', 'Kudaranji', 'Kunnamangalam', 'Kuruvattoor', 'Mavoor', 'Nanminda', 'Olavanna', 'Perumanna', 'Peruvayal', 'Phoolbari', 'Ramanattukara', 'Thalakkulathur'],
      'Koyilandy': ['Arikkulam', 'Atholi', 'Balussery', 'Changaroth', 'Chakkittapara', 'Chemancheri', 'Chengottukavu', 'Cheruvannur', 'Kanthalad', 'Kattippara', 'Kayanna', 'Koorachundu', 'Kottur', 'Koyilandy', 'Kottoor', 'Meppayur', 'Moodadi', 'Naduvannur', 'Nochad', 'Panangad', 'Payyoli', 'Thikkodi', 'Ulliyeri', 'Unnikulam'],
      'Thamarassery': ['Kodenchery', 'Koduvally', 'Koodaranhi', 'Madavoor', 'Omassery', 'Puthuppadi', 'Thamarassery', 'Thiruvambady', 'Unnikulam'],
      'Vadakara': ['Azhiyur', 'Chorode', 'Eramala', 'Kavilumpara', 'Kayakkody', 'Kottappally', 'Kuttiadi', 'Maruthonkara', 'Nadavannur', 'Onchiam', 'Palayad', 'Purameri', 'Thiruvallur', 'Tunayeri', 'Vadakara', 'Valayam', 'Velom', 'Villiappally'],
    },
    'Malappuram': {
      'Ernad': ['Areekode', 'Chaliyar', 'Edavanna', 'Kavanoor', 'Kizhuparamba', 'Kondoottly', 'Kuzhimanna', 'Malappuram', 'Manjeri', 'Muthuvalloor', 'Urngattiri'],
      'Kondotty': ['Chelembra', 'Cherukavu', 'Kondotty', 'Muthuvalloor', 'Pallikkal', 'Pulikkal', 'Vazhakkad', 'Vazhayoor'],
      'Kottakkal': ['Edayur', 'Irimbiliyam', 'Kottakkal', 'Kuttippuram', 'Marakkara', 'Ponmala', 'Valavannur'],
      'Nilambur': ['Amarambalam', 'Chungathara', 'Edakkara', 'Karulai', 'Moopainad', 'Moothedam', 'Nilambur', 'Pothukal', 'Vazhikkadavu'],
      'Perinthalmanna': ['Aliparamba', 'Angadippuram', 'Elamkulam', 'Kuruva', 'Melattur', 'Moorkanad', 'Puzhakkattiri', 'Tazhekode', 'Vettathur'],
      'Ponnani': ['Alamcode', 'Edappal', 'Maranchery', 'Nannamku', 'Perumpadappa', 'Ponnani', 'Tavanur', 'Veliyankode'],
      'Tirur': ['Anakkayam', 'Athavanad', 'Cheriyamundam', 'Edarikode', 'Kalpakanchery', 'Kottakkal', 'Mangalam', 'Niramaruthur', 'Othukkungal', 'Parappur', 'Purathur', 'Tanur', 'Tanalur', 'Thennala', 'Tirur', 'Trikkandiyur', 'Triprangode', 'Valavannur', 'Vettom'],
      'Tirurangadi': ['Moonniyur', 'Neduva', 'Nannambra', 'Parappanangadi', 'Peruvalloor', 'Tirurangadi', 'Thenhippalam', 'Vengara'],
    },
    'Palakkad': {
      'Alathur': ['Alathur', 'Coyalmannam', 'Erimayur', 'Kavasseri', 'Kizhakkencheri', 'Kottayi', 'Kuthannur', 'Melarcode', 'Peringottukurissi', 'Puducode', 'Tarur', 'Vadakkancheri'],
      'Chittur': ['Elavancherry', 'Eruthempathy', 'Koduvayur', 'Kollengode', 'Kozhinjampara', 'Muthalamada', 'Nallepilly', 'Nelliampathy', 'Patttanchery', 'Perumatty', 'Polpully', 'Vadamaranchery'],
      'Mannarkkad': ['Alanallur', 'Kanjirapuzha', 'Kottoppadam', 'Kumaramputhur', 'Mannarkkad', 'Mundur', 'Pottassery', 'Tachampara', 'Thachanattukara'],
      'Ottapalam': ['Ambalappara', 'Ananganadi', 'Chalavara', 'Cherpulassery', 'Kadapra', 'Kulukkallur', 'Lakkidi-Perur', 'Muthuthala', 'Nellaya', 'Ottapalam', 'Sreekrishnapuram', 'Thrikkadeeri', 'Vellinezhi'],
      'Palakkad': ['Akathuthera', 'Elappully', 'Kannadi', 'Karimba', 'Kongad', 'Keralassery', 'Mankara', 'Mannur', 'Mundur', 'Palakkad', 'Parli', 'Pirayiri', 'Puduppariyaram', 'Pudussery'],
      'Pattambi': ['Anakkara', 'Chalissery', 'Koppam', 'Kulukallur', 'Muthuthala', 'Nagalassery', 'Ongallur', 'Paradur', 'Pattambi', 'Thiruvegapura', 'Thrithala', 'Vilayur'],
    },
    'Pathanamthitta': {
      'Adoor': ['Adoor', 'Chenneerkkara', 'Erathu', 'Ezhamkulam', 'Kadampanad', 'Kalanjoor', 'Kodumon', 'Koodal', 'Pallickal', 'Pandalam', 'Pandalam Thekkekara', 'Thumbamon'],
      'Konni': ['Aranmula', 'Elanthoor', 'Kalanjoor', 'Konni', 'Koodal', 'Malayalapuzha', 'Mylapra', 'Pramadom', 'Thannithode', 'Vallicode'],
      'Mallappally': ['Anicadu', 'Kallooppara', 'Kottangal', 'Kottanad', 'Kunnamthanam', 'Mallappally', 'Puramattam'],
      'Ranni': ['Cherukole', 'Chittar', 'Ezhumattoor', 'Foothill', 'Kollamula', 'Kottangal', 'Naranammoozhy', 'Nazereth', 'Pazhavangadi', 'Perunad', 'Ranni', 'Ranni-Angadi', 'Ranni-Pazhavangadi', 'Ranni-Perunad', 'Seethathode', 'Vadasserikkara', 'Vechoochira'],
      'Thiruvalla': ['Anjilithanam', 'Aranmula', 'Cheruthana', 'Kaviyoor', 'Kuttoor', 'Nedumpuram', 'Niranom', 'Peringara', 'Thiruvalla', 'Thottapuzhassery'],
    },
    'Thiruvananthapuram': {
      'Attingal': ['Alamcode', 'Attingal', 'Azhoor', 'Chirayinkeezhu', 'Edava', 'Elakamon', 'Kadakkavoor', 'Karavaram', 'Kizhuvalam', 'Kudavoor', 'Manamboor', 'Mudakkal', 'Nagaroor', 'Navayikulam', 'Ottoor', 'Pulimath', 'Vakkom', 'Varkala', 'Vettoor'],
      'Kattakada': ['Amboori', 'Aryancode', 'Kallar', 'Kallikkad', 'Kattakada', 'Kuttichal', 'Malayinkeezhu', 'Maranalloor', 'Ottasekharamangalam', 'Poovachal', 'Vellarada', 'Vilappil', 'Vilavoorkkal'],
      'Nedumangad': ['Anad', 'Aruvikkara', 'Aryanad', 'Kallara', 'Karakulam', 'Manickal', 'Nellanad', 'Panavoor', 'Pangode', 'Pullampara', 'Tholicode', 'Vamanapuram', 'Vellanad', 'Vembayam', 'Vithura'],
      'Neyyattinkara': ['Chenkal', 'Karumkulam', 'Kanjiramkulam', 'Kottukal', 'Kulathoor', 'Neyyattinkara', 'Ottasekharamangalam', 'Parassala', 'Poovar', 'Thirupuram', 'Uzhamalackal', 'Vellarada', 'Vizhinjam'],
      'Thiruvananthapuram': ['Andoorkonam', 'Attipra', 'Kazhakkoottam', 'Kudappanakkunnum', 'Menamkulam', 'Sreekariyam', 'Thiruvananthapuram', 'Ulloor', 'Vattiyoorkavu', 'Veiloor'],
    },
    'Thrissur': {
      'Chalakudy': ['Aloor', 'Annamanada', 'Chalakudy', 'Elinjipra', 'Kadukutty', 'Kodakara', 'Kodassery', 'Koratty', 'Kizhakkummuri', 'Meloor', 'Muringoor', 'Pariyaram', 'Poyya', 'Puthenchira', 'Varandarappilly'],
      'Chavakkad': ['Chavakkad', 'Engandiyur', 'Eriyad', 'Guruvayur', 'Kadappuram', 'Kandanassery', 'Mullassery', 'Orumanayur', 'Punnayur', 'Punnayurkulam', 'Venkitangu', 'Vadakkekad'],
      'Kodungallur': ['Edavilangu', 'Eriyad', 'Methala', 'Poyya', 'Sreenarayanapuram', 'Vellangallur'],
      'Mukundapuram': ['Alagappanagar', 'Avinissery', 'Cherpu', 'Irinjalakuda', 'Karalam', 'Kattur', 'Muriyad', 'Nenmenikkara', 'Padiyur', 'Paralam', 'Poomangalam', 'Porathissery', 'Puthukkad', 'Trikkur', 'Vallachira', 'Velookkara'],
      'Thalapilly': ['Desamangalam', 'Erumapetty', 'Kadangode', 'Kangarappady', 'Kondazhy', 'Mullurkara', 'Pazhayannur', 'Thiruvilwamala', 'Vadakkanchery', 'Varavoor', 'Velur'],
      'Thrissur': ['Adat', 'Arimpur', 'Avinissery', 'Choolissery', 'Kolenchery', 'Kolazhy', 'Madakkathara', 'Mulagunathukavu', 'Nattika', 'Ollukkara', 'Paralam', 'Puthur', 'Tholur', 'Thrissur', 'Vadanappally', 'Vilvattom'],
    },
    'Wayanad': {
      'Mananthavady': ['Edavaka', 'Mananthavady', 'Panamaram', 'Thavinhal', 'Thirunelly', 'Vellamunda'],
      'Sulthan Bathery': ['Ambalavayal', 'Meenangadi', 'Noolpuzha', 'Poothadi', 'Pulpally', 'Sulthan Bathery'],
      'Vythiri': ['Kottathara', 'Meppadi', 'Muppainad', 'Muttil', 'Padinharethara', 'Pozhuthana', 'Tariode', 'Vengappally', 'Vythiri'],
    },
  };

  static List<String> getDistricts() {
    final list = hierarchy.keys.toList();
    list.sort();
    return list;
  }

  static List<String> getTaluks(String district) {
    if (!hierarchy.containsKey(district)) return [];
    final list = hierarchy[district]!.keys.toList();
    list.sort();
    return list;
  }

  static List<String> getPanchayats(String district, String taluk) {
    if (!hierarchy.containsKey(district)) return [];
    final distMap = hierarchy[district]!;
    if (!distMap.containsKey(taluk)) return [];
    final list = List<String>.from(distMap[taluk]!);
    list.sort();
    return list;
  }

  /// Option 3: Coordinates Bounding Box Validation for Kerala
  static String? validateCoordinates(double lat, double lng) {
    if (lat < 8.0 || lat > 13.1) {
      return '⚠️ Latitude $lat°N is outside Kerala state boundaries (Valid range: 8.0°N to 13.1°N).';
    }
    if (lng < 74.5 || lng > 77.8) {
      return '⚠️ Longitude $lng°E is outside Kerala state boundaries (Valid range: 74.5°E to 77.8°E).';
    }
    return null;
  }
}
