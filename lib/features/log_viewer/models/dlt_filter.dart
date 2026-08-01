enum DltFilterMode { multiValue, singleValue, timeRange }

class DltFilterDefinition {
  const DltFilterDefinition({
    required this.id,
    required this.label,
    required this.mode,
    this.options = const [],
  });

  final String id;
  final String label;
  final DltFilterMode mode;
  final List<String> options;
}

class DltFilter {
  const DltFilter({
    required this.fieldId,
    this.values = const [],
    this.rangeStart,
    this.rangeEnd,
  });

  final String fieldId;
  final List<String> values;
  final String? rangeStart;
  final String? rangeEnd;

  DltFilter copyWith({
    List<String>? values,
    String? rangeStart,
    String? rangeEnd,
  }) => DltFilter(
    fieldId: fieldId,
    values: values ?? this.values,
    rangeStart: rangeStart ?? this.rangeStart,
    rangeEnd: rangeEnd ?? this.rangeEnd,
  );
}

const dltFilterDefinitions = [
  DltFilterDefinition(
    id: 'ecu_id',
    label: 'ECU ID',
    mode: DltFilterMode.multiValue,
    options: ['ECU_MAIN', 'ECU_BACKUP', 'ECU_DIAG'],
  ),
  DltFilterDefinition(
    id: 'apid',
    label: 'APID',
    mode: DltFilterMode.multiValue,
    options: ['TELE', 'CORE', 'DIAG'],
  ),
  DltFilterDefinition(
    id: 'ctid',
    label: 'CTID',
    mode: DltFilterMode.multiValue,
    options: ['NetworkComm', 'Database', 'Session'],
  ),
  DltFilterDefinition(
    id: 'message_type',
    label: 'Message Type',
    mode: DltFilterMode.multiValue,
    options: ['Log', 'Trace', 'Network', 'Control'],
  ),
  DltFilterDefinition(
    id: 'log_level',
    label: 'Log Level',
    mode: DltFilterMode.multiValue,
    options: ['Fatal', 'Error', 'Warning', 'Info', 'Debug', 'Verbose'],
  ),
  DltFilterDefinition(
    id: 'trace_type',
    label: 'Trace Type',
    mode: DltFilterMode.multiValue,
    options: ['Variable', 'Function In', 'Function Out', 'State', 'VFB'],
  ),
  DltFilterDefinition(
    id: 'network_type',
    label: 'Network Type',
    mode: DltFilterMode.multiValue,
    options: ['IPC', 'CAN', 'FlexRay', 'MOST', 'Ethernet'],
  ),
  DltFilterDefinition(
    id: 'header_type',
    label: 'Header Type',
    mode: DltFilterMode.singleValue,
    options: ['Standard', 'Extended'],
  ),
  DltFilterDefinition(
    id: 'verbose_mode',
    label: 'Verbose Mode',
    mode: DltFilterMode.singleValue,
    options: ['Verbose', 'Non-verbose'],
  ),
  DltFilterDefinition(
    id: 'message_counter',
    label: 'Message Counter',
    mode: DltFilterMode.singleValue,
    options: ['0', '1', '2', '3'],
  ),
  DltFilterDefinition(
    id: 'length',
    label: 'Length',
    mode: DltFilterMode.singleValue,
    options: ['< 64 bytes', '64–256 bytes', '> 256 bytes'],
  ),
  DltFilterDefinition(
    id: 'number_of_arguments',
    label: 'Number of Arguments',
    mode: DltFilterMode.singleValue,
    options: ['0', '1', '2', '3+'],
  ),
  DltFilterDefinition(
    id: 'session_id',
    label: 'Session ID',
    mode: DltFilterMode.singleValue,
    options: ['0', '1', '2'],
  ),
  DltFilterDefinition(
    id: 'time_range',
    label: 'Time range',
    mode: DltFilterMode.timeRange,
  ),
];

DltFilterDefinition definitionFor(String fieldId) =>
    dltFilterDefinitions.firstWhere((definition) => definition.id == fieldId);
