part of 'bulk_expenses_bloc.dart';

class BulkExpenseRow {
  final String id;
  final String? budgetCategoryId;
  final String? accountId;
  final double? amount;
  final String? description;
  final DateTime date;
  final String? error;

  BulkExpenseRow({
    required this.id,
    this.budgetCategoryId,
    this.accountId,
    this.amount,
    this.description,
    required this.date,
    this.error,
  });

  BulkExpenseRow copyWith({
    Wrapped<String?>? budgetCategoryId,
    Wrapped<String?>? accountId,
    Wrapped<double?>? amount,
    Wrapped<String?>? description,
    DateTime? date,
    String? error,
    bool clearError = false,
  }) {
    return BulkExpenseRow(
      id: id,
      budgetCategoryId: budgetCategoryId != null
          ? budgetCategoryId.value
          : this.budgetCategoryId,
      accountId: accountId != null ? accountId.value : this.accountId,
      amount: amount != null ? amount.value : this.amount,
      description: description != null ? description.value : this.description,
      date: date ?? this.date,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BulkExpensesState {
  final List<BulkExpenseRow> rows;
  final bool isSubmitting;
  final String? submissionError;
  final bool isSuccess;

  BulkExpensesState({
    required this.rows,
    this.isSubmitting = false,
    this.submissionError,
    this.isSuccess = false,
  });

  BulkExpensesState copyWith({
    List<BulkExpenseRow>? rows,
    bool? isSubmitting,
    String? submissionError,
    bool? isSuccess,
  }) {
    return BulkExpensesState(
      rows: rows ?? this.rows,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: submissionError,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}
