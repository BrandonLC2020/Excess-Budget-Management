import 'package:flutter_test/flutter_test.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:frontend/features/goals/bloc/allocation_history_bloc.dart';
import 'package:frontend/features/goals/bloc/allocation_history_event.dart';
import 'package:frontend/features/goals/bloc/allocation_history_state.dart';
import 'package:frontend/features/goals/models/allocation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';

class MockGoalRepository extends Mock implements GoalRepository {}

void main() {
  late MockGoalRepository mockRepo;
  late AllocationHistoryBloc bloc;

  setUp(() {
    mockRepo = MockGoalRepository();
    bloc = AllocationHistoryBloc(goalRepository: mockRepo);
  });

  tearDown(() {
    bloc.close();
  });

  blocTest<AllocationHistoryBloc, AllocationHistoryState>(
    'emits Loading then Loaded with grouped items',
    build: () {
      when(() => mockRepo.getAllocations()).thenAnswer(
        (_) async => [
          GoalAllocation(
            id: '1',
            userId: 'u1',
            goalId: 'g1',
            amount: 10,
            createdAt: DateTime(2026, 4, 15),
          ),
          GoalAllocation(
            id: '2',
            userId: 'u1',
            goalId: 'g2',
            amount: 20,
            createdAt: DateTime(2026, 3, 10),
          ),
        ],
      );
      return bloc;
    },
    act: (bloc) => bloc.add(FetchAllocationHistory()),
    expect: () => [
      isA<AllocationHistoryLoading>(),
      isA<AllocationHistoryLoaded>().having(
        (s) => s.items.length,
        'contains 2 headers and 2 items',
        4,
      ),
    ],
  );
}
