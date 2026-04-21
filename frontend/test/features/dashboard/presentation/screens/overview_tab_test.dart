import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/dashboard/presentation/screens/overview_tab.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_bloc.dart';
import 'package:frontend/features/dashboard/bloc/dashboard_state.dart';
import 'package:frontend/features/dashboard/models/allocation.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';

class MockDashboardBloc extends Mock implements DashboardBloc {}

class MockGoalRepository extends Mock implements GoalRepository {}

void main() {
  late MockDashboardBloc mockDashboardBloc;
  late MockGoalRepository mockGoalRepository;

  setUp(() {
    mockDashboardBloc = MockDashboardBloc();
    mockGoalRepository = MockGoalRepository();

    when(() => mockDashboardBloc.state).thenReturn(DashboardInitial());
    when(
      () => mockDashboardBloc.stream,
    ).thenAnswer((_) => const Stream.empty());
    when(() => mockDashboardBloc.goalRepository).thenReturn(mockGoalRepository);
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<DashboardBloc>.value(
        value: mockDashboardBloc,
        child: const OverviewTab(),
      ),
    );
  }

  testWidgets('renders Column in compact mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    final result = SuggestionResult(
      allocations: [
        Allocation(
          id: '1',
          name: 'Goal 1',
          amount: 100,
          reason: 'Test',
          type: 'goal',
        ),
      ],
      totalAllocated: 100,
    );

    when(
      () => mockDashboardBloc.state,
    ).thenReturn(DashboardSuggestionsLoaded(result, []));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(
      find.byType(Column),
      findsWidgets,
    ); // Column is used in many places, so findsWidgets
    expect(find.byType(GridView), findsNothing);

    addTearDown(tester.view.resetPhysicalSize);
  });

  testWidgets('renders GridView in expanded mode', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;

    final result = SuggestionResult(
      allocations: [
        Allocation(
          id: '1',
          name: 'Goal 1',
          amount: 100,
          reason: 'Test',
          type: 'goal',
        ),
        Allocation(
          id: '2',
          name: 'Goal 2',
          amount: 200,
          reason: 'Test',
          type: 'goal',
        ),
      ],
      totalAllocated: 300,
    );

    when(
      () => mockDashboardBloc.state,
    ).thenReturn(DashboardSuggestionsLoaded(result, []));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump();

    expect(find.byType(GridView), findsOneWidget);

    addTearDown(tester.view.resetPhysicalSize);
  });
}
