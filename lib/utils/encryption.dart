// استيراد المكتبات اللازمة
import 'dart:typed_data'; // للتعامل مع البيانات الثنائية
import 'dart:math'; // لتوليد أرقام عشوائية
import 'package:pointycastle/export.dart'; // مكتبة للتشفير باستخدام Diffie-Hellman
import 'package:encrypt/encrypt.dart' as encrypt; // مكتبة للتشفير وفك التشفير باستخدام AES
import 'package:crypto/crypto.dart'; // مكتبة لتشفير البيانات باستخدام SHA-256
import 'dart:convert'; // لتحويل النصوص إلى بيانات ثنائية والعكس
import 'package:convert/convert.dart'; // لتحويل البيانات إلى تنسيق HEX

// تعريف كلاس DiffieHellmanHelper لتوفير أدوات التشفير باستخدام Diffie-Hellman
class DiffieHellmanHelper {
  // استخدام منحنى secp256k1 لتوليد المفاتيح
  static final ECDomainParameters params = ECDomainParameters('secp256k1');

  // دالة لتوليد زوج من المفاتيح (عام وخاص)
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateKeyPair() {
    final secureRandom = FortunaRandom(); // مولد أرقام عشوائية آمن
    final seedSource = Random.secure(); // مصدر الأرقام العشوائية
    final seed = List<int>.generate(32, (_) => seedSource.nextInt(256)); // توليد بذرة عشوائية
    secureRandom.seed(KeyParameter(Uint8List.fromList(seed))); // تهيئة المولد بالبذرة

    final keyGenerator = ECKeyGenerator()
      ..init(ParametersWithRandom(ECKeyGeneratorParameters(params), secureRandom)); // تهيئة مولد المفاتيح

    return keyGenerator.generateKeyPair(); // إرجاع زوج المفاتيح
  }

  // دالة لتحويل المفتاح العام إلى تنسيق HEX غير مضغوط
  static String encodePublicKey(ECPublicKey publicKey) {
    final x = publicKey.Q!.x!.toBigInteger(); // الحصول على الإحداثي X
    final y = publicKey.Q!.y!.toBigInteger(); // الحصول على الإحداثي Y

    // تحويل الإحداثيات إلى تنسيق سداسي عشر مع padding لضمان 64 حرف لكل منهما
    final xHex = x?.toRadixString(16).padLeft(64, '0');
    final yHex = y?.toRadixString(16).padLeft(64, '0');

    return '04$xHex$yHex'; // 04 + 64 + 64 = 130 حرف
  }

  // دالة لحساب المفتاح المشترك باستخدام Diffie-Hellman
  static BigInt computeSharedSecret(ECPrivateKey privateKey, ECPublicKey publicKey) {
    print("123$publicKey"); // طباعة المفتاح العام للتأكد
    final agreement = ECDHBasicAgreement()..init(privateKey); // تهيئة الاتفاقية باستخدام المفتاح الخاص
    return agreement.calculateAgreement(publicKey); // حساب المفتاح المشترك
  }

  // دالة لاشتقاق مفتاح AES من المفتاح المشترك باستخدام SHA-256
  static String deriveAESKey(BigInt sharedSecret) {
    final bytes = sharedSecret.toRadixString(16).padLeft(64, '0').codeUnits; // تحويل المفتاح إلى نص سداسي عشر
    final digest = sha256.convert(bytes); // تطبيق SHA-256 على النص
    return hex.encode(digest.bytes); // تحويل الناتج إلى تنسيق HEX
  }

  // دالة للحصول على المفتاح العام بتنسيق غير مضغوط
  static String getPublicKey(ECPublicKey publicKey) {
    final encoded = publicKey.Q!.getEncoded(false); // الحصول على المفتاح العام بتنسيق غير مضغوط
    return hex.encode(encoded); // تحويل المفتاح إلى تنسيق HEX
  }

  // دالة لتشفير الرسالة باستخدام AES (وضع CBC)
  static String encryptMessage(String message, BigInt sharedSecret) {
    String aesKey = deriveAESKey(sharedSecret); // اشتقاق مفتاح AES من المفتاح المشترك
    final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32)); // استخدام أول 32 حرف من المفتاح
    final iv = encrypt.IV.fromLength(16); // تهيئة متجه التهيئة (IV) بطول 16 بايت
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc)); // تهيئة التشفير باستخدام AES
    final encrypted = encrypter.encrypt(message, iv: iv); // تشفير الرسالة
    return "${iv.base64}:${encrypted.base64}"; // إرجاع النص المشفر مع IV
  }

  // دالة لفك تشفير الرسالة باستخدام AES (وضع CBC)
  static String decryptMessage(String encryptedMessage, String sharedSecret) {
    String aesKey = deriveAESKey(BigInt.parse(sharedSecret)); // اشتقاق مفتاح AES من المفتاح المشترك
    print("aesKey$aesKey"); // طباعة مفتاح AES للتأكد
    final parts = encryptedMessage.split(':'); // تقسيم النص المشفر إلى IV والرسالة المشفرة
    final iv = encrypt.IV.fromBase64(parts[0]); // استخراج IV
    final encrypted = encrypt.Encrypted.fromBase64(parts[1]); // استخراج النص المشفر
    final key = encrypt.Key.fromUtf8(aesKey.substring(0, 32)); // استخدام أول 32 حرف من المفتاح
    final encrypter = encrypt.Encrypter(encrypt.AES(key, mode: encrypt.AESMode.cbc)); // تهيئة فك التشفير باستخدام AES
    return encrypter.decrypt(encrypted, iv: iv); // فك تشفير الرسالة وإرجاع النص الأصلي
  }
}