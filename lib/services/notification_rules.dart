const duplicateWindow = Duration(hours: 6);

class SpendSnapshot {
  final double amount;
  final String place;
  final DateTime timestamp;

  const SpendSnapshot({
    required this.amount,
    required this.place,
    required this.timestamp,
  });
}

String normalizePlace(String place) {
  return place.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
}

int amountCents(double amount) => (amount * 100).round();

bool packageAllowedByNames(String? packageName, Iterable<String> allowedNames) {
  if (packageName == null || packageName.trim().isEmpty) return false;
  final pkg = packageName.trim().toLowerCase();
  for (final raw in allowedNames) {
    final needle = raw.trim().toLowerCase();
    if (needle.isEmpty) continue;
    if (pkg == needle || pkg.contains(needle)) return true;
  }
  return false;
}

bool isRecentDuplicate({
  required double amount,
  required String place,
  required DateTime moment,
  required Iterable<SpendSnapshot> existing,
  Duration window = duplicateWindow,
}) {
  if (amount <= 0 || place.trim().isEmpty) return false;
  final cents = amountCents(amount);
  final key = normalizePlace(place);
  for (final spend in existing) {
    if (amountCents(spend.amount) != cents) continue;
    if (normalizePlace(spend.place) != key) continue;
    final delta = moment.difference(spend.timestamp).abs();
    if (delta <= window) return true;
  }
  return false;
}
