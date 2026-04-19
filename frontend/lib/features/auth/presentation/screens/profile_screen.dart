import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/breakpoints.dart';
import '../../repositories/profile_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final ProfileRepository _profileRepository = ProfileRepository(
    supabase: Supabase.instance.client,
  );
  double _savingsRatio = 0.5;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final ratio = await _profileRepository.getDefaultSavingsRatio();
      setState(() {
        _savingsRatio = ratio;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading profile: $e')));
    }
  }

  Future<void> _saveRatio(double val) async {
    try {
      await _profileRepository.updateDefaultSavingsRatio(val);
      if (!mounted) return;
      setState(() => _savingsRatio = val);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings saved')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error saving: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar:
          context.isCompact
              ? AppBar(title: const Text('Profile Settings'))
              : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'AI Recommendation Balance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When you have no recent history, the AI will use this ratio to balance between savings and purchase goals.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Purchase Goals'),
                      const Text('Savings Goals'),
                    ],
                  ),
                  Slider(
                    value: _savingsRatio,
                    onChanged: (val) => setState(() => _savingsRatio = val),
                    onChangeEnd: _saveRatio,
                    divisions: 10,
                    label: '${(_savingsRatio * 100).toInt()}% Savings',
                  ),
                  Center(
                    child: Text(
                      '${((1 - _savingsRatio) * 100).toInt()}% Purchases / ${(_savingsRatio * 100).toInt()}% Savings',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Supabase.instance.client.auth.signOut(),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Logout'),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }
}
