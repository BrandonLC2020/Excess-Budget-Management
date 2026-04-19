import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:frontend/features/accounts/presentation/screens/accounts_screen.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/accounts/presentation/widgets/account_detail_view.dart';

class MockAccountBloc extends Mock implements AccountBloc {}

void main() {
  late MockAccountBloc mockAccountBloc;
  final testAccount = Account(
    id: '1',
    userId: 'u1',
    name: 'Test Account',
    balance: 100.0,
    createdAt: DateTime.now(),
  );

  setUpAll(() {
    registerFallbackValue(LoadAccounts());
  });

  setUp(() {
    mockAccountBloc = MockAccountBloc();
    when(() => mockAccountBloc.state).thenReturn(AccountLoaded([testAccount]));
    when(() => mockAccountBloc.stream).thenAnswer((_) => Stream.value(AccountLoaded([testAccount])));
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: BlocProvider<AccountBloc>.value(
        value: mockAccountBloc,
        child: const AccountsScreen(),
      ),
    );
  }

  testWidgets('AccountsScreen shows account list', (tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    expect(find.text('Test Account'), findsOneWidget);
    expect(find.text('\$100.00'), findsOneWidget);
  });

  testWidgets('In compact mode, tapping account opens dialog', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.text('Test Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Edit Account'), findsOneWidget);
  });

  testWidgets('In expanded mode, tapping account shows detail view in right pane', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(createWidgetUnderTest());
    
    // Initially no detail view selected
    expect(find.text('Select an item to view details'), findsOneWidget);

    await tester.tap(find.text('Test Account'));
    await tester.pumpAndSettle();

    expect(find.byType(AccountDetailView), findsOneWidget);
    expect(find.text('Edit Account'), findsOneWidget);
    // Should NOT be an AlertDialog
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('FloatingActionButton opens add dialog in both modes', (tester) async {
    // Compact mode
    tester.view.physicalSize = const Size(400, 800);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add Account'), findsOneWidget);
    await tester.tap(find.text('Cancel')); // Assuming there is a cancel or we can just pump
    await tester.pumpAndSettle();

    // Expanded mode
    tester.view.physicalSize = const Size(1200, 800);
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('Add Account'), findsOneWidget);
    expect(find.byType(AlertDialog), findsOneWidget);
  });
}
