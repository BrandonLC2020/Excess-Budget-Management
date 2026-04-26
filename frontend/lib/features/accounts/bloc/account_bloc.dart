import 'dart:async';
import 'package:equatable/equatable.dart';
import '../models/account.dart';
import '../repositories/account_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

// States
abstract class AccountState extends Equatable {
  const AccountState();
  @override
  List<Object?> get props => [];
}

class AccountInitial extends AccountState {}

class AccountLoading extends AccountState {}

class AccountLoaded extends AccountState {
  final List<Account> accounts;
  const AccountLoaded(this.accounts);
  @override
  List<Object?> get props => [accounts];
}

class AccountError extends AccountState {
  final String message;
  const AccountError(this.message);
  @override
  List<Object?> get props => [message];
}

// Events
abstract class AccountEvent extends Equatable {
  const AccountEvent();
  @override
  List<Object?> get props => [];
}

class LoadAccounts extends AccountEvent {}

class AddAccount extends AccountEvent {
  final String name;
  final double balance;
  const AddAccount(this.name, this.balance);
  @override
  List<Object?> get props => [name, balance];
}

class UpdateAccount extends AccountEvent {
  final String id;
  final String name;
  final double balance;
  const UpdateAccount(this.id, this.name, this.balance);
  @override
  List<Object?> get props => [id, name, balance];
}

class DeleteAccount extends AccountEvent {
  final String id;
  const DeleteAccount(this.id);
  @override
  List<Object?> get props => [id];
}

class _UpdateAccounts extends AccountEvent {
  final List<Account> accounts;
  const _UpdateAccounts(this.accounts);
  @override
  List<Object?> get props => [accounts];
}

class _HandleAccountError extends AccountEvent {
  final String message;
  const _HandleAccountError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final AccountRepository repository;
  StreamSubscription<List<Account>>? _subscription;

  AccountBloc({required this.repository}) : super(AccountInitial()) {
    on<LoadAccounts>((event, emit) async {
      emit(AccountLoading());
      await _subscription?.cancel();
      _subscription = repository.getAccountsStream().listen(
        (accounts) {
          add(_UpdateAccounts(accounts));
        },
        onError: (e) {
          add(_HandleAccountError(e.toString()));
        },
      );
    });

    on<_UpdateAccounts>((event, emit) {
      emit(AccountLoaded(event.accounts));
    });

    on<_HandleAccountError>((event, emit) {
      emit(AccountError(event.message));
    });

    on<AddAccount>((event, emit) async {
      try {
        await repository.addAccount(event.name, event.balance);
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });

    on<UpdateAccount>((event, emit) async {
      try {
        await repository.updateAccount(event.id, event.name, event.balance);
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });

    on<DeleteAccount>((event, emit) async {
      try {
        await repository.deleteAccount(event.id);
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
