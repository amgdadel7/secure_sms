// استيراد المكتبات اللازمة
import 'dart:async'; // للتعامل مع العمليات غير المتزامنة
import 'dart:convert'; // لتحويل البيانات إلى JSON والعكس
import 'package:flutter/material.dart'; // لإنشاء واجهات المستخدم
import 'package:sqflite/sqflite.dart'; // للتعامل مع قواعد البيانات SQLite
import 'package:telephony/telephony.dart'; // للتعامل مع الرسائل النصية SMS
import 'package:permission_handler/permission_handler.dart'; // لإدارة الأذونات
import 'package:path/path.dart'; // للتعامل مع مسارات الملفات
import 'package:flutter/foundation.dart'; // لتوفير ChangeNotifier
import 'package:pointycastle/export.dart'; // مكتبة التشفير
import 'package:untitled14/controllers/registration_controller.dart'; // وحدة التحكم بالتسجيل
import 'package:http/http.dart' as http; // لإجراء طلبات HTTP
import 'package:untitled14/controllers/store_key_controler.dart'; // وحدة التحكم بمفاتيح التشفير
import 'package:untitled14/models/key_info.dart'; // نموذج معلومات المفتاح
import '../models/message_model.dart'; // نموذج الرسالة
import '../models/conversation_key.dart'; // نموذج مفتاح المحادثة
import '../utils/encryption.dart'; // أدوات التشفير

// تعريف وحدة التحكم بالرسائل
class MessageController with ChangeNotifier {
  final Telephony _telephony = Telephony.instance; // تهيئة مكتبة الرسائل النصية

  Database? _messagesDb; // قاعدة بيانات الرسائل
  Database? _keysDb; // قاعدة بيانات مفاتيح التشفير

  // المُنشئ: استدعاء دالة تهيئة قواعد البيانات
  MessageController() {
    initDatabases();
  }

  // دالة لتهيئة قواعد البيانات
  Future<void> initDatabases() async {
    // تهيئة قاعدة بيانات الرسائل
    final messagesPath = await getDatabasesPath(); // الحصول على مسار قواعد البيانات
    final messagesDbPath = join(messagesPath, 'messages.db'); // تحديد مسار قاعدة بيانات الرسائل
    _messagesDb = await openDatabase(
      messagesDbPath,
      version: 1, // الإصدار الأول
      onCreate: (db, version) {
        db.execute(''' // إنشاء جدول الرسائل
          CREATE TABLE messages(
            id INTEGER PRIMARY KEY,
            sender TEXT,
            content TEXT,
            timestamp TEXT,
            isMe INTEGER,
            isEncrypted INTEGER
          )
        ''');
      },
    );

    // تهيئة قاعدة بيانات مفاتيح التشفير
    final keysPath = await getDatabasesPath(); // الحصول على مسار قواعد البيانات
    final keysDbPath = join(keysPath, 'keys.db'); // تحديد مسار قاعدة بيانات المفاتيح
    _keysDb = await openDatabase(
      keysDbPath,
      version: 2, // الإصدار الثاني
      onCreate: (db, version) {
        db.execute(''' // إنشاء جدول مفاتيح المحادثات
          CREATE TABLE conversation_keys(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            address TEXT,
            sender_id TEXT,
            own_private_key TEXT,
            own_public_key TEXT,
            their_public_key TEXT,
            shared_secret TEXT
          )
        ''');
      },
      onUpgrade: (db, oldVersion, newVersion) {
        if (oldVersion < 2) {
          db.execute('ALTER TABLE conversation_keys ADD COLUMN sender_id TEXT'); // إضافة عمود جديد
        }
      },
    );
  }

  // دالة لجلب جميع الرسائل من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getMessages() async {
    if (_messagesDb != null) {
      List<Map<String, dynamic>> messages = await _messagesDb!.query('messages'); // جلب الرسائل
      print("messages______${messages}"); // طباعة الرسائل
      return messages;
    } else {
      throw Exception('قاعدة البيانات غير مهيأة.'); // خطأ إذا لم تكن قاعدة البيانات مهيأة
    }
  }

  // دالة لطباعة الرسائل في وحدة التحكم
  void printMessages() async {
    try {
      List<Map<String, dynamic>> messages = await getMessages(); // جلب الرسائل
      for (var message in messages) {
        print('ID: ${message['id']}, Sender: ${message['sender']}, Content: ${message['content']}, Timestamp: ${message['timestamp']}, IsMe: ${message['isMe']}, IsEncrypted: ${message['isEncrypted']}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e'); // طباعة الخطأ
    }
  }

  // دالة لجلب مفاتيح المحادثات من قاعدة البيانات
  Future<List<Map<String, dynamic>>> getConversationKeys() async {
    if (_keysDb != null) {
      List<Map<String, dynamic>> keys = await _keysDb!.query('conversation_keys'); // جلب المفاتيح
      print("keys______${keys}"); // طباعة المفاتيح
      return keys;
    } else {
      throw Exception('قاعدة البيانات غير مهيأة.'); // خطأ إذا لم تكن قاعدة البيانات مهيأة
    }
  }

  // دالة لطباعة مفاتيح المحادثات في وحدة التحكم
  void printConversationKeys() async {
    try {
      List<Map<String, dynamic>> keys = await getConversationKeys(); // جلب المفاتيح
      for (var key in keys) {
        print('ID: ${key['id']}, Address: ${key['address']}, Sender ID: ${key['sender_id']}, Own Private Key: ${key['own_private_key']}, Own Public Key: ${key['own_public_key']}, Their Public Key: ${key['their_public_key']}, Shared Secret: ${key['shared_secret']}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e'); // طباعة الخطأ
    }
  }

  // دالة لجلب جميع الرسائل النصية (الوارد والصادر)
  Future<List<SmsMessage>> getAllMessages() async {
    if (await Permission.sms.status.isGranted) { // التحقق من إذن الرسائل النصية
      List<SmsMessage> inbox = await _telephony.getInboxSms(); // جلب الرسائل الواردة
      List<SmsMessage> sent = await _telephony.getSentSms(); // جلب الرسائل الصادرة
      List<SmsMessage> allMessages = []..addAll(inbox)..addAll(sent); // دمج الرسائل
      return allMessages;
    } else {
      throw "تم رفض إذن قراءة الرسائل"; // خطأ إذا لم يُمنح الإذن
    }
  }

  // دالة لجلب الرسائل النصية مجمعة حسب العنوان
  Future<Map<String, List<SmsMessage>>> getGroupedMessages() async {
    List<SmsMessage> allMessages = await getAllMessages(); // جلب جميع الرسائل
    Map<String, List<SmsMessage>> groupedMessages = {};

    for (var message in allMessages) {
      String address = message.address ?? "Unknown"; // عنوان المرسل
      if (!groupedMessages.containsKey(address)) {
        groupedMessages[address] = []; // إنشاء مجموعة جديدة إذا لم تكن موجودة
      }
      groupedMessages[address]!.add(message); // إضافة الرسالة إلى المجموعة
    }

    return groupedMessages;
  }

  // دالة لمعالجة الرسائل الواردة
  Future<void> processIncomingSms(SmsMessage sms) async {
    String address = sms.address ?? 'Unknown'; // عنوان المرسل
    String content = sms.body ?? ''; // محتوى الرسالة
    DateTime timestamp = DateTime.now(); // الوقت الحالي
    bool isMe = false; // الإشارة إلى أن الرسالة ليست مرسلة من المستخدم

    ConversationKey? key = await getConversationKey(address); // جلب مفتاح المحادثة
    String decryptedContent = content; // النص المفكك
    bool isEncrypted = false; // حالة التشفير

    if (key != null && key.sharedSecret != null) {
      try {
        decryptedContent = DiffieHellmanHelper.decryptMessage(content, key.sharedSecret!); // فك التشفير
        isEncrypted = true; // تم فك التشفير بنجاح
        print("تم فك تشفير الرسالة من $address: $decryptedContent");
      } catch (e) {
        print('فشل في فك تشفير الرسالة: $e'); // طباعة الخطأ
      }
    }

    // إنشاء كائن الرسالة
    Message message = Message(
      sender: address,
      content: decryptedContent,
      timestamp: timestamp,
      isMe: isMe,
      isEncrypted: isEncrypted, // تعيين حالة التشفير الصحيحة
    );
    await _insertMessage(message); // إدخال الرسالة في قاعدة البيانات

    notifyListeners(); // إعلام المستمعين بالتغيير
  }

  // دالة لإدخال الرسالة في قاعدة البيانات
  Future<void> _insertMessage(Message message) async {
    await _messagesDb?.insert('messages', message.toMap()); // إدخال الرسالة
    notifyListeners(); // إعلام المستمعين بالتغيير
  }

  // دالة لإرسال رسالة مشفرة
  Future<void> sendEncryptedMessage(String encryptedMessage, String plainTextMessage, String recipient) async {
    try {
      if (await Permission.sms.request().isGranted) { // التحقق من إذن الرسائل النصية
        print("encryptedMessage$encryptedMessage");
        print("encryptedMessage$plainTextMessage");
        print("encryptedMessage$recipient");
        await _telephony.sendSms(
          to: recipient, // المرسل إليه
          message: encryptedMessage, // الرسالة المشفرة
        );
        // تخزين الرسالة الأصلية غير المشفرة محليًا
        Message localMessage = Message(
          sender: recipient,
          content: plainTextMessage, // النص الأصلي
          timestamp: DateTime.now(),
          isMe: true,
          isEncrypted: true, // الإشارة إلى أن الرسالة مرسلة مشفرة
        );
        await _insertMessage(localMessage); // إدخال الرسالة في قاعدة البيانات

        notifyListeners(); // إعلام المستمعين بالتغيير
      }
    } catch (e) {
      throw "فشل في إرسال الرسالة: $e"; // طباعة الخطأ
    }
  }

  // دالة لجلب رقم الهاتف الخاص بالجهاز
  Future<dynamic> getAndPrintPhoneNumber() async {
    final LocalDatabaseService localDatabaseService = LocalDatabaseService(); // خدمة قاعدة البيانات المحلية
    var senderNumber = await localDatabaseService.getDeviceInfo(); // جلب معلومات الجهاز
    if (senderNumber != null) {
      print('UUID: ${senderNumber["phone_num"]}'); // طباعة رقم الهاتف
      return senderNumber["phone_num"];
    } else {
      print('لا يوجد Sender Phone Number'); // طباعة رسالة خطأ
      return null;
    }
  }

  // دالة لجلب UUID الخاص بالجهاز
  Future<dynamic> getAndPrintUuid() async {
    final LocalDatabaseService localDatabaseService = LocalDatabaseService(); // خدمة قاعدة البيانات المحلية
    final deviceInfo = await localDatabaseService.getDeviceInfo(); // جلب معلومات الجهاز

    if (deviceInfo != null) {
      final senderUUID = deviceInfo['uuid']!; // UUID الخاص بالجهاز
      final senderNUM = deviceInfo['phone_num']!; // رقم الهاتف الخاص بالجهاز
      print('UUID: $senderUUID');
      print('Phone Number: $senderNUM');
      return deviceInfo;
    } else {
      print('لا توجد معلومات جهاز محفوظة محلياً'); // طباعة رسالة خطأ
    }
  }

  // دالة للبحث عن UUID لجهاز معين باستخدام API
  Future<String?> findDeviceUuid(String searchValue) async {
    try {
      final response = await http.post(
        Uri.parse('https://political-thoracic-spatula.glitch.me/api/find-device'), // عنوان API
        headers: {'Content-Type': 'application/json'}, // نوع المحتوى
        body: jsonEncode({'searchValue': searchValue}), // البيانات المرسلة
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // فك تشفير الاستجابة
        String receverUUID = data['uuid'] as String; // UUID المستلم
        print('UUID2: $receverUUID');
        return receverUUID;
      } else {
        print('فشل البحث: ${response.statusCode}'); // طباعة الخطأ
        return null;
      }
    } catch (e) {
      print('خطأ في الاتصال: $e'); // طباعة الخطأ
      return null;
    }
  }

  // دالة للحصول على آخر 9 أرقام من العنوان
  String getLastNineDigits(String address) {
    String digits = address.replaceAll(RegExp(r'\D'), ''); // إزالة الأحرف غير الرقمية
    if (digits.length > 9) {
      return digits.substring(digits.length - 9); // الاحتفاظ بآخر 9 أرقام
    }
    return digits;
  }

  // دالة لجلب الرسائل لمحادثة معينة
  Future<List<Message>> getMessagesForThread(String address) async {
    print("okkk");
    if (!await Permission.sms.status.isGranted) { // التحقق من إذن الرسائل النصية
      throw Exception("تم رفض إذن قراءة الرسائل");
    }

    List<Message> allMessages = await _getAllMessages(); // جلب جميع الرسائل
    bool isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(address); // التحقق إذا كان العنوان نصيًا
    List<Message> filteredMessages = _filterMessagesByAddress(allMessages, address, isTextAddress); // تصفية الرسائل
    if (!isTextAddress) {
      filteredMessages = await _processNumericDecryption(filteredMessages, address); // فك التشفير إذا كان العنوان رقميًا
    }
    return filteredMessages;
  }

  // دالة لجلب جميع الرسائل من الوارد والصادر
  Future<List<Message>> _getAllMessages() async {
    List<SmsMessage> inbox = await _telephony.getInboxSms(); // جلب الرسائل الواردة
    List<SmsMessage> sent = await _telephony.getSentSms(); // جلب الرسائل الصادرة
    return [
      ...inbox.map((sms) => _convertSmsToMessage(sms, false)), // تحويل الرسائل الواردة إلى كائنات Message
      ...sent.map((sms) => _convertSmsToMessage(sms, true)), // تحويل الرسائل الصادرة إلى كائنات Message
    ];
  }

  // دالة لتصفية الرسائل حسب العنوان
  List<Message> _filterMessagesByAddress(List<Message> messages, String address, bool isTextAddress) {
    return messages.where((message) {
      if (message.sender == null) return false;
      if (isTextAddress) {
        return message.sender == address; // مقارنة نصية مباشرة
      } else {
        String messageDigits = _getLastNDigits(message.sender!, 9); // الحصول على آخر 9 أرقام من المرسل
        String addressDigits = _getLastNDigits(address, 9); // الحصول على آخر 9 أرقام من العنوان
        return messageDigits == addressDigits; // مقارنة الأرقام
      }
    }).toList();
  }

   // دالة لاستخراج آخر [count] أرقام من سلسلة نصية
  String _getLastNDigits(String phone, int count) {
    // إزالة أي أحرف غير رقمية من النص
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    // إذا كان طول النص أكبر من أو يساوي [count]، يتم استخراج آخر [count] أرقام
    return cleaned.length >= count ? cleaned.substring(cleaned.length - count) : cleaned;
  }
  
  // دالة لمعالجة الرسائل الرقمية وفك تشفيرها
  Future<List<Message>> _processNumericDecryption(List<Message> messages, String address) async {
    // الحصول على بيانات الجهاز مثل UUID ورقم الهاتف
    final senderData = await getAndPrintUuid(); // مثال: {'uuid': 'sender-123', 'phone_num': '0555123456'}
    final senderNum = await getAndPrintPhoneNumber(); // رقم المرسل الفعلي
    String lastNine = _getLastNDigits(address, 9); // استخراج آخر 9 أرقام من العنوان
    final dbHelper = DatabaseHelper(); // تهيئة كائن قاعدة البيانات
    String? receiverUUID;
  
    // محاولة البحث في قاعدة البيانات المحلية باستخدام (senderNUM, receiverNUM)
    receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
      senderNUM: senderNum,
      receiverNUM: lastNine,
    );
    print("نتيجة البحث الأولى - senderNum: $senderNum, lastNine: $lastNine, receiverUUID: $receiverUUID");
  
    // إذا لم توجد بيانات، نقوم بمحاولة البحث بترتيب معكوس
    if (receiverUUID == null) {
      receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
        senderNUM: lastNine,
        receiverNUM: senderNum,
      );
      print("بحث بالترتيب المعكوس - lastNine: $lastNine, receiverUUID: $receiverUUID");
  
      // إذا لم توجد بيانات في قاعدة البيانات المحلية، يتم محاولة جلبها عبر API
      if (receiverUUID == null) {
        final response = await http.post(
          Uri.parse('https://political-thoracic-spatula.glitch.me/api/check-key'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'senderNUM': lastNine,
            'receiverNUM': senderNum,
          }),
        );
  
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success']) {
            print('تم العثور على المفتاح: ${data['data']['senderUUID']}');
            receiverUUID = data['data']['receiverUUID'];
            await dbHelper.storeKeysLocally(
              senderUUID: data['data']['senderUUID'],
              senderNUM: data['data']['senderNUM'],
              receiverUUID: data['data']['receiverUUID'],
              receiverNUM: data['data']['receiverNUM'],
              sharedSecret: BigInt.parse(data['data']['sharedSecret']),
            );
          } else {
            print('لا يوجد مفتاح مشترك.');
          }
        }
      }
    }
  
    // إذا لم يتم العثور على UUID، يتم إرجاع الرسائل كما هي
    if (receiverUUID == null) {
      print("receiverUUID: $receiverUUID");
      return messages;
    }
  
    // محاولة استرجاع المفتاح المشترك من قاعدة البيانات المحلية
    BigInt? sharedSecret;
    if (receiverUUID != null) {
      List<Map<String, dynamic>> results = await dbHelper.fetchKeyInfoByNumbers(
        senderNUM: senderNum,
        receiverNUM: lastNine,
      );
  
      if (results.isEmpty) {
        results = await dbHelper.fetchKeyInfoByNumbers(
          senderNUM: lastNine,
          receiverNUM: senderNum,
        );
      }
  
      if (results.isNotEmpty) {
        final keyData = results.first;
        print('🔑 المفتاح المشترك: ${keyData['sharedSecret']}');
        _decryptMessages(messages, BigInt.parse(keyData['sharedSecret']));
      }
    }
  
    return messages;
  }
  
  // دالة لفك تشفير الرسائل باستخدام المفتاح المشترك
  void _decryptMessages(List<Message> messages, BigInt sharedSecret) {
    for (var message in messages) {
      try {
        final text = message.content.toString();
        final decryptedText = DiffieHellmanHelper.decryptMessage(
            text, sharedSecret.toString()); // فك تشفير النص
        message.content = decryptedText; // تحديث محتوى الرسالة بالنص المفكك
        print("تم فك التشفير: $text");
      } catch (e) {
        print('فشل في فك تشفير الرسالة: $e'); // طباعة الخطأ إذا فشل فك التشفير
      }
    }
  }
  
  // دالة لجلب المفتاح المشترك من API باستخدام أرقام الهواتف
  Future<BigInt?> _fetchSharedSecretFromApiByNum(
      String senderNUM,
      String receiverNUM,
      DatabaseHelper dbHelper) async {
    final String baseUrl = 'https://political-thoracic-spatula.glitch.me';
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/get-keys-by-num'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderNUM': senderNUM,
          'receiverNUM': receiverNUM,
        }),
      ).timeout(const Duration(seconds: 10));
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());
          await dbHelper.storeKeysLocally(
            senderUUID: keyInfo.senderUUID,
            senderNUM: keyInfo.senderNUM,
            receiverUUID: keyInfo.receiverUUID,
            receiverNUM: keyInfo.receiverNUM,
            sharedSecret: secret,
          );
          return secret;
        } else {
          print("API /api/get-keys-by-num لم تُرجع بيانات");
          return null;
        }
      } else {
        throw Exception('فشل في الحصول على المفاتيح بواسطة API: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('فشل الاتصال بال API: ${e.message}');
    } on TimeoutException {
      throw Exception('انتهى وقت الانتظار لل API');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }
  
  // دالة لاستدعاء API لجلب المفاتيح وتخزينها محلياً
  Future<BigInt?> _fetchSharedSecretFromApi(
      String senderUUID,
      String receiverUUID,
      DatabaseHelper dbHelper) async {
    final String baseUrl = 'https://political-thoracic-spatula.glitch.me';
    try {
      http.Response response;
  
      // المحاولة الأولى باستخدام الترتيب الأصلي
      response = await http.post(
        Uri.parse('$baseUrl/api/get-keys'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderUUID': senderUUID,
          'receiverUUID': receiverUUID,
        }),
      );
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());
          await dbHelper.storeKeysLocally(
            senderUUID: senderUUID,
            senderNUM: keyInfo.senderNUM,
            receiverUUID: receiverUUID,
            receiverNUM: keyInfo.receiverNUM,
            sharedSecret: secret,
          );
          return secret;
        }
      }
  
      // المحاولة الثانية باستخدام الترتيب المعكوس
      response = await http.post(
        Uri.parse('$baseUrl/api/get-keys'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderUUID': receiverUUID,
          'receiverUUID': senderUUID,
        }),
      );
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && data['data'] != null) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());
          await dbHelper.storeKeysLocally(
            senderUUID: receiverUUID,
            senderNUM: keyInfo.senderNUM,
            receiverUUID: senderUUID,
            receiverNUM: keyInfo.receiverNUM,
            sharedSecret: secret,
          );
          return secret;
        }
      }
  
      throw Exception('فشل في الحصول على المفاتيح بعد المحاولات: ${response.statusCode}');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }
  
  // دالة لتحويل رسالة SMS إلى كائن Message
  Message _convertSmsToMessage(SmsMessage sms, bool isMe) {
    final body = sms.body ?? "";
    final isEncrypted = body.startsWith('ENC:'); // التحقق إذا كانت الرسالة مشفرة
    final content = isEncrypted ? body.substring(4) : body; // إزالة بادئة التشفير إذا كانت موجودة
  
    return Message(
      sender: sms.address ?? "Unknown",
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
      isMe: isMe,
      isEncrypted: isEncrypted,
    );
  }
  
  // دالة لإدخال مفتاح المحادثة في قاعدة البيانات
  Future<void> _insertConversationKey(ConversationKey key) async {
    await _keysDb?.insert(
      'conversation_keys',
      key.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
  
  // دالة لتوليد زوج من المفاتيح العامة والخاصة
  Future<Map<String, String>?> getKeyPair(String address) async {
    try {
      final keyPair = DiffieHellmanHelper.generateKeyPair();
      final ecPrivate = keyPair.privateKey as ECPrivateKey;
      final ecPublic = keyPair.publicKey as ECPublicKey;
  
      return {
        'publicKey': '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}',
        'privateKey': ecPrivate.d!.toString(),
      };
    } catch (e) {
      print('فشل في توليد المفاتيح: $e');
      return null;
    }
  }
  
  // دالة للحصول على مفتاح المحادثة
  Future<ConversationKey?> getConversationKey(String address) async {
    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPrivate = keyPair.privateKey as ECPrivateKey;
    final ecPublic = keyPair.publicKey as ECPublicKey;
  
    final ownPrivateKey = ecPrivate.d!.toRadixString(16); // تحويل المفتاح الخاص إلى HEX
    final ownPublicKey = DiffieHellmanHelper.encodePublicKey(ecPublic);
  
    final newKey = ConversationKey(
      address: address,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: null,
      sharedSecret: null,
    );
  
    await _insertConversationKey(newKey);
  
    return newKey;
  }
  
  // دالة لبدء تبادل المفاتيح
  Future<void> initiateKeyExchange(String recipient) async {
    ConversationKey? existingKey = await getConversationKey(recipient);
    if (existingKey != null && existingKey.sharedSecret != null) {
      print("Existing shared secret: ${existingKey.sharedSecret}");
      return;
    }
  
    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPrivate = keyPair.privateKey as ECPrivateKey;
    final ecPublic = keyPair.publicKey as ECPublicKey;
    String ownPrivateKey = ecPrivate.d!.toString();
    String ownPublicKey = '${ecPublic.Q!.x!.toBigInteger()}:${ecPublic.Q!.y!.toBigInteger()}';
  
    ConversationKey newKey = ConversationKey(
      address: recipient,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: null,
      sharedSecret: null,
    );
    await _insertConversationKey(newKey);
  }
  
  // دالة لتطبيع رقم الهاتف
  String normalizePhoneNumber(String phoneNumber) {
    if (RegExp(r'[^0-9+]').hasMatch(phoneNumber)) {
      return phoneNumber;
    }
  
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
  
    if (normalized.startsWith('+')) {
      return normalized.length >= 9
          ? normalized.substring(normalized.length - 9)
          : normalized;
    }
  
    if (normalized.length >= 9) {
      return normalized.substring(normalized.length - 9);
    }
  
    return normalized;
  }
  
  // دالة لجلب المحادثات
  Future<Map<String, List<SmsMessage>>> getConversations({bool forceRefresh = false}) async {
    if (!await Permission.sms.request().isGranted) {
      throw "تم رفض إذن قراءة الرسائل";
    }
  
    if (forceRefresh || _cachedConversations.isEmpty) {
      final List<SmsMessage> inbox = await _telephony.getInboxSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE, SmsColumn.READ],
      );
      final List<SmsMessage> sent = await _telephony.getSentSms(
        columns: [SmsColumn.ADDRESS, SmsColumn.BODY, SmsColumn.DATE],
      );
  
      Map<String, List<SmsMessage>> groupedMessages = {};
  
      void groupMessages(SmsMessage message) {
        String? rawAddress = message.address;
        if (rawAddress == null) return;
  
        final isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(rawAddress);
        final normalizedAddress = isTextAddress ? rawAddress : normalizePhoneNumber(rawAddress);
        groupedMessages.putIfAbsent(normalizedAddress, () => []);
        groupedMessages[normalizedAddress]!.add(message);
      }
  
      for (var message in [...inbox, ...sent]) {
        groupMessages(message);
      }
  
      _cachedConversations = groupedMessages;
    }
  
    return _cachedConversations..removeWhere((key, value) => value.isEmpty);
  }