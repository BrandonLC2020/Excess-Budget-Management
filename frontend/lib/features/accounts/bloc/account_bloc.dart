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

// Bloc
class AccountBloc extends Bloc<AccountEvent, AccountState> {
  final AccountRepository repository;

  AccountBloc({required this.repository}) : super(AccountInitial()) {
    on<LoadAccounts>((event, emit) async {
      emit(AccountLoading());
      try {
        final accounts = await repository.getAccounts();
        emit(AccountLoaded(accounts));
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });

    on<AddAccount>((event, emit) async {
      try {
        await repository.addAccount(event.name, event.balance);
        add(LoadAccounts());
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });

    on<UpdateAccount>((event, emit) async {
      try {
        await repository.updateAccount(event.id, event.name, event.balance);
        add(LoadAccounts());
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });

    on<DeleteAccount>((event, emit) async {
      try {
        await repository.deleteAccount(event.id);
        add(LoadAccounts());
      } catch (e) {
        emit(AccountError(e.toString()));
      }
    });
  }
}
