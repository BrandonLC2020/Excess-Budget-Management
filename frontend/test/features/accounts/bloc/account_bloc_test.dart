import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:frontend/features/accounts/bloc/account_bloc.dart';
import 'package:frontend/features/accounts/models/account.dart';
import 'package:frontend/features/accounts/repositories/account_repository.dart';
import 'dart:async';

class MockAccountRepository extends Mock implements AccountRepository {}

void main() {
  late AccountRepository repository;
  late AccountBloc bloc;
  late StreamController<List<Account>> controller;

  setUp(() {
    repository = MockAccountRepository();
    controller = StreamController<List<Account>>.broadcast();
    when(
      () => repository.getAccountsStream(),
    ).thenAnswer((_) => controller.stream);
    bloc = AccountBloc(repository: repository);
  });

  tearDown(() {
    controller.close();
    bloc.close();
  });

  final tAccounts = [
    Account(
      id: '1',
      userId: 'user1',
      name: 'Checking',
      balance: 1000.0,
      createdAt: DateTime(2023, 1, 1),
    ),
  ];

  group('AccountBloc Reactive Tests', () {
    blocTest<AccountBloc, AccountState>(
      'emits [AccountLoading, AccountLoaded] when LoadAccounts is added and stream emits data',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(LoadAccounts());
        await Future.delayed(Duration.zero);
        controller.add(tAccounts);
      },
      expect: () => [AccountLoading(), AccountLoaded(tAccounts)],
    );

    blocTest<AccountBloc, AccountState>(
      'emits [AccountLoaded] when stream emits new data after initial load',
      build: () => bloc,
      seed: () => AccountLoaded(tAccounts),
      act: (bloc) async {
        bloc.add(LoadAccounts());
        await Future.delayed(Duration.zero);
        controller.add(const []); // Emit new data
      },
      expect: () => [AccountLoading(), const AccountLoaded([])],
    );

    blocTest<AccountBloc, AccountState>(
      'emits [AccountError] when stream emits error',
      build: () => bloc,
      act: (bloc) async {
        bloc.add(LoadAccounts());
        await Future.delayed(Duration.zero);
        controller.addError('Error fetching accounts');
      },
      expect: () => [
        AccountLoading(),
        const AccountError('Error fetching accounts'),
      ],
    );

    blocTest<AccountBloc, AccountState>(
      'AddAccount calls repository.addAccount',
      build: () => bloc,
      setUp: () {
        when(
          () => repository.addAccount(any(), any()),
        ).thenAnswer((_) async => tAccounts.first);
      },
      act: (bloc) => bloc.add(const AddAccount('New Account', 100.0)),
      verify: (_) {
        verify(() => repository.addAccount('New Account', 100.0)).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'UpdateAccount calls repository.updateAccount',
      build: () => bloc,
      setUp: () {
        when(
          () => repository.updateAccount(any(), any(), any()),
        ).thenAnswer((_) async => tAccounts.first);
      },
      act: (bloc) =>
          bloc.add(const UpdateAccount('1', 'Updated Account', 200.0)),
      verify: (_) {
        verify(
          () => repository.updateAccount('1', 'Updated Account', 200.0),
        ).called(1);
      },
    );

    blocTest<AccountBloc, AccountState>(
      'DeleteAccount calls repository.deleteAccount',
      build: () => bloc,
      setUp: () {
        when(
          () => repository.deleteAccount(any()),
        ).thenAnswer((_) async => Future.value());
      },
      act: (bloc) => bloc.add(const DeleteAccount('1')),
      verify: (_) {
        verify(() => repository.deleteAccount('1')).called(1);
      },
    );
  });
}
