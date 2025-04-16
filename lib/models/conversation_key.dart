// تعريف كلاس ConversationKey لتمثيل مفاتيح المحادثة
class ConversationKey {
  final int? id; // معرف المفتاح (اختياري)
  final String address; // عنوان المحادثة (مثل رقم الهاتف أو معرف آخر)
  final String ownPrivateKey; // المفتاح الخاص بالمستخدم
  final String ownPublicKey; // المفتاح العام للمستخدم
  final String? theirPublicKey; // المفتاح العام للطرف الآخر (اختياري)
  final String? sharedSecret; // المفتاح المشترك الناتج عن التشفير (اختياري)

  // المُنشئ لإنشاء كائن ConversationKey
  ConversationKey({
    this.id, // معرف المفتاح (اختياري)
    required this.address, // عنوان المحادثة
    required this.ownPrivateKey, // المفتاح الخاص بالمستخدم
    required this.ownPublicKey, // المفتاح العام للمستخدم
    this.theirPublicKey, // المفتاح العام للطرف الآخر (اختياري)
    this.sharedSecret, // المفتاح المشترك (اختياري)
  });

  // دالة لتحويل الكائن إلى خريطة (Map) لتسهيل تخزينه في قاعدة البيانات
  Map<String, dynamic> toMap() {
    return {
      'id': id, // معرف المفتاح
      'address': address, // عنوان المحادثة
      'own_private_key': ownPrivateKey, // المفتاح الخاص بالمستخدم
      'own_public_key': ownPublicKey, // المفتاح العام للمستخدم
      'their_public_key': theirPublicKey, // المفتاح العام للطرف الآخر
      'shared_secret': sharedSecret, // المفتاح المشترك
    };
  }

  // دالة لإنشاء كائن ConversationKey من خريطة (Map) (مثل البيانات المسترجعة من قاعدة البيانات)
  factory ConversationKey.fromMap(Map<String, dynamic> map) {
    return ConversationKey(
      id: map['id'], // تعيين معرف المفتاح
      address: map['address'], // تعيين عنوان المحادثة
      ownPrivateKey: map['own_private_key'], // تعيين المفتاح الخاص
      ownPublicKey: map['own_public_key'], // تعيين المفتاح العام
      theirPublicKey: map['their_public_key'], // تعيين المفتاح العام للطرف الآخر
      sharedSecret: map['shared_secret'], // تعيين المفتاح المشترك
    );
  }

  // دالة لإنشاء نسخة جديدة من الكائن مع إمكانية تعديل بعض القيم
  ConversationKey copyWith({
    int? id, // معرف المفتاح (اختياري)
    String? address, // عنوان المحادثة (اختياري)
    String? ownPrivateKey, // المفتاح الخاص بالمستخدم (اختياري)
    String? ownPublicKey, // المفتاح العام للمستخدم (اختياري)
    String? theirPublicKey, // المفتاح العام للطرف الآخر (اختياري)
    String? sharedSecret, // المفتاح المشترك (اختياري)
  }) {
    return ConversationKey(
      id: id ?? this.id, // استخدام القيمة الجديدة إذا تم توفيرها، وإلا القيمة الحالية
      address: address ?? this.address, // نفس المنطق ينطبق على باقي الحقول
      ownPrivateKey: ownPrivateKey ?? this.ownPrivateKey,
      ownPublicKey: ownPublicKey ?? this.ownPublicKey,
      theirPublicKey: theirPublicKey ?? this.theirPublicKey,
      sharedSecret: sharedSecret ?? this.sharedSecret,
    );
  }

  // دالة لتحويل الكائن إلى سلسلة نصية (String) لعرضه بسهولة
  @override
  String toString() {
    return 'ConversationKey(address: $address, ownPrivateKey: $ownPrivateKey, ownPublicKey: $ownPublicKey, theirPublicKey: $theirPublicKey, sharedSecret: $sharedSecret)';
  }
}