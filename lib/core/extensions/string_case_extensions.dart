extension StringCaseExtensions on String {
  /// "basmati rice" -> "Basmati Rice", "BASMATI RICE" -> "Basmati Rice"
  /// Applied at save time (not display time) so the data itself stays
  /// consistently formatted everywhere it's used — receipts, search,
  /// admin lists, sorting — not just wherever this happens to be called.
  String toTitleCase() {
    final trimmed = trim();
    if (trimmed.isEmpty) return trimmed;
    return trimmed.split(RegExp(r'\s+')).map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}
