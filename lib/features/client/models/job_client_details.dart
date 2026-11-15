class JobClientDetails {
  final String jobId;
  final String clientName;
  final DateTime orderDate;
  final DateTime createdAt;

  const JobClientDetails({
    required this.jobId,
    required this.clientName,
    required this.orderDate,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'jobId': jobId,
      'clientName': clientName,
      'orderDate': orderDate.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory JobClientDetails.fromJson(Map<String, dynamic> json) {
    return JobClientDetails(
      jobId: json['jobId'] as String,
      clientName: json['clientName'] as String,
      orderDate: DateTime.parse(json['orderDate'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
