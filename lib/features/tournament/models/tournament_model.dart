class TournamentModel {
  final String id;
  final String title;
  final int entryFee;
  final String prizePool;
  final int totalSlots;
  final int filledSlots;
  final String status;

  TournamentModel({
    required this.id,
    required this.title,
    required this.entryFee,
    required this.prizePool,
    required this.totalSlots,
    required this.filledSlots,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'entryFee': entryFee,
      'prizePool': prizePool,
      'totalSlots': totalSlots,
      'filledSlots': filledSlots,
      'status': status,
    };
  }

  factory TournamentModel.fromMap(String id, Map<String, dynamic> map) {
    return TournamentModel(
      id: id,
      title: map['title'] ?? '',
      entryFee: map['entryFee'] is int 
          ? map['entryFee'] as int 
          : (int.tryParse(map['entryFee']?.toString() ?? '') ?? 0),
      prizePool: (map['prizePool'] ?? '').toString(),
      totalSlots: map['totalSlots'] is int 
          ? map['totalSlots'] as int 
          : (int.tryParse(map['totalSlots']?.toString() ?? '') ?? 0),
      filledSlots: map['filledSlots'] is int 
          ? map['filledSlots'] as int 
          : (int.tryParse(map['filledSlots']?.toString() ?? '') ?? 0),
      status: map['status'] ?? 'upcoming',
    );
  }
}