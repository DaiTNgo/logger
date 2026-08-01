enum LogLevel { info, warning, error }

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.dltValues = const {},
    this.highlightedWord,
  });

  final String time;
  final LogLevel level;
  final String message;
  final Map<String, String> dltValues;
  final String? highlightedWord;
}
