import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../auth/app_user.dart';
import '../../auth/firebase_auth_controller.dart';
import '../onboarding/nitj_email.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key, required this.controller});

  final FirebaseAuthController controller;

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final _pageController = PageController();

  final _accountFormKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _bioController = TextEditingController();
  final _customInterestController = TextEditingController();

  Gender _gender = Gender.preferNotToSay;

  final Set<String> _selectedInterests = {
    'Music',
  };

  Uint8List? _profileImage;

  bool _submitting = false;
  String? _error;

  static const _suggestedInterests = <String>[
    'Music',
    'Gym',
    'Anime',
    'Movies',
    'Cricket',
    'Badminton',
    'Coding',
    'Photography',
    'Travel',
    'Food',
    'Books',
    'Gaming',
  ];

  @override
  void initState() {
    super.initState();
    _bioController.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _bioController.dispose();
    _customInterestController.dispose();
    super.dispose();
  }

  int _wordCount(String text) {
    final words = text
        .trim()
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty)
        .toList();
    return words.length;
  }

  Future<void> _nextFromAccount() async {
    if (!_accountFormKey.currentState!.validate()) return;
    await _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _nextFromProfile() async {
    if (!_profileFormKey.currentState!.validate()) return;

    // Ask for profile picture (recommended) but don't hard-block signup yet.
    // We can make this mandatory later when backend storage is wired.
    if (_profileImage == null) {
      setState(() {
        _error = 'Add a profile photo (recommended). You can also continue without it for now.';
      });
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  void _toggleInterest(String interest) {
    setState(() {
      _error = null;
      if (_selectedInterests.contains(interest)) {
        _selectedInterests.remove(interest);
      } else {
        _selectedInterests.add(interest);
      }
    });
  }

  void _addCustomInterest() {
    final raw = _customInterestController.text.trim();
    if (raw.isEmpty) return;

    final normalized = raw[0].toUpperCase() + raw.substring(1);

    setState(() {
      _selectedInterests.add(normalized);
      _customInterestController.clear();
    });
  }

  Future<void> _pickProfileImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
      allowMultiple: false,
    );

    final bytes = result?.files.single.bytes;
    if (bytes == null) return;

    setState(() {
      _profileImage = bytes;
    });
  }

  Future<void> _submit() async {
    if (_selectedInterests.isEmpty) {
      setState(() {
        _error = 'Please choose at least one interest.';
      });
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 250));

    final err = await widget.controller.signUp(
      email: _emailController.text,
      username: _usernameController.text,
      password: _passwordController.text,
      gender: _gender,
      bio: _bioController.text,
      interests: _selectedInterests.toList()..sort(),
      profileImageBytes: _profileImage?.toList(),
    );

    setState(() {
      _submitting = false;
      _error = err;
    });

    if (err == null && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sign up'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: theme.colorScheme.outlineVariant),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          _error!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.error,
                          ),
                        ),
                      ),
                    Expanded(
                      child: PageView(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        children: [
                          _AccountStep(
                            formKey: _accountFormKey,
                            emailController: _emailController,
                            usernameController: _usernameController,
                            passwordController: _passwordController,
                            onNext: _nextFromAccount,
                          ),
                          _ProfileStep(
                            formKey: _profileFormKey,
                            gender: _gender,
                            onGenderChanged: (g) => setState(() => _gender = g),
                            bioController: _bioController,
                            wordCount: _wordCount(_bioController.text),
                            onNext: _nextFromProfile,
                            onPickImage: _pickProfileImage,
                            profileImage: _profileImage,
                          ),
                          _InterestsStep(
                            selected: _selectedInterests,
                            suggested: _suggestedInterests,
                            onToggle: _toggleInterest,
                            customController: _customInterestController,
                            onAddCustom: _addCustomInterest,
                            onSubmit: _submitting ? null : _submit,
                            submitting: _submitting,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountStep extends StatelessWidget {
  const _AccountStep({
    required this.formKey,
    required this.emailController,
    required this.usernameController,
    required this.passwordController,
    required this.onNext,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: ListView(
        children: [
          const Text(
            'Create your account',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: emailController,
            decoration: const InputDecoration(
              labelText: 'College email',
              hintText: 'name.branch.year@nitj.ac.in',
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Enter email';
              if (!isValidNitjEmail(value)) {
                return 'Use: name.branch.year@nitj.ac.in';
              }
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: usernameController,
            decoration: const InputDecoration(
              labelText: 'Username',
            ),
            validator: (v) {
              final value = (v ?? '').trim();
              if (value.isEmpty) return 'Enter username';
              if (value.length < 3) return 'Username too short';
              return null;
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(
              labelText: 'Password',
            ),
            validator: (v) {
              final value = v ?? '';
              if (value.isEmpty) return 'Enter password';
              if (value.length < 6) return 'Min 6 characters';
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
        ],
      ),
    );
  }
}

class _ProfileStep extends StatelessWidget {
  const _ProfileStep({
    required this.formKey,
    required this.gender,
    required this.onGenderChanged,
    required this.bioController,
    required this.wordCount,
    required this.onNext,
    required this.onPickImage,
    required this.profileImage,
  });

  final GlobalKey<FormState> formKey;
  final Gender gender;
  final ValueChanged<Gender> onGenderChanged;
  final TextEditingController bioController;
  final int wordCount;
  final VoidCallback onNext;
  final VoidCallback onPickImage;
  final Uint8List? profileImage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: ListView(
        children: [
          const Text(
            'Set up your profile',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Center(
            child: Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 44,
                  backgroundImage: profileImage == null ? null : MemoryImage(profileImage!),
                  child: profileImage == null ? const Icon(Icons.person, size: 44) : null,
                ),
                IconButton.filledTonal(
                  tooltip: 'Add photo',
                  onPressed: onPickImage,
                  icon: const Icon(Icons.camera_alt),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<Gender>(
            value: gender,
            items: [
              for (final g in Gender.values)
                DropdownMenuItem(value: g, child: Text(g.label)),
            ],
            onChanged: (v) {
              if (v != null) onGenderChanged(v);
            },
            decoration: const InputDecoration(labelText: 'Gender'),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: bioController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: 'Bio',
              helperText: 'Up to 50 words ($wordCount/50)',
            ),
            validator: (v) {
              final text = v ?? '';
              final words = text.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;
              if (words == 0) return 'Add a short bio';
              if (words > 50) return 'Bio must be 50 words or less';
              return null;
            },
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: onNext,
            child: const Text('Next'),
          ),
          const SizedBox(height: 8),
          Text(
            'Tip: keep it short and respectful.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _InterestsStep extends StatelessWidget {
  const _InterestsStep({
    required this.selected,
    required this.suggested,
    required this.onToggle,
    required this.customController,
    required this.onAddCustom,
    required this.onSubmit,
    required this.submitting,
  });

  final Set<String> selected;
  final List<String> suggested;
  final ValueChanged<String> onToggle;
  final TextEditingController customController;
  final VoidCallback onAddCustom;
  final VoidCallback? onSubmit;
  final bool submitting;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const Text(
          'Choose your interests',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final interest in suggested)
              FilterChip(
                label: Text(interest),
                selected: selected.contains(interest),
                onSelected: (_) => onToggle(interest),
              ),
            for (final interest in selected.where((i) => !suggested.contains(i)))
              FilterChip(
                label: Text(interest),
                selected: true,
                onSelected: (_) => onToggle(interest),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: customController,
                decoration: const InputDecoration(
                  labelText: 'Add custom interest',
                ),
                onSubmitted: (_) => onAddCustom(),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: onAddCustom,
              child: const Text('Add'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: selected.isEmpty ? null : onSubmit,
          child: Text(submitting ? 'Creating…' : 'Create account'),
        ),
      ],
    );
  }
}
