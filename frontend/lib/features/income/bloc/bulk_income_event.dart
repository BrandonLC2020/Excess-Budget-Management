part of 'bulk_income_bloc.dart';

abstract class BulkIncomeEvent {}

class AddIncomeRow extends BulkIncomeEvent {}

class RemoveIncomeRow extends BulkIncomeEvent {
  final String rowId;
  RemoveIncomeRow(this.rowId);
}

class UpdateIncomeRow extends BulkIncomeEvent {
  final String rowId;
  final String? accountId;
  final double? amount;
  final String? description;
  final DateTime? dateReceived;

  UpdateIncomeRow({
    required this.rowId,
    this.accountId,
    this.amount,
    this.description,
    this.dateReceived,
  });
}

class SubmitBulkIncome extends BulkIncomeEvent {}
