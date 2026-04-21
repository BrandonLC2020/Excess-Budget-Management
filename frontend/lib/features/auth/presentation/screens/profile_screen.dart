import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/breakpoints.dart';
import '../../models/profile.dart';
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
  final _nameController = TextEditingController();
  UserProfile? _profile;
  bool _isLoading = true;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _profileRepository.getProfile();
      setState(() {
        _profile = profile;
        _nameController.text = profile.fullName ?? '';
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

  Future<void> _updateProfile() async {
    if (_profile == null) return;
    try {
      final updatedProfile = _profile!.copyWith(
        fullName: _nameController.text.trim(),
      );
      await _profileRepository.updateProfile(updatedProfile);
      setState(() => _profile = updatedProfile);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error updating profile: $e')));
    }
  }

  Future<void> _pickAndUploadImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );

    if (image == null) return;

    setState(() => _isUploading = true);

    try {
      final avatarUrl = await _profileRepository.uploadAvatar(image);
      final updatedProfile = _profile!.copyWith(avatarUrl: avatarUrl);
      await _profileRepository.updateProfile(updatedProfile);
      setState(() {
        _profile = updatedProfile;
        _isUploading = false;
      });
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Avatar updated')));
    } catch (e) {
      setState(() => _isUploading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error uploading avatar: $e')));
    }
  }

  Future<void> _saveRatio(double val) async {
    if (_profile == null) return;
    try {
      final updatedProfile = _profile!.copyWith(defaultSavingsRatio: val);
      await _profileRepository.updateDefaultSavingsRatio(val);
      setState(() => _profile = updatedProfile);
      if (!mounted) return;
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
      appBar: context.isCompact
          ? AppBar(title: const Text('Profile Settings'))
          : null,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundImage: _profile?.avatarUrl != null
                              ? NetworkImage(_profile!.avatarUrl!)
                              : null,
                          child: _profile?.avatarUrl == null
                              ? const Icon(Icons.person, size: 60)
                              : null,
                        ),
                        if (_isUploading)
                          const Positioned.fill(
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: CircleAvatar(
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary,
                            radius: 18,
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: _isUploading
                                  ? null
                                  : _pickAndUploadImage,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.badge),
                    ),
                    onFieldSubmitted: (_) => _updateProfile(),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    initialValue: _profile?.email,
                    readOnly: true,
                    decoration: const InputDecoration(
                      labelText: 'Email Address',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.email),
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 32),
                  const Divider(),
                  const SizedBox(height: 32),
                  const Text(
                    'AI Recommendation Balance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'When you have no recent history, the AI will use this ratio to balance between savings and purchase goals.',
                    style: TextStyle(color: Colors.grey),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      Text('Purchase Goals'),
                      Text('Savings Goals'),
                    ],
                  ),
                  Slider(
                    value: _profile?.defaultSavingsRatio ?? 0.5,
                    onChanged: (val) => setState(() {
                      _profile = _profile?.copyWith(defaultSavingsRatio: val);
                    }),
                    onChangeEnd: _saveRatio,
                    divisions: 10,
                    label:
                        '${((_profile?.defaultSavingsRatio ?? 0.5) * 100).toInt()}% Savings',
                  ),
                  Center(
                    child: Text(
                      '${((1 - (_profile?.defaultSavingsRatio ?? 0.5)) * 100).toInt()}% Purchases / ${((_profile?.defaultSavingsRatio ?? 0.5) * 100).toInt()}% Savings',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(height: 48),
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
