class Email {
  final String id;
  final String messageId;
  final String threadId;
  final String accountName;
  final String accountType;
  final String subject;
  final String from;
  final String to;
  final DateTime date;
  final String text;
  final String html;
  bool isRead;
  final String snippet;

  Email({
    required this.id,
    required this.messageId,
    required this.threadId,
    required this.accountName,
    required this.accountType,
    required this.subject,
    required this.from,
    required this.to,
    required this.date,
    required this.text,
    required this.html,
    required this.isRead,
    required this.snippet,
  });

  factory Email.fromJson(Map<String, dynamic> json) {
    return Email(
      id: json['id'] ?? '',
      messageId: json['messageId'] ?? '',
      threadId: json['threadId'] ?? '',
      accountName: json['accountName'] ?? '',
      accountType: json['accountType'] ?? '',
      subject: json['subject'] ?? '(No Subject)',
      from: json['from'] ?? 'Unknown',
      to: json['to'] ?? '',
      date: DateTime.tryParse(json['date'] ?? '') ?? DateTime.now(),
      text: json['text'] ?? '',
      html: json['html'] ?? '',
      isRead: json['isRead'] ?? false,
      snippet: json['snippet'] ?? '',
    );
  }
}
