import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/supabase_service.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _formKey = GlobalKey<FormState>();
  final _feedbackController = TextEditingController();
  String _selectedCategory = AppConstants.feedbackCategories.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSubmitting = true);

    try {
      final currentUser = SupabaseService.currentUser;
      final userEmail = currentUser?.email ?? 'anonymous';
      final userId = currentUser?.id;
      final feedback = _feedbackController.text.trim();

      // Primary method: Store feedback in the database
      bool savedToDatabase = false;
      try {
        await SupabaseService.instance.from('app_feedback').insert({
          'user_id': userId,
          'user_email': userEmail,
          'category': _selectedCategory,
          'feedback': feedback,
          'app_version': '1.0.0',
          'status': 'pending',
        });
        savedToDatabase = true;
      } catch (e) {
        // Database insert failed, will try edge function
      }

      // Secondary method: Try to send notification via edge function
      if (savedToDatabase) {
        final session = SupabaseService.instance.auth.currentSession;
        if (session != null && session.accessToken.isNotEmpty) {
          try {
            await SupabaseService.instance.functions.invoke(
              'send-feedback',
              body: {
                'category': _selectedCategory,
                'feedback': feedback,
                'userEmail': userEmail,
                'appName': AppConstants.appName,
                'developerEmail': AppConstants.developerEmail,
              },
              headers: {
                'Authorization': 'Bearer ${session.accessToken}',
              },
            );
          } catch (e) {
            // Edge function failed, but feedback is saved - that's okay
          }
        }
      }

      // Fallback: Open email client if database insert failed
      if (!savedToDatabase) {
        final subject = Uri.encodeComponent(
          '[$_selectedCategory] ${AppConstants.appName} Feedback',
        );
        final body = Uri.encodeComponent(
          'Category: $_selectedCategory\n'
          'From: $userEmail\n\n'
          '$feedback',
        );
        final mailtoUrl = Uri.parse(
          'mailto:${AppConstants.developerEmail}?subject=$subject&body=$body',
        );

        final launched = await launchUrl(
          mailtoUrl,
          mode: LaunchMode.externalApplication,
        );

        if (!launched) {
          // If mailto also fails, show the email address for manual copying
          if (!mounted) return;
          _showManualEmailDialog(feedback);
          return;
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Thank you for your feedback!')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send feedback: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showManualEmailDialog(String feedback) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Send Feedback Manually'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Please send your feedback to:'),
            const SizedBox(height: 8),
            SelectableText(
              AppConstants.developerEmail,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Your feedback has been copied below:'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(4),
              ),
              child: SelectableText(
                'Category: $_selectedCategory\n\n$feedback',
                style: const TextStyle(fontSize: 12),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Send Feedback',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                'Help us improve ${AppConstants.appName}! Your feedback will be sent to ${AppConstants.companyName}.',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 24),

              // Category Dropdown
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: const InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.category_outlined),
                ),
                items: AppConstants.feedbackCategories.map((category) {
                  IconData icon;
                  switch (category) {
                    case 'Feature Request':
                      icon = Icons.lightbulb_outline;
                      break;
                    case 'Bug Report':
                      icon = Icons.bug_report_outlined;
                      break;
                    default:
                      icon = Icons.chat_bubble_outline;
                  }
                  return DropdownMenuItem(
                    value: category,
                    child: Row(
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Text(category),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _selectedCategory = value);
                  }
                },
              ),
              const SizedBox(height: 16),

              // Feedback Text Field
              TextFormField(
                controller: _feedbackController,
                minLines: 4,
                maxLines: 8,
                decoration: InputDecoration(
                  labelText: _selectedCategory == 'Bug Report'
                      ? 'Describe the issue you encountered'
                      : _selectedCategory == 'Feature Request'
                          ? 'Describe the feature you would like'
                          : 'Describe your feedback or suggestion',
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
                validator: (value) => (value == null || value.trim().isEmpty)
                    ? 'Please enter your feedback'
                    : null,
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isSubmitting ? null : _submitFeedback,
                  icon: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                  label: const Text('Send Feedback'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Contact info
              Center(
                child: Text(
                  'Or email us directly at ${AppConstants.developerEmail}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
