// models/coach_record.dart

class CoachRecord {
  final String model;
  final String number;
  final String depot;
  final String? capacity;
  final String? bogie;
  final String? manufacturer;

  CoachRecord({
    required this.model,
    required this.number,
    required this.depot,
    this.capacity,
    this.bogie,
    this.manufacturer,
  });

  factory CoachRecord.fromJson(Map<String, dynamic> json) {
    return CoachRecord(
      model: json['型号']?.toString() ?? '',
      number: json['车号']?.toString() ?? '',
      depot: json['现配属']?.toString() ?? '',
      capacity: json['定员']?.toString(),
      bogie: json['转向架']?.toString(),
      manufacturer: json['制造厂']?.toString(),
    );
  }
}
