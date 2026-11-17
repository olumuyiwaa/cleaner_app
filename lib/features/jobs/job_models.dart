import '../../core/json.dart';

enum JobPhase { upcoming, onTheWay, working, done, cancelled }

class ChecklistItem {
  const ChecklistItem({required this.id, required this.label, required this.done});

  final String id;
  final String label;
  final bool done;

  ChecklistItem copyWith({bool? done}) =>
      ChecklistItem(id: id, label: label, done: done ?? this.done);

  factory ChecklistItem.fromJson(Map<String, dynamic> j) => ChecklistItem(
        id: str(j['id']) ?? '',
        label: str(j['label']) ?? '',
        done: boolOf(j['done']),
      );
}

class JobPhoto {
  const JobPhoto({required this.id, required this.stage});

  final String id;

  /// 'BEFORE' or 'AFTER'
  final String stage;

  factory JobPhoto.fromJson(Map<String, dynamic> j) => JobPhoto(
        id: str(j['id']) ?? '',
        stage: str(j['stage']) ?? 'BEFORE',
      );
}

class Assignment {
  const Assignment({
    required this.id,
    required this.isTeamLead,
    this.onMyWayAt,
    this.checkedInAt,
    this.checkedOutAt,
  });

  final String id;
  final bool isTeamLead;
  final DateTime? onMyWayAt;
  final DateTime? checkedInAt;
  final DateTime? checkedOutAt;

  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: str(j['id']) ?? '',
        isTeamLead: boolOf(j['isTeamLead']),
        onMyWayAt: dateOf(j['onMyWayAt']),
        checkedInAt: dateOf(j['checkedInAt']),
        checkedOutAt: dateOf(j['checkedOutAt']),
      );
}

/// A booking assigned to this cleaner, as returned by /cleaner/bookings.
/// The server only exposes what a cleaner needs: first/last name and phone of
/// the customer, never their email or the price.
class Job {
  const Job({
    required this.id,
    required this.status,
    required this.start,
    required this.end,
    required this.serviceName,
    required this.addressLine1,
    required this.city,
    required this.customerFirstName,
    required this.customerLastName,
    this.addressLine2,
    this.postalCode,
    this.latitude,
    this.longitude,
    this.accessCode,
    this.keyLocation,
    this.parkingInstructions,
    this.petNotes,
    this.specialInstructions,
    this.customerPhone,
    this.extras = const [],
    this.assignment,
    this.checklist = const [],
    this.hasChecklist = false,
    this.photos = const [],
  });

  final String id;
  final String status;
  final DateTime start;
  final DateTime end;
  final String serviceName;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String? postalCode;
  final double? latitude;
  final double? longitude;
  final String? accessCode;
  final String? keyLocation;
  final String? parkingInstructions;
  final String? petNotes;
  final String? specialInstructions;
  final String customerFirstName;
  final String customerLastName;
  final String? customerPhone;
  final List<String> extras;
  final Assignment? assignment;
  final List<ChecklistItem> checklist;
  final bool hasChecklist;
  final List<JobPhoto> photos;

  String get customerName => '$customerFirstName $customerLastName'.trim();

  String get address {
    final cityLine = [postalCode, city].whereType<String>().where((s) => s.isNotEmpty).join(' ');
    return [addressLine1, addressLine2, cityLine]
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .join(', ');
  }

  JobPhase get phase {
    if (status == 'CANCELLED') return JobPhase.cancelled;
    if (status == 'COMPLETED' || assignment?.checkedOutAt != null) {
      return JobPhase.done;
    }
    if (assignment?.checkedInAt != null) return JobPhase.working;
    if (assignment?.onMyWayAt != null) return JobPhase.onTheWay;
    return JobPhase.upcoming;
  }

  int get checklistDone => checklist.where((i) => i.done).length;

  int photoCount(String stage) => photos.where((p) => p.stage == stage).length;

  /// Whether any of the access / care notes are filled in.
  bool get hasNotes => [
        accessCode,
        keyLocation,
        parkingInstructions,
        petNotes,
        specialInstructions,
      ].any((s) => s != null && s.isNotEmpty);

  Job copyWithChecklist(List<ChecklistItem> items) => Job(
        id: id,
        status: status,
        start: start,
        end: end,
        serviceName: serviceName,
        addressLine1: addressLine1,
        addressLine2: addressLine2,
        city: city,
        postalCode: postalCode,
        latitude: latitude,
        longitude: longitude,
        accessCode: accessCode,
        keyLocation: keyLocation,
        parkingInstructions: parkingInstructions,
        petNotes: petNotes,
        specialInstructions: specialInstructions,
        customerFirstName: customerFirstName,
        customerLastName: customerLastName,
        customerPhone: customerPhone,
        extras: extras,
        assignment: assignment,
        checklist: items,
        hasChecklist: hasChecklist,
        photos: photos,
      );

  factory Job.fromJson(Map<String, dynamic> j) {
    final customer = mapOf(j['customer']);
    final service = mapOf(j['service']);
    final assignments = mapsOf(j['assignments']);
    final checklistJson = j['checklist'];
    final checklistMap = mapOf(checklistJson);

    return Job(
      id: str(j['id']) ?? '',
      status: str(j['status']) ?? 'ASSIGNED',
      start: dateOf(j['scheduledStart']) ?? DateTime.now(),
      end: dateOf(j['scheduledEnd']) ?? DateTime.now(),
      serviceName: str(service['name']) ?? '',
      addressLine1: str(j['addressLine1']) ?? '',
      addressLine2: str(j['addressLine2']),
      city: str(j['city']) ?? '',
      postalCode: str(j['postalCode']),
      latitude: doubleOf(j['latitude']),
      longitude: doubleOf(j['longitude']),
      accessCode: str(j['accessCode']),
      keyLocation: str(j['keyLocation']),
      parkingInstructions: str(j['parkingInstructions']),
      petNotes: str(j['petNotes']),
      specialInstructions: str(j['specialInstructions']),
      customerFirstName: str(customer['firstName']) ?? '',
      customerLastName: str(customer['lastName']) ?? '',
      customerPhone: str(customer['phone']),
      extras: _extraNames(j['addOns']),
      assignment: assignments.isEmpty ? null : Assignment.fromJson(assignments.first),
      hasChecklist: checklistJson != null,
      checklist: mapsOf(checklistMap['items']).map(ChecklistItem.fromJson).toList(),
      photos: mapsOf(j['photos']).map(JobPhoto.fromJson).toList(),
    );
  }

  static List<String> _extraNames(dynamic addOns) {
    if (addOns is! List) return const [];
    final names = <String>[];
    for (final a in addOns) {
      if (a is String && a.isNotEmpty) {
        names.add(a);
      } else if (a is Map && a['name'] != null) {
        names.add(a['name'].toString());
      }
    }
    return names;
  }
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.mine,
    required this.role,
    required this.body,
    required this.createdAt,
    this.name,
  });

  final String id;
  final bool mine;
  final String role;
  final String body;
  final String createdAt;
  final String? name;

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
        id: str(j['id']) ?? '',
        mine: boolOf(j['mine']),
        role: str(j['role']) ?? 'CUSTOMER',
        body: str(j['body']) ?? '',
        createdAt: str(j['createdAt']) ?? '',
        name: str(j['name']),
      );
}

class ChatThread {
  const ChatThread({required this.open, required this.messages, this.withName});

  final bool open;
  final String? withName;
  final List<ChatMessage> messages;

  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        // A missing flag means the chat is available; only an explicit false closes it.
        open: j['open'] != false,
        withName: str(j['with']),
        messages: mapsOf(j['messages']).map(ChatMessage.fromJson).toList(),
      );
}
