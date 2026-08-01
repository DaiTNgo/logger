import 'package:logger/models/log_entry.dart';

const sampleLogs = <LogEntry>[
  LogEntry(
    time: '10:42:01',
    level: LogLevel.info,
    message:
        'System initialization complete. Module [core] started successfully in 142ms.',
  ),
  LogEntry(
    time: '10:42:05',
    level: LogLevel.info,
    message: 'Network listener bound to 0.0.0.0:8080. Awaiting connections.',
  ),
  LogEntry(
    time: '10:45:12',
    level: LogLevel.warning,
    message:
        'High memory usage detected in worker pool. Current utilization: 85%. Consider scaling.',
  ),
  LogEntry(
    time: '10:48:33',
    level: LogLevel.error,
    message:
        'Connection timeout while attempting to reach database replica at 192.168.1.5:5432. Retrying in 5s...',
    highlightedWord: 'timeout',
  ),
  LogEntry(
    time: '10:48:38',
    level: LogLevel.info,
    message: 'Retry 1/3: Attempting connection to secondary replica.',
  ),
  LogEntry(
    time: '10:48:43',
    level: LogLevel.error,
    message:
        "Failed to resolve host 'db-replica-sec.internal'. DNS query timeout after 5000ms.",
    highlightedWord: 'timeout',
  ),
  LogEntry(
    time: '10:49:01',
    level: LogLevel.info,
    message: 'User session terminated gracefully. [UID: 9482-A]',
  ),
  LogEntry(
    time: '10:50:15',
    level: LogLevel.info,
    message: "Scheduled task 'LogRotation' completed. 4 files compressed.",
  ),
  LogEntry(
    time: '10:52:05',
    level: LogLevel.warning,
    message:
        'Deprecation warning: API endpoint /v1/users/list will be removed in next release.',
  ),
  LogEntry(
    time: '10:55:00',
    level: LogLevel.info,
    message: 'Heartbeat sent to orchestrator. Status: HEALTHY.',
  ),
];
