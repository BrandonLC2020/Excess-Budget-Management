class Allocation {
  final String type; // "goal" or "account"
  final String id;
  final String name;
  final double amount;
  final String reason;

  Allocation({
    required this.type,
    required this.id,
    required this.name,
    required this.amount,
    required this.reason,
  });

  factory Allocation.fromJson(Map<String, dynamic> json) {
    return Allocation(
      type: json['type'] as String,
      id: json['id'] as String,
      name: json['name'] as String,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String,
    );
  }
}

class SuggestionResult {
  final List<Allocation> allocations;
  final double totalAllocated;

  SuggestionResult({required this.allocations, required this.totalAllocated});

  factory SuggestionResult.fromJson(Map<String, dynamic> json) {
    var allocList = json['allocations'] as List? ?? [];
    List<Allocation> allocations = allocList
        .map((i) => Allocation.fromJson(i))
        .toList();

    return SuggestionResult(
      allocations: allocations,
      totalAllocated: (json['totalAllocated'] as num).toDouble(),
    );
  }
}
