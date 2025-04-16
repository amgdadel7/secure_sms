// تعريف كلاس KeyInfo لتمثيل معلومات المفتاح المشترك
class KeyInfo {
  final String senderUUID; // UUID الخاص بالمرسل
  final String senderNUM; // رقم هاتف المرسل
  final String receiverUUID; // UUID الخاص بالمستقبل
  final String receiverNUM; // رقم هاتف المستقبل
  final String sharedSecret; // المفتاح المشترك الناتج عن التشفير
  final DateTime createdAt; // تاريخ إنشاء المفتاح

  // المُنشئ لإنشاء كائن KeyInfo
  KeyInfo({
    required this.senderUUID, // UUID الخاص بالمرسل
    required this.senderNUM, // رقم هاتف المرسل
    required this.receiverUUID, // UUID الخاص بالمستقبل
    required this.receiverNUM, // رقم هاتف المستقبل
    required this.sharedSecret, // المفتاح المشترك
    required this.createdAt, // تاريخ الإنشاء
  });

  // دالة لإنشاء كائن KeyInfo من كائن JSON (مثل البيانات المسترجعة من API)
  factory KeyInfo.fromJson(Map<String, dynamic> json) {
    return KeyInfo(
      senderUUID: json['senderUUID'], // تعيين UUID الخاص بالمرسل
      senderNUM: json['senderNUM'], // تعيين رقم هاتف المرسل
      receiverUUID: json['receiverUUID'], // تعيين UUID الخاص بالمستقبل
      receiverNUM: json['receiverNUM'], // تعيين رقم هاتف المستقبل
      sharedSecret: json['sharedSecret'], // تعيين المفتاح المشترك
      createdAt: DateTime.parse(json['created_at']), // تحويل تاريخ الإنشاء من نص إلى كائن DateTime
    );
  }
}