final class SchemaMismatchSummary {
  const SchemaMismatchSummary({
    this.extraColumnRecords = 0,
    this.missingColumnRecords = 0,
    this.regexNonMatchingRecords = 0,
    this.corruptRecordCount = 0,
  });

  final int extraColumnRecords;
  final int missingColumnRecords;
  final int regexNonMatchingRecords;
  final int corruptRecordCount;

  bool get isEmpty =>
      extraColumnRecords == 0 &&
      missingColumnRecords == 0 &&
      regexNonMatchingRecords == 0 &&
      corruptRecordCount == 0;

  int get totalRecords =>
      extraColumnRecords +
      missingColumnRecords +
      regexNonMatchingRecords +
      corruptRecordCount;

  SchemaMismatchSummary operator +(SchemaMismatchSummary other) {
    return SchemaMismatchSummary(
      extraColumnRecords: extraColumnRecords + other.extraColumnRecords,
      missingColumnRecords: missingColumnRecords + other.missingColumnRecords,
      regexNonMatchingRecords:
          regexNonMatchingRecords + other.regexNonMatchingRecords,
      corruptRecordCount: corruptRecordCount + other.corruptRecordCount,
    );
  }
}
