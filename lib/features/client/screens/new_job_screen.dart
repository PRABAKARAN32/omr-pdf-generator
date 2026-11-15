import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/job_session_provider.dart';

class NewJobScreen extends ConsumerStatefulWidget {
  final VoidCallback onBack;
  final VoidCallback onContinue;

  const NewJobScreen({
    super.key,
    required this.onBack,
    required this.onContinue,
  });

  @override
  ConsumerState<NewJobScreen> createState() => _NewJobScreenState();
}

class _NewJobScreenState extends ConsumerState<NewJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clientNameController = TextEditingController();

  DateTime _orderDate = DateTime.now();

  @override
  void dispose() {
    _clientNameController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (selectedDate != null) {
      setState(() {
        _orderDate = selectedDate;
      });
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  void _createJob() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    ref
        .read(jobSessionProvider.notifier)
        .startJob(
          clientName: _clientNameController.text,
          orderDate: _orderDate,
        );

    widget.onContinue();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 500,
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Back to Dashboard',
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'New Job',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),
                const Text('Enter the client details to start a new job.'),

                const SizedBox(height: 28),
                const Text('Client Name'),
                const SizedBox(height: 8),

                TextFormField(
                  controller: _clientNameController,
                  decoration: const InputDecoration(
                    hintText: 'Enter client name',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Client name is required';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 24),
                const Text('Order Placing Date'),
                const SizedBox(height: 8),

                OutlinedButton(
                  onPressed: _selectDate,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.calendar_today),
                      const SizedBox(width: 10),
                      Text(_formatDate(_orderDate)),
                    ],
                  ),
                ),

                const Spacer(),

                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: widget.onBack,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Back'),
                    ),
                    const Spacer(),
                    ElevatedButton.icon(
                      onPressed: _createJob,
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Next: Upload Excel'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
