part of 'bulk_expenses_bloc.dart';

abstract class BulkExpensesEvent {}

class AddExpenseRow extends BulkExpensesEvent {}

class RemoveExpenseRow extends BulkExpensesEvent {
  final String rowId;
  RemoveExpenseRow(this.rowId);
}

class UpdateExpenseRow extends BulkExpensesEvent {
  final String rowId;
  final String? budgetCategoryId;
  final double? amount;
  final String? description;
  final DateTime? date;

  UpdateExpenseRow({
    required this.rowId,
    this.budgetCategoryId,
    this.amount,
    this.description,
    this.date,
  });
}

class SubmitBulkExpenses extends BulkExpensesEvent {}
