import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../repositories/income_repository.dart';

part 'bulk_income_event.dart';
part 'bulk_income_state.dart';

class BulkIncomeBloc extends Bloc<BulkIncomeEvent, BulkIncomeState> {
  final IncomeRepository repository;
  final _uuid = const Uuid();

  BulkIncomeBloc({required this.repository})
    : super(
        BulkIncomeState(
          rows: [
            BulkIncomeRow(id: const Uuid().v4(), dateReceived: DateTime.now()),
          ],
        ),
      ) {
    on<AddIncomeRow>((event, emit) {
      final newRows = List<BulkIncomeRow>.from(state.rows)
        ..add(BulkIncomeRow(id: _uuid.v4(), dateReceived: DateTime.now()));
      emit(state.copyWith(rows: newRows));
    });

    on<RemoveIncomeRow>((event, emit) {
      final newRows = state.rows.where((r) => r.id != event.rowId).toList();
      if (newRows.isEmpty) {
        newRows.add(
          BulkIncomeRow(id: _uuid.v4(), dateReceived: DateTime.now()),
        );
      }
      emit(state.copyWith(rows: newRows));
    });

    on<UpdateIncomeRow>((event, emit) {
      final newRows = state.rows.map((row) {
        if (row.id == event.rowId) {
          return row.copyWith(
            accountId: event.accountId,
            amount: event.amount,
            description: event.description,
            dateReceived: event.dateReceived,
            clearError: true,
          );
        }
        return row;
      }).toList();
      emit(state.copyWith(rows: newRows));
    });

    on<SubmitBulkIncome>((event, emit) async {
      bool hasError = false;
      final validatedRows = state.rows.map((row) {
        if (row.amount == null || row.amount! <= 0) {
          hasError = true;
          return row.copyWith(error: 'Valid amount required');
        }
        if (row.description == null || row.description!.isEmpty) {
          hasError = true;
          return row.copyWith(error: 'Source/Description required');
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
                'amount': row.amount,
                'account_id': row.accountId,
                'description': row.description,
                'date_received': row.dateReceived
                    .toIso8601String()
                    .split('T')
                    .first,
              },
            )
            .toList();

        await repository.bulkInsertExtraIncome(insertData);
        emit(state.copyWith(isSubmitting: false, isSuccess: true));
      } catch (e) {
        emit(
          state.copyWith(isSubmitting: false, submissionError: e.toString()),
        );
      }
    });
  }
}
