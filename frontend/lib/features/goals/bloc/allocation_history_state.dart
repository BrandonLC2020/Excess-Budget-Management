import '../models/allocation.dart';

abstract class AllocationHistoryState {}

class AllocationHistoryInitial extends AllocationHistoryState {}

class AllocationHistoryLoading extends AllocationHistoryState {}

class AllocationHistoryLoaded extends AllocationHistoryState {
  final List<GoalAllocation> allocations;

  AllocationHistoryLoaded(this.allocations);
}

class AllocationHistoryError extends AllocationHistoryState {
  final String message;

  AllocationHistoryError(this.message);
}
