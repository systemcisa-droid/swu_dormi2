class RoomAssignmentModel {
  final String id;
  final String userId;
  final String building;
  final String roomNumber;
  final int bedNumber;
  final DateTime assignedDate;
  final DateTime? endDate;
  final List<String> roommateIds;
  final String status; // 'active', 'expired', 'pending'

  RoomAssignmentModel({
    required this.id,
    required this.userId,
    required this.building,
    required this.roomNumber,
    required this.bedNumber,
    required this.assignedDate,
    this.endDate,
    required this.roommateIds,
    this.status = 'active',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'building': building,
      'roomNumber': roomNumber,
      'bedNumber': bedNumber,
      'assignedDate': assignedDate.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'roommateIds': roommateIds,
      'status': status,
    };
  }

  factory RoomAssignmentModel.fromMap(Map<String, dynamic> map) {
    return RoomAssignmentModel(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      building: map['building'] ?? '',
      roomNumber: map['roomNumber'] ?? '',
      bedNumber: map['bedNumber'] ?? 0,
      assignedDate: DateTime.parse(map['assignedDate']),
      endDate: map['endDate'] != null ? DateTime.parse(map['endDate']) : null,
      roommateIds: List<String>.from(map['roommateIds'] ?? []),
      status: map['status'] ?? 'active',
    );
  }
}
