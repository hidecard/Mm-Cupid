import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedGender;
  String? _selectedInterestedIn;
  DateTime? _selectedBirthday;
  final _bioController = TextEditingController();

  @override
  void dispose() {
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final now = DateTime.now();
    final initialDate = _selectedBirthday ?? DateTime(now.year - 20);
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1900),
      lastDate: now,
    );
    if (picked != null) {
      setState(() {
        _selectedBirthday = picked;
      });
    }
  }

  Future<void> _completeOnboarding() async {
    if (_selectedGender == null ||
        _selectedInterestedIn == null ||
        _selectedBirthday == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fill in all required fields'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final success = await auth.completeOnboarding(
      gender: _selectedGender!,
      interestedIn: _selectedInterestedIn!,
      birthday: _selectedBirthday!.toIso8601String().split('T').first,
      bio: _bioController.text.trim().isNotEmpty ? _bioController.text.trim() : null,
    );

    if (!mounted) return;

    if (!success && auth.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.error!), backgroundColor: Colors.red),
      );
    }
    // AuthGate will automatically rebuild and show MainScreen when onboarding is complete
  }

  Widget _buildGenderOption(String value, IconData icon) {
    final selected = _selectedGender == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedGender = value;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: selected
                ? const Color(0xFFE94560).withValues(alpha: 0.1)
                : Colors.grey[100],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: selected ? const Color(0xFFE94560) : Colors.grey[300]!,
              width: selected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon,
                  size: 32,
                  color: selected ? const Color(0xFFE94560) : Colors.grey[600]),
              const SizedBox(height: 8),
              Text(
                value.toUpperCase(),
                style: TextStyle(
                  color: selected ? const Color(0xFFE94560) : Colors.grey[700],
                  fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 24),
              const Text(
                'Tell us about yourself',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This helps us find the right matches for you',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'Gender',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildGenderOption('male', Icons.male),
                  const SizedBox(width: 12),
                  _buildGenderOption('female', Icons.female),
                  const SizedBox(width: 12),
                  _buildGenderOption('other', Icons.wc),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Interested In',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _InterestOption(
                      label: 'Male',
                      value: 'male',
                      selected: _selectedInterestedIn == 'male',
                      onSelect: (v) => setState(() => _selectedInterestedIn = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InterestOption(
                      label: 'Female',
                      value: 'female',
                      selected: _selectedInterestedIn == 'female',
                      onSelect: (v) => setState(() => _selectedInterestedIn = v),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _InterestOption(
                      label: 'Both',
                      value: 'both',
                      selected: _selectedInterestedIn == 'both',
                      onSelect: (v) => setState(() => _selectedInterestedIn = v),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              const Text(
                'Birthday',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: _selectDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _selectedBirthday != null
                            ? _selectedBirthday!
                                .toIso8601String()
                                .split('T')
                                .first
                            : 'Select your birthday',
                        style: TextStyle(
                          color: _selectedBirthday != null
                              ? Colors.black
                              : Colors.grey[600],
                        ),
                      ),
                      const Icon(Icons.calendar_today_outlined, size: 20),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Bio (Optional)',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _bioController,
                maxLines: 3,
                maxLength: 200,
                decoration: InputDecoration(
                  hintText: 'Tell something about yourself...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.isLoading ? null : _completeOnboarding,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  backgroundColor: const Color(0xFFE94560),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: auth.isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Complete Profile',
                        style: TextStyle(fontSize: 16),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InterestOption extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onSelect;

  const _InterestOption({
    required this.label,
    required this.value,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onSelect(value),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: selected
              ? const Color(0xFFE94560).withValues(alpha: 0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? const Color(0xFFE94560) : Colors.grey[300]!,
            width: selected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? const Color(0xFFE94560) : Colors.grey[700],
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}
