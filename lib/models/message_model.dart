// تعريف كلاس Message لتمثيل الرسائل
class Message {
  final int? id; // معرف الرسالة (اختياري)
  final String sender; // المرسل (مثل رقم الهاتف أو معرف آخر)
  String content; // محتوى الرسالة
  final DateTime timestamp; // وقت إرسال الرسالة
  final bool isMe; // هل الرسالة مرسلة من المستخدم نفسه؟
  final bool isEncrypted; // هل الرسالة مشفرة؟

  // المُنشئ لإنشاء كائن Message
  Message({
    this.id, // معرف الرسالة (اختياري)
    required this.sender, // المرسل
    required this.content, // محتوى الرسالة
    required this.timestamp, // وقت الإرسال
    required this.isMe, // هل الرسالة مرسلة من المستخدم؟
    this.isEncrypted = false, // هل الرسالة مشفرة؟ (القيمة الافتراضية: غير مشفرة)
  });

  // دالة لتحويل كائن الرسالة إلى خريطة (Map) لتسهيل تخزينه في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id, // معرف الرسالة
      'sender': sender, // المرسل
      'content': content, // محتوى الرسالة
      'timestamp': timestamp.toIso8601String(), // تحويل وقت الإرسال إلى نص بتنسيق ISO8601
      'isMe': isMe ? 1 : 0, // تحويل القيمة المنطقية إلى عدد (1 إذا كان true، و0 إذا كان false)
      'isEncrypted': isEncrypted ? 1 : 0, // تحويل القيمة المنطقية إلى عدد
    };
  }

  // دالة لإنشاء كائن Message من خريطة (Map) (مثل البيانات المسترجعة من قاعدة البيانات)
  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'], // تعيين معرف الرسالة
      sender: map['sender'], // تعيين المرسل
      content: map['content'], // تعيين محتوى الرسالة
      timestamp: DateTime.parse(map['timestamp']), // تحويل النص إلى كائن DateTime
      isMe: map['isMe'] == 1, // تحويل العدد إلى قيمة منطقية (true إذا كان 1)
      isEncrypted: map['isEncrypted'] == 1, // تحويل العدد إلى قيمة منطقية (true إذا كان 1)
    );
  }
}