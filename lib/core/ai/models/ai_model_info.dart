import 'package:equatable/equatable.dart';

class AiModelInfo extends Equatable {
  final String key;
  final String name;
  final String description;
  final String format; // 'ONNX', 'TFLite'
  final int sampleRate;
  final double sizeMb;
  final String license;
  final String status; // 'ready', 'missing', 'downloading', 'error'
  final bool isLoadedInMemory;
  final double ramUsageMb;
  final String? sha256;
  final String? diskPath;
  final String? error;

  const AiModelInfo({
    required this.key,
    required this.name,
    required this.description,
    required this.format,
    required this.sampleRate,
    required this.sizeMb,
    required this.license,
    required this.status,
    this.isLoadedInMemory = false,
    this.ramUsageMb = 0.0,
    this.sha256,
    this.diskPath,
    this.error,
  });

  AiModelInfo copyWith({
    String? status,
    bool? isLoadedInMemory,
    double? ramUsageMb,
    String? diskPath,
    String? error,
  }) {
    return AiModelInfo(
      key: key,
      name: name,
      description: description,
      format: format,
      sampleRate: sampleRate,
      sizeMb: sizeMb,
      license: license,
      status: status ?? this.status,
      isLoadedInMemory: isLoadedInMemory ?? this.isLoadedInMemory,
      ramUsageMb: ramUsageMb ?? this.ramUsageMb,
      sha256: sha256,
      diskPath: diskPath ?? this.diskPath,
      error: error ?? this.error,
    );
  }

  Map<String, dynamic> toJson() => {
    'key': key,
    'name': name,
    'description': description,
    'format': format,
    'sample_rate': sampleRate,
    'size_mb': sizeMb,
    'license': license,
    'status': status,
    'is_loaded_in_memory': isLoadedInMemory,
    'ram_usage_mb': ramUsageMb,
    'sha256': sha256,
    'disk_path': diskPath,
    'error': error,
  };

  @override
  List<Object?> get props => [
    key,
    name,
    status,
    isLoadedInMemory,
    ramUsageMb,
    diskPath,
  ];
}
