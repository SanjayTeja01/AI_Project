import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

class SosScreen extends StatefulWidget {
  final bool isActivation;

  const SosScreen({super.key, this.isActivation = false});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class SosEvent {
  final String id;
  final DateTime triggeredAt;
  final DateTime? stoppedAt;
  final GeoPoint location;
  final String locationLink;
  final String status;

  SosEvent({
    required this.id,
    required this.triggeredAt,
    this.stoppedAt,
    required this.location,
    required this.locationLink,
    required this.status,
  });

  factory SosEvent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SosEvent(
      id: doc.id,
      triggeredAt: (data['triggeredAt'] as Timestamp).toDate(),
      stoppedAt: data['cancelledAt'] != null
          ? (data['cancelledAt'] as Timestamp).toDate()
          : null,
      location: data['location'] as GeoPoint,
      locationLink: data['locationLink'] ?? '',
      status: data['status'] ?? 'active',
    );
  }
}

class _SosScreenState extends State<SosScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteSosEvent(String eventId, bool isActive) async {
    if (isActive) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cannot delete an active SOS event. Please stop it first.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete SOS Event'),
        content: const Text('Are you sure you want to delete this SOS event?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _firestore.collection('sos_events').doc(eventId).delete();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('SOS event deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to delete SOS event')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Please log in')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS History'),
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('sos_events')
            .where('userId', isEqualTo: user.uid)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.red));
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          final events = (snapshot.data?.docs ?? [])
              .map((doc) => SosEvent.fromFirestore(doc))
              .toList()
            ..sort((a, b) => b.triggeredAt.compareTo(a.triggeredAt));

          if (events.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.history,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No SOS history',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: events.length,
            itemBuilder: (context, index) {
              final event = events[index];
              final isActive = event.status == 'active';
              
              // Format date manually
              String formatDate(DateTime date) {
                const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
                  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
                return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
              }
              
              String formatTime(DateTime date) {
                final hour = date.hour > 12 ? date.hour - 12 : (date.hour == 0 ? 12 : date.hour);
                final minute = date.minute.toString().padLeft(2, '0');
                final period = date.hour >= 12 ? 'PM' : 'AM';
                return '$hour:$minute $period';
              }

              String eventHeading;
              Color headingColor;
              IconData headingIcon;
              
              if (isActive) {
                eventHeading = 'SOS Active';
                headingColor = Colors.red[700]!;
                headingIcon = Icons.warning;
              } else if (event.stoppedAt != null) {
                eventHeading = 'SOS Alert Ended';
                headingColor = Colors.green;
                headingIcon = Icons.check_circle;
              } else {
                eventHeading = 'SOS Event';
                headingColor = Colors.black87;
                headingIcon = Icons.info;
              }

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                elevation: 1,
                color: isActive ? Colors.red[50] : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Icon(
                                headingIcon,
                                size: 20,
                                color: headingColor,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                eventHeading,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: headingColor,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline, color: Colors.red, size: 22),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () => _deleteSosEvent(event.id, isActive),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Icon(Icons.access_time, size: 16, color: Colors.grey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Triggered: ${formatDate(event.triggeredAt)} at ${formatTime(event.triggeredAt)}',
                              style: const TextStyle(fontSize: 14, color: Colors.grey),
                            ),
                          ),
                        ],
                      ),
                      if (event.stoppedAt != null) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.check_circle, size: 16, color: Colors.green),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Ended: ${formatDate(event.stoppedAt!)} at ${formatTime(event.stoppedAt!)}',
                                style: const TextStyle(fontSize: 14, color: Colors.green),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          final url = Uri.parse(event.locationLink);
                          if (await canLaunchUrl(url)) {
                            await launchUrl(url, mode: LaunchMode.externalApplication);
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          alignment: Alignment.centerLeft,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, size: 18, color: Colors.blue),
                            const SizedBox(width: 6),
                            const Text(
                              'View Location',
                              style: TextStyle(color: Colors.blue, fontSize: 14),
                            ),
                            const SizedBox(width: 4),
                            const Icon(Icons.open_in_new, size: 16, color: Colors.blue),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

