import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../../core/breakpoints.dart';
import '../../../../core/widgets/master_detail_layout.dart';
import '../../bloc/account_bloc.dart';
import '../../models/account.dart';
import '../widgets/account_detail_view.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  Account? _selectedAccount;

  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(LoadAccounts());
  }

  void _showAccountDialog([Account? account]) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(account == null ? 'Add Account' : 'Edit Account'),
          content: SingleChildScrollView(
            child: AccountForm(
              account: account,
              onSaved: () => Navigator.pop(context),
              onCancel: () => Navigator.pop(context),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: context.isCompact ? AppBar(title: const Text('Accounts')) : null,
      body: BlocListener<AccountBloc, AccountState>(
        listener: (context, state) {
          if (state is AccountLoaded && _selectedAccount != null) {
            setState(() {
              _selectedAccount = state.accounts.firstWhere(
                (a) => a.id == _selectedAccount!.id,
                orElse: () => _selectedAccount!,
              );
            });
          }
        },
        child: MasterDetailLayout(
          master: BlocBuilder<AccountBloc, AccountState>(
            builder: (context, state) {
              if (state is AccountLoading) {
                return const Center(child: CircularProgressIndicator());
              } else if (state is AccountError) {
                return Center(child: Text('Error: ${state.message}'));
              } else if (state is AccountLoaded) {
                if (state.accounts.isEmpty) {
                  return const Center(
                    child: Text('No accounts found. Add one!'),
                  );
                }
                return ListView.builder(
                  itemCount: state.accounts.length,
                  itemBuilder: (context, index) {
                    final account = state.accounts[index];
                    final isSelected = _selectedAccount?.id == account.id;

                    return ListTile(
                      title: Text(
                        account.name,
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text('\$${account.balance.toStringAsFixed(2)}'),
                      selected: !context.isCompact && isSelected,
                      selectedTileColor: Theme.of(
                        context,
                      ).colorScheme.primaryContainer,
                      trailing: context.isCompact
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () {
                                context.read<AccountBloc>().add(
                                  DeleteAccount(account.id),
                                );
                              },
                            )
                          : null,
                      onTap: () {
                        if (context.isCompact) {
                          _showAccountDialog(account);
                        } else {
                          setState(() {
                            _selectedAccount = account;
                          });
                        }
                      },
                    );
                  },
                );
              }
              return const Center(child: Text('Failed to load accounts.'));
            },
          ),
          detail: _selectedAccount != null
              ? AccountDetailView(
                  key: ValueKey(_selectedAccount!.id),
                  account: _selectedAccount!,
                  onDelete: () {
                    setState(() {
                      _selectedAccount = null;
                    });
                  },
                )
              : null,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
