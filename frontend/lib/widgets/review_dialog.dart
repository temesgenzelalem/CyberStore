import 'package:flutter/material.dart';
import 'package:frontend/services/api_service.dart';
import 'package:frontend/l10n/app_localization.dart';

class ReviewDialog extends StatefulWidget {
  final int productId;
  const ReviewDialog({super.key, required this.productId});

  @override
  State<ReviewDialog> createState() => _ReviewDialogState();
}

class _ReviewDialogState extends State<ReviewDialog> {
  int _rating = 5;
  final _commentController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isLoading = false;

  void _submitReview() async {
    setState(() => _isLoading = true);
    final response = await _apiService.post('/products/${widget.productId}/reviews', {
      'rating': _rating,
      'comment': _commentController.text,
    });

    if (response.statusCode == 201) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Review submitted!')));
      }
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalization.of(context);
    return AlertDialog(
      title: Text(l10n?.translate('write_review') ?? 'Write a Review'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Select Rating:'),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return IconButton(
                icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: Colors.amber),
                onPressed: () => setState(() => _rating = index + 1),
              );
            }),
          ),
          TextField(
            controller: _commentController,
            decoration: const InputDecoration(labelText: 'Comment (Optional)'),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n?.translate('cancel') ?? 'Cancel')),
        ElevatedButton(
          onPressed: _isLoading ? null : _submitReview,
          child: _isLoading ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(l10n?.translate('save') ?? 'Submit'),
        ),
      ],
    );
  }
}
