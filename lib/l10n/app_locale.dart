import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

const defaultLocaleCode = 'en';

@immutable
class AppLanguageMetadata {
  const AppLanguageMetadata({
    required this.code,
    required this.nativeName,
    required this.englishName,
    required this.localizedNames,
  });

  final String code;
  final String nativeName;
  final String englishName;
  final Map<String, String> localizedNames;

  String localizedNameFor(String uiLocaleCode) {
    final normalizedCode = normalizeLocaleCode(uiLocaleCode);
    final languageCode = _parseLocaleCode(normalizedCode).languageCode
        .toLowerCase();
    return localizedNames[normalizedCode] ??
        localizedNames[languageCode] ??
        localizedNames[defaultLocaleCode] ??
        englishName;
  }
}

@immutable
class AppLanguageOption {
  const AppLanguageOption({
    required this.code,
    required this.locale,
    required this.nativeName,
    required this.localizedName,
    required this.englishName,
  });

  final String code;
  final Locale locale;
  final String nativeName;
  final String localizedName;
  final String englishName;

  String get label => localizedName;
}

const _supportedLanguageMetadata = <String, AppLanguageMetadata>{
  'bg': AppLanguageMetadata(
    code: 'bg',
    nativeName: 'Български',
    englishName: 'Bulgarian',
    localizedNames: {
      'bg': 'Български',
      'cs': 'bulharský',
      'da': 'bulgarsk',
      'de': 'Bulgarisch',
      'el': 'Βουλγαρική',
      'en': 'Bulgarian',
      'es': 'búlgaro',
      'fi': 'bulgarialainen',
      'fr': 'bulgare',
      'hu': 'bolgár',
      'it': 'bulgari',
      'ja': 'ブルガリア語',
      'ko': '불가리아어',
      'nl': 'Bulgaars',
      'pl': 'bułgarski',
      'pt': 'búlgaro',
      'ro': 'bulgară',
      'ru': 'Болгарский',
      'sv': 'bulgariska',
      'th': 'บัลแกเรีย',
      'vi': 'Tiếng Bulgaria',
      'zh': '保加利亚语',
      'et': 'bulgaaria',
      'hi': 'बुल्गारियाई',
      'sl': 'bolgarščina',
      'zh-Hant': '保加利亞文',
    },
  ),
  'cs': AppLanguageMetadata(
    code: 'cs',
    nativeName: 'Čeština',
    englishName: 'Czech',
    localizedNames: {
      'cs': 'Čeština',
      'de': 'Tschechisch',
      'el': 'Τσεχική',
      'en': 'Czech',
      'es': 'Checo',
      'fr': 'Tchèque',
      'it': 'Ceco',
      'ja': 'チェコ',
      'ko': '체코어',
      'nl': 'Tsjechisch',
      'pl': 'czeski',
      'pt': 'Tcheco',
      'ru': 'чешский',
      'sv': 'tjeckiska',
      'th': 'เช็ก',
      'vi': 'tiếng Séc',
      'zh': '捷克',
      'bg': 'чешки',
      'da': 'tjekkisk',
      'et': 'tšehhi',
      'fi': 'tšekki',
      'hi': 'चेक',
      'hu': 'cseh',
      'ro': 'cehă',
      'sl': 'češčina',
      'zh-Hant': '捷克文',
    },
  ),
  'da': AppLanguageMetadata(
    code: 'da',
    nativeName: 'Dansk',
    englishName: 'Danish',
    localizedNames: {
      'cs': 'dánské',
      'da': 'Dansk',
      'de': 'Dänisch',
      'el': 'Δανική',
      'en': 'Danish',
      'es': 'danés',
      'fi': 'tanskalainen',
      'fr': 'danois',
      'hu': 'dán',
      'it': 'danese',
      'ja': 'デンマーク語',
      'ko': '덴마크어',
      'nl': 'Deense',
      'pl': 'duński',
      'pt': 'Dinamarquês',
      'ro': 'daneză',
      'ru': 'датский',
      'sv': 'danska',
      'th': 'เดนมาร์ก',
      'vi': 'Đan Mạch',
      'zh': '丹麦语',
      'bg': 'датски',
      'et': 'taani',
      'hi': 'डेनिश',
      'sl': 'danščina',
      'zh-Hant': '丹麥文',
    },
  ),
  'de': AppLanguageMetadata(
    code: 'de',
    nativeName: 'Deutsch',
    englishName: 'German',
    localizedNames: {
      'de': 'Deutsch',
      'en': 'German',
      'es': 'Alemán',
      'fr': 'Allemand',
      'it': 'Tedesco',
      'ja': 'ドイツ語',
      'ko': '독일어',
      'pt': 'Alemão',
      'ru': 'Немецкий',
      'zh': '德语',
      'bg': 'немски',
      'cs': 'němčina',
      'da': 'tysk',
      'el': 'Γερμανικά',
      'et': 'saksa',
      'fi': 'saksa',
      'hi': 'जर्मन',
      'hu': 'német',
      'nl': 'Duits',
      'pl': 'niemiecki',
      'ro': 'germană',
      'sl': 'nemščina',
      'sv': 'tyska',
      'th': 'เยอรมัน',
      'vi': 'Tiếng Đức',
      'zh-Hant': '德文',
    },
  ),
  'el': AppLanguageMetadata(
    code: 'el',
    nativeName: 'Ελληνικά',
    englishName: 'Greek',
    localizedNames: {
      'de': 'Griechisch',
      'el': 'Ελληνικά',
      'en': 'Greek',
      'es': 'griego',
      'fr': 'grec',
      'it': 'greco',
      'ja': 'ギリシャ',
      'ko': '그리스어',
      'nl': 'Grieks',
      'pl': 'grecki',
      'pt': 'grego',
      'ru': 'греческого',
      'sv': 'grekiska',
      'th': 'กรีก',
      'vi': 'Hy Lạp',
      'zh': '希腊',
      'bg': 'гръцки',
      'cs': 'řečtina',
      'da': 'græsk',
      'et': 'kreeka',
      'fi': 'kreikka',
      'hi': 'यूनानी',
      'hu': 'görög',
      'ro': 'greacă',
      'sl': 'grščina',
      'zh-Hant': '希臘文',
    },
  ),
  'en': AppLanguageMetadata(
    code: 'en',
    nativeName: 'English',
    englishName: 'English',
    localizedNames: {
      'de': 'Englisch',
      'en': 'English',
      'es': 'Inglés',
      'fr': 'Anglais',
      'it': 'Inglese',
      'ja': '英語',
      'ko': '영어',
      'pt': 'Inglês',
      'ru': 'Английский',
      'zh': '英语',
      'bg': 'английски',
      'cs': 'angličtina',
      'da': 'engelsk',
      'el': 'Αγγλικά',
      'et': 'inglise',
      'fi': 'englanti',
      'hi': 'अंग्रेज़ी',
      'hu': 'angol',
      'nl': 'Engels',
      'pl': 'angielski',
      'ro': 'engleză',
      'sl': 'angleščina',
      'sv': 'engelska',
      'th': 'อังกฤษ',
      'vi': 'Tiếng Anh',
      'zh-Hant': '英文',
    },
  ),
  'es': AppLanguageMetadata(
    code: 'es',
    nativeName: 'Español',
    englishName: 'Spanish',
    localizedNames: {
      'de': 'Spanisch',
      'en': 'Spanish',
      'es': 'Español',
      'fr': 'Espagnol',
      'it': 'Spagnolo',
      'ja': 'スペイン語',
      'ko': '스페인어',
      'pt': 'Espanhol',
      'ru': 'Испанский',
      'zh': '西班牙语',
      'bg': 'испански',
      'cs': 'španělština',
      'da': 'spansk',
      'el': 'Ισπανικά',
      'et': 'hispaania',
      'fi': 'espanja',
      'hi': 'स्पेनिश',
      'hu': 'spanyol',
      'nl': 'Spaans',
      'pl': 'hiszpański',
      'ro': 'spaniolă',
      'sl': 'španščina',
      'sv': 'spanska',
      'th': 'สเปน',
      'vi': 'Tiếng Tây Ban Nha',
      'zh-Hant': '西班牙文',
    },
  ),
  'et': AppLanguageMetadata(
    code: 'et',
    nativeName: 'Eesti',
    englishName: 'Estonian',
    localizedNames: {
      'bg': 'естонски',
      'cs': 'estonské',
      'da': 'estisk',
      'de': 'Estnisch',
      'el': 'Εσθονικά',
      'en': 'Estonian',
      'es': 'estonio',
      'et': 'Eesti',
      'fi': 'virolainen',
      'fr': 'estonien',
      'hu': 'észt',
      'it': 'estone',
      'ja': 'エストニア語',
      'ko': '에스토니아어',
      'nl': 'Estse',
      'pl': 'estoński',
      'pt': 'Estônia',
      'ro': 'estonă',
      'ru': 'эстонский',
      'sv': 'estniska',
      'th': 'เอสโตเนีย',
      'vi': 'Tiếng Estonia',
      'zh': '爱沙尼亚语',
      'hi': 'एस्टोनियाई',
      'sl': 'estonščina',
      'zh-Hant': '愛沙尼亞文',
    },
  ),
  'fi': AppLanguageMetadata(
    code: 'fi',
    nativeName: 'Suomi',
    englishName: 'Finnish',
    localizedNames: {
      'cs': 'finština',
      'de': 'Finnisch',
      'el': 'Φινλανδικά',
      'en': 'Finnish',
      'es': 'Finlandés',
      'fi': 'Suomi',
      'fr': 'Finlandais',
      'it': 'finlandese',
      'ja': 'フィンランド語',
      'ko': '핀란드어',
      'nl': 'Fins',
      'pl': 'fiński',
      'pt': 'finlandês',
      'ro': 'finlandeză',
      'ru': 'финский',
      'sv': 'finska',
      'th': 'ฟินแลนด์',
      'vi': 'Phần Lan',
      'zh': '芬兰语',
      'bg': 'фински',
      'da': 'finsk',
      'et': 'soome',
      'hi': 'फ़िनिश',
      'hu': 'finn',
      'sl': 'finščina',
      'zh-Hant': '芬蘭文',
    },
  ),
  'fr': AppLanguageMetadata(
    code: 'fr',
    nativeName: 'Français',
    englishName: 'French',
    localizedNames: {
      'de': 'Französisch',
      'en': 'French',
      'es': 'Francés',
      'fr': 'Français',
      'it': 'Francese',
      'ja': 'フランス語',
      'ko': '프랑스어',
      'pt': 'Francês',
      'ru': 'Французский',
      'zh': '法语',
      'bg': 'френски',
      'cs': 'francouzština',
      'da': 'fransk',
      'el': 'Γαλλικά',
      'et': 'prantsuse',
      'fi': 'ranska',
      'hi': 'फ़्रेंच',
      'hu': 'francia',
      'nl': 'Frans',
      'pl': 'francuski',
      'ro': 'franceză',
      'sl': 'francoščina',
      'sv': 'franska',
      'th': 'ฝรั่งเศส',
      'vi': 'Tiếng Pháp',
      'zh-Hant': '法文',
    },
  ),
  'hu': AppLanguageMetadata(
    code: 'hu',
    nativeName: 'Magyar',
    englishName: 'Hungarian',
    localizedNames: {
      'cs': 'maďarské',
      'de': 'Ungarisch',
      'el': 'Ουγγρική',
      'en': 'Hungarian',
      'es': 'húngaro',
      'fi': 'Unkarilainen',
      'fr': 'hongrois',
      'hu': 'Magyar',
      'it': 'Ungherese',
      'ja': 'ハンガリー語',
      'ko': 'Hungarian',
      'nl': 'Hongaars',
      'pl': 'węgierski',
      'pt': 'Húngaro',
      'ro': 'maghiară',
      'ru': 'венгерский',
      'sv': 'Ungerska',
      'th': 'ฮังการี',
      'vi': 'tiếng Hungary',
      'zh': '匈牙利语',
      'bg': 'унгарски',
      'da': 'ungarsk',
      'et': 'ungari',
      'hi': 'हंगेरियाई',
      'sl': 'madžarščina',
      'zh-Hant': '匈牙利文',
    },
  ),
  'hi': AppLanguageMetadata(
    code: 'hi',
    nativeName: 'हिन्दी',
    englishName: 'Hindi',
    localizedNames: {
      'bg': 'Хинди',
      'cs': 'hindština',
      'da': 'hindi',
      'de': 'Hindi',
      'el': 'Χίντι',
      'en': 'Hindi',
      'es': 'Hindi',
      'et': 'Hindi',
      'fi': 'hindi',
      'fr': 'Hindi',
      'hi': 'हिन्दी',
      'hu': 'Hindi',
      'it': 'Hindi',
      'ja': 'ヒンディー語',
      'ko': '힌디어',
      'nl': 'Hindi',
      'pl': 'Hindi',
      'pt': 'Hindi',
      'ro': 'Hindi',
      'ru': 'Хинди',
      'sl': 'hindijščina',
      'sv': 'hindi',
      'th': 'ภาษาฮินดี',
      'vi': 'Tiếng Hindi',
      'zh': '印地语',
      'zh-Hant': '印地文',
    },
  ),
  'it': AppLanguageMetadata(
    code: 'it',
    nativeName: 'Italiano',
    englishName: 'Italian',
    localizedNames: {
      'de': 'Italienisch',
      'en': 'Italian',
      'es': 'Italiano',
      'fr': 'Italien',
      'it': 'Italiano',
      'ja': 'イタリア語',
      'ko': '이탈리아어',
      'pt': 'Italiano',
      'ru': 'Итальянский',
      'zh': '意大利语',
      'bg': 'италиански',
      'cs': 'italština',
      'da': 'italiensk',
      'el': 'Ιταλικά',
      'et': 'itaalia',
      'fi': 'italia',
      'hi': 'इतालवी',
      'hu': 'olasz',
      'nl': 'Italiaans',
      'pl': 'włoski',
      'ro': 'italiană',
      'sl': 'italijanščina',
      'sv': 'italienska',
      'th': 'อิตาลี',
      'vi': 'Tiếng Italy',
      'zh-Hant': '義大利文',
    },
  ),
  'ja': AppLanguageMetadata(
    code: 'ja',
    nativeName: '日本語',
    englishName: 'Japanese',
    localizedNames: {
      'de': 'Japanisch',
      'en': 'Japanese',
      'es': 'Japonés',
      'fr': 'Japonais',
      'it': 'Giapponese',
      'ja': '日本語',
      'ko': '일본어',
      'pt': 'Japonês',
      'ru': 'Японский',
      'zh': '日语',
      'bg': 'японски',
      'cs': 'japonština',
      'da': 'japansk',
      'el': 'Ιαπωνικά',
      'et': 'jaapani',
      'fi': 'japani',
      'hi': 'जापानी',
      'hu': 'japán',
      'nl': 'Japans',
      'pl': 'japoński',
      'ro': 'japoneză',
      'sl': 'japonščina',
      'sv': 'japanska',
      'th': 'ญี่ปุ่น',
      'vi': 'Tiếng Nhật',
      'zh-Hant': '日文',
    },
  ),
  'ko': AppLanguageMetadata(
    code: 'ko',
    nativeName: '한국어',
    englishName: 'Korean',
    localizedNames: {
      'de': 'Koreanisch',
      'en': 'Korean',
      'es': 'Coreano',
      'fr': 'Coréen',
      'it': 'Coreano',
      'ja': '韓国語',
      'ko': '한국어',
      'pt': 'Coreano',
      'ru': 'Корейский',
      'zh': '韩语',
      'bg': 'корейски',
      'cs': 'korejština',
      'da': 'koreansk',
      'el': 'Κορεατικά',
      'et': 'korea',
      'fi': 'korea',
      'hi': 'कोरियाई',
      'hu': 'koreai',
      'nl': 'Koreaans',
      'pl': 'koreański',
      'ro': 'coreeană',
      'sl': 'korejščina',
      'sv': 'koreanska',
      'th': 'เกาหลี',
      'vi': 'Tiếng Hàn',
      'zh-Hant': '韓文',
    },
  ),
  'nl': AppLanguageMetadata(
    code: 'nl',
    nativeName: 'Nederlands',
    englishName: 'Dutch',
    localizedNames: {
      'de': 'Niederländisch',
      'en': 'Dutch',
      'es': 'Neerlandés',
      'fr': 'Néerlandais',
      'it': 'Olandese',
      'ja': 'オランダ語',
      'ko': '네덜란드어',
      'nl': 'Nederlands',
      'pt': 'Holandês',
      'ru': 'Нидерландский',
      'zh': '荷兰语',
      'bg': 'нидерландски',
      'cs': 'nizozemština',
      'da': 'nederlandsk',
      'el': 'Ολλανδικά',
      'et': 'hollandi',
      'fi': 'hollanti',
      'hi': 'डच',
      'hu': 'holland',
      'pl': 'niderlandzki',
      'ro': 'neerlandeză',
      'sl': 'nizozemščina',
      'sv': 'nederländska',
      'th': 'ดัตช์',
      'vi': 'Tiếng Hà Lan',
      'zh-Hant': '荷蘭文',
    },
  ),
  'pl': AppLanguageMetadata(
    code: 'pl',
    nativeName: 'Polski',
    englishName: 'Polish',
    localizedNames: {
      'de': 'polnisch',
      'en': 'Polish',
      'es': 'polaco',
      'fr': 'polonais',
      'it': 'polacco',
      'ja': 'ポーランド語',
      'ko': '폴란드어',
      'nl': 'Pools',
      'pl': 'Polski',
      'pt': 'polonês',
      'ru': 'польский',
      'zh': '波兰语',
      'bg': 'полски',
      'cs': 'polština',
      'da': 'polsk',
      'el': 'Πολωνικά',
      'et': 'poola',
      'fi': 'puola',
      'hi': 'पोलिश',
      'hu': 'lengyel',
      'ro': 'poloneză',
      'sl': 'poljščina',
      'sv': 'polska',
      'th': 'โปแลนด์',
      'vi': 'Tiếng Ba Lan',
      'zh-Hant': '波蘭文',
    },
  ),
  'pt': AppLanguageMetadata(
    code: 'pt',
    nativeName: 'Português',
    englishName: 'Portuguese',
    localizedNames: {
      'de': 'Portugiesisch',
      'en': 'Portuguese',
      'es': 'Portugués',
      'fr': 'Portugais',
      'it': 'Portoghese',
      'ja': 'ポルトガル語',
      'ko': '포르투갈어',
      'pt': 'Português',
      'ru': 'Португальский',
      'zh': '葡萄牙语',
      'bg': 'португалски',
      'cs': 'portugalština',
      'da': 'portugisisk',
      'el': 'Πορτογαλικά',
      'et': 'portugali',
      'fi': 'portugali',
      'hi': 'पुर्तगाली',
      'hu': 'portugál',
      'nl': 'Portugees',
      'pl': 'portugalski',
      'ro': 'portugheză',
      'sl': 'portugalščina',
      'sv': 'portugisiska',
      'th': 'โปรตุเกส',
      'vi': 'Tiếng Bồ Đào Nha',
      'zh-Hant': '葡萄牙文',
    },
  ),
  'ro': AppLanguageMetadata(
    code: 'ro',
    nativeName: 'Română',
    englishName: 'Romanian',
    localizedNames: {
      'cs': 'rumunské',
      'de': 'Rumänisch',
      'el': 'Ρουμανικά',
      'en': 'Romanian',
      'es': 'rumano',
      'fr': 'Roumain',
      'it': 'rumeno',
      'ja': 'ルーマニア語',
      'ko': '루마니아어',
      'nl': 'Roemeens',
      'pl': 'rumuński',
      'pt': 'romeno',
      'ro': 'Română',
      'ru': 'румынский',
      'sv': 'rumänska',
      'th': 'โรมาเนีย',
      'vi': 'Tiếng Romania',
      'zh': '罗马尼亚语',
      'bg': 'румънски',
      'da': 'rumænsk',
      'et': 'rumeenia',
      'fi': 'romania',
      'hi': 'रोमानियाई',
      'hu': 'román',
      'sl': 'romunščina',
      'zh-Hant': '羅馬尼亞文',
    },
  ),
  'ru': AppLanguageMetadata(
    code: 'ru',
    nativeName: 'Русский',
    englishName: 'Russian',
    localizedNames: {
      'de': 'Russisch',
      'en': 'Russian',
      'es': 'Ruso',
      'fr': 'Russe',
      'it': 'Russo',
      'ja': 'ロシア語',
      'ko': '러시아어',
      'pt': 'Russo',
      'ru': 'Русский',
      'zh': '俄语',
      'bg': 'руски',
      'cs': 'ruština',
      'da': 'russisk',
      'el': 'Ρωσικά',
      'et': 'vene',
      'fi': 'venäjä',
      'hi': 'रूसी',
      'hu': 'orosz',
      'nl': 'Russisch',
      'pl': 'rosyjski',
      'ro': 'rusă',
      'sl': 'ruščina',
      'sv': 'ryska',
      'th': 'รัสเซีย',
      'vi': 'Tiếng Nga',
      'zh-Hant': '俄文',
    },
  ),
  'sl': AppLanguageMetadata(
    code: 'sl',
    nativeName: 'Slovenščina',
    englishName: 'Slovenian',
    localizedNames: {
      'bg': 'Словенски',
      'cs': 'Slovinský',
      'da': 'slovensk',
      'de': 'Slowenisch',
      'el': 'Σλοβενικά',
      'en': 'Slovenian',
      'es': 'Esloveno',
      'et': 'Sloveenia keel',
      'fi': 'slovenialainen',
      'fr': 'slovène',
      'hu': 'szlovén',
      'it': 'sloveno',
      'ja': 'スロベニア語',
      'ko': '슬로베니아어',
      'nl': 'Sloveense',
      'pl': 'słoweński',
      'pt': 'Eslovênia',
      'ro': 'slovenă',
      'ru': 'Словенский',
      'sl': 'Slovenščina',
      'sv': 'slovenska',
      'th': 'สโลวีเนีย',
      'vi': 'Tiếng Slovenia',
      'zh': '斯洛文尼亚语',
      'hi': 'स्लोवेनियाई',
      'zh-Hant': '斯洛維尼亞文',
    },
  ),
  'sv': AppLanguageMetadata(
    code: 'sv',
    nativeName: 'Svenska',
    englishName: 'Swedish',
    localizedNames: {
      'de': 'Schwedisch',
      'en': 'Swedish',
      'es': 'sueco',
      'fr': 'suédois',
      'it': 'Svedese',
      'ja': 'スウェーデン語',
      'ko': '스웨덴어',
      'nl': 'Zweeds',
      'pl': 'szwedzki',
      'pt': 'sueco',
      'ru': 'шведский',
      'sv': 'Svenska',
      'zh': '瑞典语',
      'bg': 'шведски',
      'cs': 'švédština',
      'da': 'svensk',
      'el': 'Σουηδικά',
      'et': 'rootsi',
      'fi': 'ruotsi',
      'hi': 'स्वीडिश',
      'hu': 'svéd',
      'ro': 'suedeză',
      'sl': 'švedščina',
      'th': 'สวีเดน',
      'vi': 'Tiếng Thụy Điển',
      'zh-Hant': '瑞典文',
    },
  ),
  'th': AppLanguageMetadata(
    code: 'th',
    nativeName: 'ไทย',
    englishName: 'Thai',
    localizedNames: {
      'de': 'thailändisch',
      'en': 'Thai',
      'es': 'tailandés',
      'fr': 'thaïlandais',
      'it': 'Thailandese',
      'ja': 'タイ語',
      'ko': '태국',
      'nl': 'Thaise',
      'pl': 'tajskiego',
      'pt': 'tailandês',
      'ru': 'тайский',
      'sv': 'Thailändska',
      'th': 'ไทย',
      'zh': '泰语',
      'bg': 'тайски',
      'cs': 'thajština',
      'da': 'thai',
      'el': 'Ταϊλανδικά',
      'et': 'tai',
      'fi': 'thai',
      'hi': 'थाई',
      'hu': 'thai',
      'ro': 'thailandeză',
      'sl': 'tajščina',
      'vi': 'Tiếng Thái',
      'zh-Hant': '泰文',
    },
  ),
  'vi': AppLanguageMetadata(
    code: 'vi',
    nativeName: 'Tiếng Việt',
    englishName: 'Vietnamese',
    localizedNames: {
      'de': 'vietnamesisch',
      'en': 'Vietnamese',
      'es': 'vietnamitas',
      'fr': 'vietnamiens',
      'it': 'vietnamita',
      'ja': 'ベトナム語',
      'ko': '베트남어',
      'nl': 'Vietnamese',
      'pl': 'wietnamski',
      'pt': 'vietnamitas',
      'ru': 'Вьетнамский',
      'sv': 'vietnamesiska',
      'th': 'เวียดนาม',
      'vi': 'Tiếng Việt',
      'zh': '越南语',
      'bg': 'виетнамски',
      'cs': 'vietnamština',
      'da': 'vietnamesisk',
      'el': 'Βιετναμικά',
      'et': 'vietnami',
      'fi': 'vietnam',
      'hi': 'वियतनामी',
      'hu': 'vietnámi',
      'ro': 'vietnameză',
      'sl': 'vietnamščina',
      'zh-Hant': '越南文',
    },
  ),
  'zh': AppLanguageMetadata(
    code: 'zh',
    nativeName: '简体中文',
    englishName: 'Chinese (Simplified)',
    localizedNames: {
      'de': 'Chinesisch (vereinfacht)',
      'en': 'Chinese (Simplified)',
      'es': 'Chino simplificado',
      'fr': 'Chinois simplifié',
      'it': 'Cinese semplificato',
      'ja': '中国語（簡体字）',
      'ko': '중국어(간체)',
      'pt': 'Chinês simplificado',
      'ru': 'Китайский (упрощённый)',
      'zh': '简体中文',
      'zh-Hant': '簡體中文',
      'bg': 'китайски (опростена)',
      'cs': 'čínština (zjednodušené)',
      'da': 'kinesisk (forenklet)',
      'el': 'Κινεζικά (Απλοποιημένο)',
      'et': 'hiina (lihtsustatud)',
      'fi': 'kiina (yksinkertaistettu)',
      'hi': 'चीनी (सरलीकृत)',
      'hu': 'kínai (Egyszerűsített)',
      'nl': 'Chinees (vereenvoudigd)',
      'pl': 'chiński (uproszczone)',
      'ro': 'chineză (simplificată)',
      'sl': 'kitajščina (poenostavljena pisava)',
      'sv': 'kinesiska (förenklad)',
      'th': 'จีน (ตัวย่อ)',
      'vi': 'Tiếng Trung (Giản thể)',
    },
  ),
  'zh-Hant': AppLanguageMetadata(
    code: 'zh-Hant',
    nativeName: '繁體中文',
    englishName: 'Chinese (Traditional)',
    localizedNames: {
      'de': 'Chinesisch (traditionell)',
      'en': 'Chinese (Traditional)',
      'es': 'Chino tradicional',
      'fr': 'Chinois traditionnel',
      'it': 'Cinese tradizionale',
      'ja': '中国語（繁体字）',
      'ko': '중국어(번체)',
      'pt': 'Chinês tradicional',
      'ru': 'Китайский (традиционный)',
      'zh': '繁体中文',
      'zh-Hant': '繁體中文',
      'bg': 'китайски (традиционна)',
      'cs': 'čínština (tradiční)',
      'da': 'kinesisk (traditionelt)',
      'el': 'Κινεζικά (Παραδοσιακό)',
      'et': 'hiina (traditsiooniline)',
      'fi': 'kiina (perinteinen)',
      'hi': 'चीनी (पारंपरिक)',
      'hu': 'kínai (Hagyományos)',
      'nl': 'Chinees (traditioneel)',
      'pl': 'chiński (tradycyjne)',
      'ro': 'chineză (tradițională)',
      'sl': 'kitajščina (tradicionalna pisava)',
      'sv': 'kinesiska (traditionell)',
      'th': 'จีน (ตัวเต็ม)',
      'vi': 'Tiếng Trung (Phồn thể)',
    },
  ),
};

String localeCodeFromLocale(Locale locale) {
  final parts = <String>[locale.languageCode.toLowerCase()];
  final scriptCode = locale.scriptCode;
  final countryCode = locale.countryCode;
  if (scriptCode != null && scriptCode.isNotEmpty) {
    parts.add(_normalizeScriptCode(scriptCode));
  }
  if (countryCode != null && countryCode.isNotEmpty) {
    parts.add(countryCode.toUpperCase());
  }
  return parts.join('-');
}

String normalizeLocaleCode(String? localeCode) {
  final raw = localeCode?.trim();
  if (raw == null || raw.isEmpty) {
    return localeCodeFromLocale(_defaultAppLocale);
  }
  final requestedLocale = _canonicalizeChineseLocale(_parseLocaleCode(raw));
  final locale = _findSupportedLocale(
    requestedLocale,
    allowLanguageFallback: true,
  );
  return locale == null
      ? localeCodeFromLocale(_defaultAppLocale)
      : localeCodeFromLocale(locale);
}

Locale appLocaleFromCode(String localeCode) {
  final locale = _findSupportedLocale(
    _canonicalizeChineseLocale(_parseLocaleCode(localeCode)),
    allowLanguageFallback: true,
  );
  return locale ?? _defaultAppLocale;
}

String resolveFirstLaunchLocaleCode(Locale? locale) {
  if (locale == null) {
    return localeCodeFromLocale(_defaultAppLocale);
  }
  final requestedLocale = _canonicalizeChineseLocale(locale);
  final exactLocale = _findSupportedLocale(
    requestedLocale,
    allowLanguageFallback: false,
  );
  if (exactLocale != null) {
    return localeCodeFromLocale(exactLocale);
  }
  final languageLocale = _findSupportedLocale(
    requestedLocale,
    allowLanguageFallback: true,
  );
  if (languageLocale != null) {
    return localeCodeFromLocale(languageLocale);
  }
  return localeCodeFromLocale(_defaultAppLocale);
}

List<AppLanguageOption> supportedLanguageOptions(AppLocalizations l10n) {
  final uiLocaleCode = normalizeLocaleCode(l10n.localeName);
  final options = AppLocalizations.supportedLocales.map((locale) {
    final code = localeCodeFromLocale(locale);
    final metadata = languageMetadataForLocaleCode(code);
    return AppLanguageOption(
      code: code,
      locale: locale,
      nativeName: metadata.nativeName,
      localizedName: metadata.localizedNameFor(uiLocaleCode),
      englishName: metadata.englishName,
    );
  }).toList();
  options.sort((a, b) {
    final priorityCompare = _languageSortPriority(a.code)
        .compareTo(_languageSortPriority(b.code));
    if (priorityCompare != 0) {
      return priorityCompare;
    }
    return a.localizedName.compareTo(b.localizedName);
  });
  return List.unmodifiable(options);
}

AppLanguageMetadata languageMetadataForLocaleCode(String localeCode) {
  final normalizedCode = normalizeLocaleCode(localeCode);
  return _supportedLanguageMetadata[normalizedCode] ??
      AppLanguageMetadata(
        code: normalizedCode,
        nativeName: normalizedCode,
        englishName: normalizedCode,
        localizedNames: {defaultLocaleCode: normalizedCode},
      );
}

String languageLabelForLocaleCode(String localeCode, {AppLocalizations? l10n}) {
  final metadata = languageMetadataForLocaleCode(localeCode);
  if (l10n == null) {
    return metadata.nativeName;
  }
  return metadata.localizedNameFor(normalizeLocaleCode(l10n.localeName));
}

bool isSupportedLocaleCode(String localeCode) {
  final raw = localeCode.trim();
  if (raw.isEmpty) {
    return false;
  }
  return _findSupportedLocale(
        _canonicalizeChineseLocale(_parseLocaleCode(raw)),
        allowLanguageFallback: true,
      ) !=
      null;
}

int _languageSortPriority(String localeCode) {
  return normalizeLocaleCode(localeCode) ==
          normalizeLocaleCode(defaultLocaleCode)
      ? 0
      : 1;
}

Locale? _findSupportedLocale(
  Locale locale, {
  required bool allowLanguageFallback,
}) {
  final requestedLocale = _canonicalizeChineseLocale(locale);
  final requestedCode = localeCodeFromLocale(requestedLocale);
  for (final supportedLocale in AppLocalizations.supportedLocales) {
    if (localeCodeFromLocale(supportedLocale) == requestedCode) {
      return supportedLocale;
    }
  }
  if (!allowLanguageFallback) {
    return null;
  }
  final requestedLanguageCode = requestedLocale.languageCode.toLowerCase();
  for (final supportedLocale in AppLocalizations.supportedLocales) {
    if (supportedLocale.languageCode.toLowerCase() == requestedLanguageCode) {
      return supportedLocale;
    }
  }
  return null;
}

Locale _parseLocaleCode(String localeCode) {
  final segments = localeCode
      .trim()
      .replaceAll('_', '-')
      .split('-')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return _defaultAppLocale;
  }
  final languageCode = segments.first.toLowerCase();
  String? scriptCode;
  String? countryCode;
  if (segments.length >= 2) {
    final second = segments[1];
    if (second.length == 4) {
      scriptCode = _normalizeScriptCode(second);
      if (segments.length >= 3) {
        countryCode = segments[2].toUpperCase();
      }
    } else {
      countryCode = second.toUpperCase();
    }
  }
  return Locale.fromSubtags(
    languageCode: languageCode,
    scriptCode: scriptCode,
    countryCode: countryCode,
  );
}

String _normalizeScriptCode(String scriptCode) {
  if (scriptCode.isEmpty) {
    return scriptCode;
  }
  return '${scriptCode[0].toUpperCase()}${scriptCode.substring(1).toLowerCase()}';
}

Locale _canonicalizeChineseLocale(Locale locale) {
  if (locale.languageCode.toLowerCase() != 'zh') {
    return locale;
  }

  final normalizedScriptCode =
      locale.scriptCode == null || locale.scriptCode!.isEmpty
      ? null
      : _normalizeScriptCode(locale.scriptCode!);
  final normalizedCountryCode =
      locale.countryCode == null || locale.countryCode!.isEmpty
      ? null
      : locale.countryCode!.toUpperCase();

  const traditionalCountries = {'TW', 'HK', 'MO'};
  if (normalizedScriptCode == 'Hant' ||
      traditionalCountries.contains(normalizedCountryCode)) {
    return const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
  }

  return const Locale('zh');
}

Locale get _defaultAppLocale {
  return _findSupportedLocale(
        _parseLocaleCode(defaultLocaleCode),
        allowLanguageFallback: true,
      ) ??
      AppLocalizations.supportedLocales.first;
}
