/// Origens oficiais de notificação de consumo (Play Store + SMS Caixa).
///
/// Catálogo alinhado a [banks.md] na raiz do repositório. Pacotes Android
/// quando conhecidos; palavras no título como fallback conservador.
library;

class BankNotificationSource {
  const BankNotificationSource({
    required this.id,
    required this.label,
    this.packages = const [],
    this.packageSubstrings = const [],
    this.titleKeywords = const [],
    this.titlePatterns = const [],
  });

  final String id;
  final String label;

  /// IDs exatos do pacote Android (Google Play).
  final List<String> packages;

  /// `packageName` contém o fragmento (minúsculas), para variantes do mesmo app.
  final List<String> packageSubstrings;

  /// Nome ou marca no título da notificação (fallback se o pacote não bater).
  final List<String> titleKeywords;

  /// Regexes no título (marcas curtas, ex.: Inter).
  final List<RegExp> titlePatterns;

  bool matchesPackage(String? packageName) {
    if (packageName == null || packageName.isEmpty) return false;
    final pkg = packageName.toLowerCase();
    for (final exact in packages) {
      if (pkg == exact.toLowerCase()) return true;
    }
    for (final part in packageSubstrings) {
      if (pkg.contains(part.toLowerCase())) return true;
    }
    return false;
  }

  bool matchesTitle(String title) {
    for (final pattern in titlePatterns) {
      if (pattern.hasMatch(title)) return true;
    }
    for (final keyword in titleKeywords) {
      if (_titleContainsKeyword(title, keyword)) return true;
    }
    return false;
  }
}

enum BankSourceMatchKind {
  package,
  notificationTitle,
  caixaSms,
}

class BankSourceMatch {
  const BankSourceMatch({
    required this.source,
    required this.kind,
  });

  final BankNotificationSource source;
  final BankSourceMatchKind kind;
}

/// Apps de mensagens usados pela Caixa para avisos de compra (SMS).
const caixaSmsPackages = <String>{
  'com.google.android.apps.messaging',
  'com.samsung.android.messaging',
  'com.android.mms',
  'com.microsoft.android.smsorganizer',
};

/// Bancos e fintechs com app na Play Store (banks.md).
final bankNotificationSources = <BankNotificationSource>[
  BankNotificationSource(
    id: 'bb',
    label: 'Banco do Brasil',
    packages: ['br.com.bb.android', 'com.bb.android'],
    packageSubstrings: ['bb.android'],
    titleKeywords: ['banco do brasil', 'bb:'],
  ),
  BankNotificationSource(
    id: 'itau',
    label: 'Itaú',
    packages: ['com.itau', 'com.itaucard', 'br.com.itau'],
    packageSubstrings: ['itaucard', '.itau.'],
    titleKeywords: ['itaú', 'itau'],
  ),
  BankNotificationSource(
    id: 'bradesco',
    label: 'Bradesco',
    packages: ['br.com.bradesco'],
    packageSubstrings: ['bradesco'],
    titleKeywords: ['bradesco', 'app bradesco'],
  ),
  BankNotificationSource(
    id: 'santander',
    label: 'Santander',
    packages: ['com.santander.app', 'br.com.santander'],
    packageSubstrings: ['santander'],
    titleKeywords: ['santander'],
  ),
  BankNotificationSource(
    id: 'caixa',
    label: 'Caixa',
    packages: [
      'br.com.caixa',
      'br.com.government.caixa',
      'br.gov.caixa.tem',
      'br.com.caixa.tem',
    ],
    packageSubstrings: ['caixa.tem', 'gov.caixa'],
    titleKeywords: ['caixa tem', 'caixa econômica', 'caixa economica', 'caixa'],
  ),
  BankNotificationSource(
    id: 'nubank',
    label: 'Nubank',
    packages: ['com.nu.production', 'com.nu.production.debug'],
    packageSubstrings: ['nu.production'],
    titleKeywords: ['nubank'],
  ),
  BankNotificationSource(
    id: 'inter',
    label: 'Inter',
    packages: ['br.com.intermedium', 'com.bancointer'],
    packageSubstrings: ['intermedium', 'bancointer'],
    titleKeywords: ['banco inter'],
    titlePatterns: [RegExp(r'\binter\b', caseSensitive: false)],
  ),
  BankNotificationSource(
    id: 'c6',
    label: 'C6 Bank',
    packages: ['br.com.c6bank.app'],
    packageSubstrings: ['c6bank'],
    titleKeywords: ['c6 bank', 'c6bank'],
  ),
  BankNotificationSource(
    id: 'pagbank',
    label: 'PagBank',
    packages: ['com.pagbank', 'br.com.uol.ps.myaccount'],
    packageSubstrings: ['pagbank', 'ps.myaccount'],
    titleKeywords: ['pagbank', 'pagseguro'],
  ),
  BankNotificationSource(
    id: 'mercado_pago',
    label: 'Mercado Pago',
    packages: ['com.mercadopago.wallet'],
    packageSubstrings: ['mercadopago'],
    titleKeywords: ['mercado pago'],
  ),
  BankNotificationSource(
    id: 'picpay',
    label: 'PicPay',
    packages: ['com.picpay'],
    packageSubstrings: ['picpay'],
    titleKeywords: ['picpay'],
  ),
  BankNotificationSource(
    id: 'neon',
    label: 'Neon',
    packages: ['br.com.neon'],
    titleKeywords: ['neon'],
  ),
  BankNotificationSource(
    id: 'iti',
    label: 'iti',
    packages: ['br.com.itau.iti', 'com.itau.iti'],
    packageSubstrings: ['.iti'],
    titleKeywords: ['iti'],
  ),
  BankNotificationSource(
    id: 'next',
    label: 'Next',
    packages: ['com.next', 'br.com.next'],
    titleKeywords: ['next'],
  ),
  BankNotificationSource(
    id: 'original',
    label: 'Original',
    packages: ['com.original.bank', 'br.com.original.bank'],
    packageSubstrings: ['original.bank'],
    titleKeywords: ['original'],
  ),
  BankNotificationSource(
    id: 'bmg',
    label: 'Banco BMG',
    packages: ['br.com.bancobmg'],
    packageSubstrings: ['bancobmg'],
    titleKeywords: ['banco bmg', 'bmg'],
  ),
  BankNotificationSource(
    id: 'pan',
    label: 'Banco PAN',
    packages: ['br.com.bancopan'],
    packageSubstrings: ['bancopan'],
    titleKeywords: ['banco pan'],
  ),
  BankNotificationSource(
    id: 'agibank',
    label: 'Agibank',
    packages: ['br.com.agibank'],
    packageSubstrings: ['agibank'],
    titleKeywords: ['agibank'],
  ),
  BankNotificationSource(
    id: 'btg',
    label: 'BTG Pactual',
    packages: ['br.com.btgpactual.digital', 'com.btgpactual.app'],
    packageSubstrings: ['btgpactual'],
    titleKeywords: ['btg pactual', 'btg'],
  ),
  BankNotificationSource(
    id: 'bs2',
    label: 'Banco BS2',
    packages: ['br.com.bs2'],
    titleKeywords: ['banco bs2', 'bs2'],
  ),
  BankNotificationSource(
    id: 'mercantil',
    label: 'Banco Mercantil',
    packages: ['br.com.mercantil'],
    packageSubstrings: ['br.com.mercantil'],
    titleKeywords: ['banco mercantil'],
  ),
  BankNotificationSource(
    id: 'bv',
    label: 'Banco BV',
    packages: ['br.com.bv', 'br.com.bancobv'],
    packageSubstrings: ['bancobv'],
    titleKeywords: ['banco bv'],
  ),
  BankNotificationSource(
    id: 'sicoob',
    label: 'Sicoob',
    packages: ['br.com.sicoob'],
    packageSubstrings: ['sicoob'],
    titleKeywords: ['sicoob'],
  ),
  BankNotificationSource(
    id: 'sicredi',
    label: 'Sicredi',
    packages: ['br.com.sicredi.app', 'br.com.sicredi'],
    packageSubstrings: ['sicredi'],
    titleKeywords: ['sicredi'],
  ),
  BankNotificationSource(
    id: '99pay',
    label: '99Pay',
    packages: ['com.pay99', 'com.app99.pay'],
    packageSubstrings: ['99pay'],
    titleKeywords: ['99pay'],
  ),
  BankNotificationSource(
    id: 'digimais',
    label: 'Banco Digimais',
    packages: ['br.com.digimais'],
    packageSubstrings: ['digimais'],
    titleKeywords: ['digimais', 'banco digimais'],
  ),
  BankNotificationSource(
    id: 'zro',
    label: 'Zro Bank',
    packages: ['br.com.zrobank', 'bank.zro'],
    packageSubstrings: ['zrobank', 'zro.bank'],
    titleKeywords: ['zro bank'],
  ),
  BankNotificationSource(
    id: 'stark',
    label: 'Stark Bank',
    packages: ['com.starkbank'],
    packageSubstrings: ['starkbank'],
    titleKeywords: ['stark bank', 'starkbank'],
  ),
  BankNotificationSource(
    id: 's3',
    label: 'S3 Bank',
    packages: ['br.com.s3bank'],
    packageSubstrings: ['s3bank'],
    titleKeywords: ['s3 bank'],
  ),
  BankNotificationSource(
    id: 'ngcash',
    label: 'NG.CASH',
    packages: ['ng.cash.app', 'com.ng.cash'],
    packageSubstrings: ['ng.cash'],
    titleKeywords: ['ng.cash', 'ng cash'],
  ),
  BankNotificationSource(
    id: 'n26',
    label: 'N26',
    packages: ['de.number26.android'],
    packageSubstrings: ['number26'],
    titleKeywords: ['n26'],
  ),
  BankNotificationSource(
    id: 'digio',
    label: 'Banco Digio',
    packages: ['br.com.bancodigio', 'br.com.digio'],
    packageSubstrings: ['bancodigio'],
    titleKeywords: ['banco digio', 'digio'],
  ),
];

final _caixaSource = bankNotificationSources.firstWhere((s) => s.id == 'caixa');

final _caixaSmsTextRe = RegExp(
  r'caixa(\s+econ[oô]mica|\s+tem)?|\bcaixa\s*:',
  caseSensitive: false,
);

bool _titleContainsKeyword(String title, String keyword) {
  final k = keyword.trim().toLowerCase();
  if (k.isEmpty) return false;
  if (k.length <= 3) {
    return RegExp(r'\b${RegExp.escape(k)}\b', caseSensitive: false).hasMatch(title);
  }
  return title.toLowerCase().contains(k);
}

bool isCaixaSmsPackage(String? packageName) {
  if (packageName == null || packageName.isEmpty) return false;
  return caixaSmsPackages.contains(packageName.toLowerCase());
}

bool looksLikeCaixaSms(String title, String body) {
  return _caixaSmsTextRe.hasMatch('$title $body');
}

/// Resolve a origem bancária da notificação, se estiver no catálogo.
BankSourceMatch? matchBankNotificationSource({
  String? packageName,
  required String title,
  required String body,
}) {
  for (final source in bankNotificationSources) {
    if (source.matchesPackage(packageName)) {
      return BankSourceMatch(source: source, kind: BankSourceMatchKind.package);
    }
  }

  if (isCaixaSmsPackage(packageName) && looksLikeCaixaSms(title, body)) {
    return BankSourceMatch(
      source: _caixaSource,
      kind: BankSourceMatchKind.caixaSms,
    );
  }

  if (isCaixaSmsPackage(packageName)) {
    return null;
  }

  for (final source in bankNotificationSources) {
    if (source.matchesTitle(title)) {
      return BankSourceMatch(
        source: source,
        kind: BankSourceMatchKind.notificationTitle,
      );
    }
  }

  return null;
}

BankNotificationSource? labelForPackage(String? packageName) {
  if (packageName == null) return null;
  for (final source in bankNotificationSources) {
    if (source.matchesPackage(packageName)) return source;
  }
  return null;
}
