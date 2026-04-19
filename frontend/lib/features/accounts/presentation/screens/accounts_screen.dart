import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../bloc/account_bloc.dart';
import '../../models/account.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<AccountBloc>().add(LoadAccounts());
  }

  void _showAccountDialog([Account? account]) {
    final nameController = TextEditingController(text: account?.name);
    final balanceController = TextEditingController(
      text: account?.balance.toString(),
    );

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(account == null ? 'Add Account' : 'Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Account Name'),
              ),
              TextField(
                controller: balanceController,
                decoration: const InputDecoration(labelText: 'Balance'),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final balance =
                    double.tryParse(balanceController.text.trim()) ?? 0.0;

                if (name.isNotEmpty) {
                  if (account == null) {
                    context.read<AccountBloc>().add(AddAccount(name, balance));
                  } else {
                    context.read<AccountBloc>().add(
                      UpdateAccount(account.id, name, balance),
                    );
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: BlocBuilder<AccountBloc, AccountState>(
        builder: (context, state) {
          if (state is AccountLoading) {
            return const Center(child: CircularProgressIndicator());
          } else if (state is AccountError) {
            return Center(child: Text('Error: ${state.message}'));
          } else if (state is AccountLoaded) {
            if (state.accounts.isEmpty) {
              return const Center(child: Text('No accounts found. Add one!'));
            }
            return ListView.builder(
              itemCount: state.accounts.length,
              itemBuilder: (context, index) {
                final account = state.accounts[index];
                return ListTile(
                  title: Text(account.name),
                  subtitle: Text('\$${account.balance.toStringAsFixed(2)}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      context.read<AccountBloc>().add(
                        DeleteAccount(account.id),
                      );
                    },
                  ),
                  onTap: () => _showAccountDialog(account),
                );
              },
            );
          }
          return const Center(child: Text('Failed to load accounts.'));
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAccountDialog(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
