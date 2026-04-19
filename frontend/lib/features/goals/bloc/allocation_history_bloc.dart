import 'package:flutter_bloc/flutter_bloc.dart';
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
        emit(AllocationHistoryLoaded(allocations));
      } catch (e) {
        emit(AllocationHistoryError(e.toString()));
      }
    });
  }
}
