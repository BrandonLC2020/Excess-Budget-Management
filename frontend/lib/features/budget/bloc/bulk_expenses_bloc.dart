import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../repositories/budget_repository.dart';

part 'bulk_expenses_event.dart';
part 'bulk_expenses_state.dart';

class BulkExpensesBloc extends Bloc<BulkExpensesEvent, BulkExpensesState> {
  final BudgetRepository repository;
  final _uuid = const Uuid();

  BulkExpensesBloc({required this.repository})
    : super(
        BulkExpensesState(
          rows: [BulkExpenseRow(id: const Uuid().v4(), date: DateTime.now())],
        ),
      ) {
    on<AddExpenseRow>((event, emit) {
      final newRows = List<BulkExpenseRow>.from(state.rows)
        ..add(BulkExpenseRow(id: _uuid.v4(), date: DateTime.now()));
      emit(state.copyWith(rows: newRows));
    });

    on<RemoveExpenseRow>((event, emit) {
      final newRows = state.rows.where((r) => r.id != event.rowId).toList();
      if (newRows.isEmpty) {
        newRows.add(BulkExpenseRow(id: _uuid.v4(), date: DateTime.now()));
      }
      emit(state.copyWith(rows: newRows));
    });

    on<UpdateExpenseRow>((event, emit) {
      final newRows = state.rows.map((row) {
        if (row.id == event.rowId) {
          return row.copyWith(
            budgetCategoryId: event.budgetCategoryId,
            accountId: event.accountId,
            amount: event.amount,
            description: event.description,
            date: event.date,
            clearError: true,
          );
        }
        return row;
      }).toList();
      emit(state.copyWith(rows: newRows));
    });

    on<SubmitBulkExpenses>((event, emit) async {
      bool hasError = false;
      final validatedRows = state.rows.map((row) {
        if (row.amount == null || row.amount! <= 0) {
          hasError = true;
          return row.copyWith(error: 'Valid amount required');
        }
        if (row.budgetCategoryId == null || row.budgetCategoryId!.isEmpty) {
          hasError = true;
          return row.copyWith(error: 'Category required');
        }
        return row.copyWith(clearError: true);
      }).toList();

      if (hasError) {
        emit(
          state.copyWith(
            rows: validatedRows,
            submissionError: 'Please fix the errors in the rows.',
          ),
        );
        return;
      }

      emit(state.copyWith(isSubmitting: true, submissionError: null));

      try {
        final insertData = validatedRows
            .map(
              (row) => {
                'budget_category_id': row.budgetCategoryId,
                'account_id': row.accountId,
                'amount': row.amount,
                'description': row.description ?? '',
                'date': row.date.toIso8601String().split('T').first,
              },
            )
            .toList();

        await repository.bulkInsertExpenses(insertData);
        emit(state.copyWith(isSubmitting: false, isSuccess: true));
      } catch (e) {
        emit(
          state.copyWith(isSubmitting: false, submissionError: e.toString()),
        );
      }
    });
  }
}
