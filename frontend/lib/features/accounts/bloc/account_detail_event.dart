import 'package:equatable/equatable.dart';
import '../models/account.dart';

abstract class AccountDetailEvent extends Equatable {
  const AccountDetailEvent();
  @override
  List<Object?> get props => [];
}

class LoadAccountDetail extends AccountDetailEvent {
  final Account account;
  const LoadAccountDetail(this.account);
  @override
  List<Object?> get props => [account];
}

class ToggleEditMode extends AccountDetailEvent {
  final bool isEditing;
  const ToggleEditMode(this.isEditing);
  @override
  List<Object?> get props => [isEditing];
}

class RefreshAccountDetail extends AccountDetailEvent {
  final String accountId;
  const RefreshAccountDetail(this.accountId);
  @override
  List<Object?> get props => [accountId];
}
