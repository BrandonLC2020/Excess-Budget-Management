import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../repositories/goal_repository.dart';
import 'allocation_history_event.dart';
import 'allocation_history_state.dart';

class AllocationHistoryBloc
    extends Bloc<AllocationHistoryEvent, AllocationHistoryState> {
  final GoalRepository goalRepository;

  AllocationHistoryBloc({required this.goalRepository})
    : super(AllocationHistoryInitial()) {
    on<FetchAllocationHistory>((event, emit) async {
      emit(AllocationHistoryLoading());
      try {
        final allocations = await goalRepository.getAllocations();

        final List<AllocationListItem> groupedItems = [];
        String? currentMonth;

        for (final allocation in allocations) {
          final monthStr = DateFormat('MMMM yyyy').format(allocation.createdAt);
          if (monthStr != currentMonth) {
            groupedItems.add(AllocationMonthHeader(monthStr));
            currentMonth = monthStr;
          }
          groupedItems.add(AllocationItem(allocation));
        }

        emit(AllocationHistoryLoaded(groupedItems));
      } catch (e) {
        emit(AllocationHistoryError(e.toString()));
      }
    });
  }
}
