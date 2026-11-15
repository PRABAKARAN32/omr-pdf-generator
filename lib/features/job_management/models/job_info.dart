class JobInfo {
  final String id;
  final String clientName;
  final DateTime orderDate;
  final DateTime? generatedAt;
  final int recordCount;
  final String barcodeFormat;
  final String pdfFileName;

  const JobInfo({
    required this.id,
    required this.clientName,
    required this.orderDate,
    this.generatedAt,
    required this.recordCount,
    required this.barcodeFormat,
    required this.pdfFileName,
  });

  factory JobInfo.fromJson(Map<String, dynamic> json) {
    return JobInfo(
      id: json['id'] as String,
      clientName: json['clientName'] as String,
      orderDate: DateTime.parse(json['orderDate'] as String),
      generatedAt: json['generatedAt'] == null
          ? null
          : DateTime.parse(json['generatedAt'] as String),
      recordCount: (json['recordCount'] as num).toInt(),
      barcodeFormat: json['barcodeFormat'] as String,
      pdfFileName: json['pdfFileName'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'clientName': clientName,
      'orderDate': orderDate.toIso8601String(),
      'generatedAt': generatedAt?.toIso8601String(),
      'recordCount': recordCount,
      'barcodeFormat': barcodeFormat,
      'pdfFileName': pdfFileName,
    };
  }
}
