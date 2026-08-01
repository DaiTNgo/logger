enum LogLevel { info, warning, error }

class LogEntry {
  const LogEntry({
    required this.time,
    required this.level,
    required this.message,
    this.highlightedWord,
  });

  final String time;
  final LogLevel level;
  final String message;
  final String? highlightedWord;
}
