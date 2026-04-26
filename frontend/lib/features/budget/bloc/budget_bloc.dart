import 'package:equatable/equatable.dart';
import '../models/budget_category.dart';
import '../repositories/budget_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'dart:async';

// States
abstract class BudgetState extends Equatable {
  const BudgetState();
  @override
  List<Object?> get props => [];
}

class BudgetInitial extends BudgetState {}

class BudgetLoading extends BudgetState {}

class BudgetLoaded extends BudgetState {
  final List<BudgetCategory> categories;
  const BudgetLoaded(this.categories);
  @override
  List<Object?> get props => [categories];
}

class BudgetError extends BudgetState {
  final String message;
  const BudgetError(this.message);
  @override
  List<Object?> get props => [message];
}

// Events
abstract class BudgetEvent extends Equatable {
  const BudgetEvent();
  @override
  List<Object?> get props => [];
}

class LoadBudgets extends BudgetEvent {}

class AddBudgetCategory extends BudgetEvent {
  final String name;
  final double limitAmount;
  final int? iconCode;
  final String? colorHex;
  final BudgetCategoryType type;

  const AddBudgetCategory(
    this.name,
    this.limitAmount, {
    this.iconCode,
    this.colorHex,
    this.type = BudgetCategoryType.expense,
  });
  @override
  List<Object?> get props => [name, limitAmount, iconCode, colorHex, type];
}

class UpdateBudgetCategory extends BudgetEvent {
  final String id;
  final String name;
  final double limitAmount;
  final int? iconCode;
  final String? colorHex;
  final BudgetCategoryType? type;

  const UpdateBudgetCategory(
    this.id,
    this.name,
    this.limitAmount, {
    this.iconCode,
    this.colorHex,
    this.type,
  });
  @override
  List<Object?> get props => [id, name, limitAmount, iconCode, colorHex, type];
}

class DeleteBudgetCategory extends BudgetEvent {
  final String id;
  const DeleteBudgetCategory(this.id);
  @override
  List<Object?> get props => [id];
}

class _UpdateBudgets extends BudgetEvent {
  final List<BudgetCategory> categories;
  const _UpdateBudgets(this.categories);
  @override
  List<Object?> get props => [categories];
}

class _HandleBudgetError extends BudgetEvent {
  final String message;
  const _HandleBudgetError(this.message);
  @override
  List<Object?> get props => [message];
}

// Bloc
class BudgetBloc extends Bloc<BudgetEvent, BudgetState> {
  final BudgetRepository repository;
  StreamSubscription<List<BudgetCategory>>? _subscription;

  BudgetBloc({required this.repository}) : super(BudgetInitial()) {
    on<LoadBudgets>((event, emit) async {
      emit(BudgetLoading());
      await _subscription?.cancel();
      _subscription = repository.getBudgetCategoriesStream().listen(
        (categories) {
          add(_UpdateBudgets(categories));
        },
        onError: (e) {
          add(_HandleBudgetError(e.toString()));
        },
      );
    });

    on<_UpdateBudgets>((event, emit) {
      emit(BudgetLoaded(event.categories));
    });

    on<_HandleBudgetError>((event, emit) {
      emit(BudgetError(event.message));
    });

    on<AddBudgetCategory>((event, emit) async {
      try {
        await repository.addBudgetCategory(
          event.name,
          event.limitAmount,
          iconCode: event.iconCode,
          colorHex: event.colorHex,
          type: event.type,
        );
      } catch (e) {
        emit(BudgetError(e.toString()));
      }
    });

    on<UpdateBudgetCategory>((event, emit) async {
      try {
        await repository.updateBudgetCategory(
          event.id,
          event.name,
          event.limitAmount,
          iconCode: event.iconCode,
          colorHex: event.colorHex,
          type: event.type,
        );
      } catch (e) {
        emit(BudgetError(e.toString()));
      }
    });

    on<DeleteBudgetCategory>((event, emit) async {
      try {
        await repository.deleteBudgetCategory(event.id);
      } catch (e) {
        emit(BudgetError(e.toString()));
      }
    });
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
