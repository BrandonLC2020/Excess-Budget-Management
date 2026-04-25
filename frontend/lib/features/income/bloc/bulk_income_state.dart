part of 'bulk_income_bloc.dart';

class BulkIncomeRow {
  final String id;
  final String? accountId;
  final String? categoryId;
  final double? amount;
  final String? description;
  final DateTime dateReceived;
  final String? error;

  BulkIncomeRow({
    required this.id,
    this.accountId,
    this.categoryId,
    this.amount,
    this.description,
    required this.dateReceived,
    this.error,
  });

  BulkIncomeRow copyWith({
    Wrapped<String?>? accountId,
    Wrapped<String?>? categoryId,
    Wrapped<double?>? amount,
    Wrapped<String?>? description,
    DateTime? dateReceived,
    String? error,
    bool clearError = false,
  }) {
    return BulkIncomeRow(
      id: id,
      accountId: accountId != null ? accountId.value : this.accountId,
      categoryId: categoryId != null ? categoryId.value : this.categoryId,
      amount: amount != null ? amount.value : this.amount,
      description: description != null ? description.value : this.description,
      dateReceived: dateReceived ?? this.dateReceived,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class BulkIncomeState {
  final List<BulkIncomeRow> rows;
  final bool isSubmitting;
  final String? submissionError;
  final bool isSuccess;

  BulkIncomeState({
    required this.rows,
    this.isSubmitting = false,
    this.submissionError,
    this.isSuccess = false,
  });

  BulkIncomeState copyWith({
    List<BulkIncomeRow>? rows,
    bool? isSubmitting,
    String? submissionError,
    bool? isSuccess,
  }) {
    return BulkIncomeState(
      rows: rows ?? this.rows,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      submissionError: submissionError,
      isSuccess: isSuccess ?? this.isSuccess,
    );
  }
}
