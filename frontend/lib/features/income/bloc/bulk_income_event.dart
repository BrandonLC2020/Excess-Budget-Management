part of 'bulk_income_bloc.dart';

abstract class BulkIncomeEvent {}

class AddIncomeRow extends BulkIncomeEvent {}

class RemoveIncomeRow extends BulkIncomeEvent {
  final String rowId;
  RemoveIncomeRow(this.rowId);
}

class UpdateIncomeRow extends BulkIncomeEvent {
  final String rowId;
  final Wrapped<String?>? accountId;
  final Wrapped<String?>? categoryId;
  final Wrapped<double?>? amount;
  final Wrapped<String?>? description;
  final DateTime? dateReceived;

  UpdateIncomeRow({
    required this.rowId,
    this.accountId,
    this.categoryId,
    this.amount,
    this.description,
    this.dateReceived,
  });
}

class SubmitBulkIncome extends BulkIncomeEvent {}
