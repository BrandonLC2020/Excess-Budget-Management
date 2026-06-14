import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/goals/models/goal.dart';
import 'package:frontend/features/goals/repositories/goal_repository.dart';
import 'package:frontend/features/income/bloc/overtime_bloc.dart';
import 'package:frontend/features/income/models/overtime_projection.dart';
import 'package:frontend/features/income/models/overtime_settings.dart';
import 'package:frontend/features/income/repositories/income_repository.dart';

class MockIncomeRepository extends Mock implements IncomeRepository {}

class MockGoalRepository extends Mock implements GoalRepository {}

void main() {
  late MockIncomeRepository mockIncomeRepository;
  late MockGoalRepository mockGoalRepository;
  late OvertimeBloc overtimeBloc;

  final testSettings = OvertimeSettings(
    hourlyBaseRate: 40.0,
    overtimeMultiplier: 1.5,
    estimatedTaxRate: 0.20,
  );

  final testGoals = [
    Goal(
      id: 'goal-1',
      userId: 'user-1',
      name: 'Europe Trip',
      targetAmount: 1000.0,
      currentAmount: 200.0,
      type: 'short_term',
      category: 'purchase',
      createdAt: DateTime.parse('2024-03-20T00:00:00Z'),
    ),
  ];

  final testProjection = OvertimeProjection(
    netHourlyRate: 48.0,
    weeklyOvertimeNetIncome: 480.0,
    monthlyOvertimeNetIncome: 2080.0,
    totalHoursNeeded: 16.67,
    monthsToCompleteStandard: 4.0,
    monthsToCompleteWithOvertime: 0.35,
    monthsSaved: 3.65,
  );

  setUp(() {
    mockIncomeRepository = MockIncomeRepository();
    mockGoalRepository = MockGoalRepository();
    overtimeBloc = OvertimeBloc(
      incomeRepository: mockIncomeRepository,
      goalRepository: mockGoalRepository,
    );
  });

  tearDown(() {
    overtimeBloc.close();
  });

  test('initial state has default values', () {
    expect(overtimeBloc.state.isLoading, false);
    expect(overtimeBloc.state.isSaving, false);
    expect(overtimeBloc.state.isCalculating, false);
    expect(overtimeBloc.state.settings, null);
    expect(overtimeBloc.state.goals, isEmpty);
    expect(overtimeBloc.state.overtimeHoursPerWeek, 0.0);
    expect(overtimeBloc.state.standardContribution, 0.0);
    expect(overtimeBloc.state.projection, null);
  });

  blocTest<OvertimeBloc, OvertimeState>(
    'FetchOvertimeData loads settings and goals, then triggers projection',
    build: () {
      when(
        () => mockIncomeRepository.getOvertimeSettings(),
      ).thenAnswer((_) async => testSettings);
      when(
        () => mockGoalRepository.getGoals(),
      ).thenAnswer((_) async => testGoals);
      when(
        () => mockIncomeRepository.getOvertimeProjection(
          overtimeHoursPerWeek: 0.0,
          standardContribution: 0.0,
          goalId: 'goal-1',
        ),
      ).thenAnswer((_) async => testProjection);
      return overtimeBloc;
    },
    act: (bloc) => bloc.add(FetchOvertimeData()),
    expect: () => [
      // 1. Shows loading
      isA<OvertimeState>().having((s) => s.isLoading, 'isLoading', true),
      // 2. Loads settings and goals
      isA<OvertimeState>()
          .having((s) => s.isLoading, 'isLoading', false)
          .having((s) => s.settings, 'settings', testSettings)
          .having((s) => s.goals, 'goals', testGoals)
          .having((s) => s.selectedGoalId, 'selectedGoalId', 'goal-1'),
      // 3. Triggers calculation
      isA<OvertimeState>().having(
        (s) => s.isCalculating,
        'isCalculating',
        true,
      ),
      // 4. Receives projection
      isA<OvertimeState>()
          .having((s) => s.isCalculating, 'isCalculating', false)
          .having((s) => s.projection, 'projection', testProjection),
    ],
  );

  blocTest<OvertimeBloc, OvertimeState>(
    'UpdateOvertimeHours triggers projection calculation',
    build: () {
      // Seed state
      overtimeBloc.emit(
        OvertimeState(
          settings: testSettings,
          goals: testGoals,
          selectedGoalId: 'goal-1',
          overtimeHoursPerWeek: 0.0,
        ),
      );

      when(
        () => mockIncomeRepository.getOvertimeProjection(
          overtimeHoursPerWeek: 10.0,
          standardContribution: 0.0,
          goalId: 'goal-1',
        ),
      ).thenAnswer((_) async => testProjection);
      return overtimeBloc;
    },
    act: (bloc) => bloc.add(UpdateOvertimeHours(10.0)),
    expect: () => [
      // 1. Hours updated
      isA<OvertimeState>().having((s) => s.overtimeHoursPerWeek, 'hours', 10.0),
      // 2. Starts calculating
      isA<OvertimeState>()
          .having((s) => s.overtimeHoursPerWeek, 'hours', 10.0)
          .having((s) => s.isCalculating, 'isCalculating', true),
      // 3. Gets projection
      isA<OvertimeState>()
          .having((s) => s.overtimeHoursPerWeek, 'hours', 10.0)
          .having((s) => s.isCalculating, 'isCalculating', false)
          .having((s) => s.projection, 'projection', testProjection),
    ],
  );
}
