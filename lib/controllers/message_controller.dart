import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:telephony/telephony.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:pointycastle/export.dart';
import 'package:untitled14/controllers/registration_controller.dart';
import 'package:http/http.dart' as http;
import 'package:untitled14/controllers/store_key_controler.dart';
import 'package:untitled14/models/key_info.dart';
import '../models/message_model.dart';
import '../models/conversation_key.dart';
import '../utils/encryption.dart';


class MessageController with ChangeNotifier {
  final Telephony _telephony = Telephony.instance;

  Database? _messagesDb;
  Database? _keysDb;

  MessageController() {
    initDatabases();
  }

  Future<void> initDatabases() async {
    final messagesPath = await getDatabasesPath();
    final messagesDbPath = join(messagesPath, 'messages.db');
    _messagesDb = await openDatabase(
      messagesDbPath,
      version: 1,
      onCreate: (db, version) {
        db.execute('''
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

    final keysPath = await getDatabasesPath();
    final keysDbPath = join(keysPath, 'keys.db');
    _keysDb = await openDatabase(
      keysDbPath,
      version: 2, // زيادة رقم الإصدار
      onCreate: (db, version) {
        db.execute('''
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
          db.execute('ALTER TABLE conversation_keys ADD COLUMN sender_id TEXT');
        }
      },
    );
  }

  Future<List<Map<String, dynamic>>> getMessages() async {
    if (_messagesDb != null) {
      List<Map<String, dynamic>> messages = await _messagesDb!.query('messages');
      print("messages______${messages}");
      return messages;
    } else {
      throw Exception('قاعدة البيانات غير مهيأة.');
    }
  }

  void printMessages() async {
    try {
      List<Map<String, dynamic>> messages = await getMessages();
      for (var message in messages) {
        print('ID: ${message['id']}, Sender: ${message['sender']}, Content: ${message['content']}, Timestamp: ${message['timestamp']}, IsMe: ${message['isMe']}, IsEncrypted: ${message['isEncrypted']}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e');
    }
  }

  Future<List<Map<String, dynamic>>> getConversationKeys() async {
    if (_keysDb != null) {
      List<Map<String, dynamic>> keys = await _keysDb!.query('conversation_keys');
      print("keys______${keys}");
      return keys;
    } else {
      throw Exception('قاعدة البيانات غير مهيأة.');
    }
  }

  void printConversationKeys() async {
    try {
      List<Map<String, dynamic>> keys = await getConversationKeys();
      for (var key in keys) {
        print('ID: ${key['id']}, Address: ${key['address']}, Sender ID: ${key['sender_id']}, Own Private Key: ${key['own_private_key']}, Own Public Key: ${key['own_public_key']}, Their Public Key: ${key['their_public_key']}, Shared Secret: ${key['shared_secret']}');
      }
    } catch (e) {
      print('حدث خطأ أثناء جلب البيانات: $e');
    }
  }

  Future<List<SmsMessage>> getAllMessages() async {
    if (await Permission.sms.status.isGranted) {
      List<SmsMessage> inbox = await _telephony.getInboxSms();
      List<SmsMessage> sent = await _telephony.getSentSms();
      List<SmsMessage> allMessages = []..addAll(inbox)..addAll(sent);
      return allMessages;
    } else {
      throw "تم رفض إذن قراءة الرسائل";
    }
  }

  Future<Map<String, List<SmsMessage>>> getGroupedMessages() async {
    List<SmsMessage> allMessages = await getAllMessages();
    Map<String, List<SmsMessage>> groupedMessages = {};

    for (var message in allMessages) {
      String address = message.address ?? "Unknown";
      if (!groupedMessages.containsKey(address)) {
        groupedMessages[address] = [];
      }
      groupedMessages[address]!.add(message);
    }

    return groupedMessages;
  }

  Future<void> processIncomingSms(SmsMessage sms) async {
    String address = sms.address ?? 'Unknown';
    String content = sms.body ?? '';
    DateTime timestamp = DateTime.now();
    bool isMe = false;

    ConversationKey? key = await getConversationKey(address);
    String decryptedContent = content;
    bool isEncrypted = false;

    if (key != null && key.sharedSecret != null) {
      try {
        decryptedContent = DiffieHellmanHelper.decryptMessage(content, key.sharedSecret!);
        isEncrypted = true; // تم فك التشفير بنجاح
        print("تم فك تشفير الرسالة من $address: $decryptedContent");
      } catch (e) {
        print('فشل في فك تشفير الرسالة: $e');
      }
    }

    Message message = Message(
      sender: address,
      content: decryptedContent,
      timestamp: timestamp,
      isMe: isMe,
      isEncrypted: isEncrypted, // تعيين حالة التشفير الصحيحة
    );
    await _insertMessage(message);

    notifyListeners();
  }

  Future<void> _insertMessage(Message message) async {
    await _messagesDb?.insert('messages', message.toMap());
    notifyListeners();
  }
  Future<void> sendEncryptedMessage(String encryptedMessage, String plainTextMessage, String recipient) async {
    try {
      if (await Permission.sms.request().isGranted) {
        // إرسال الرسالة المشفرة
        print("encryptedMessage$encryptedMessage");
        print("encryptedMessage$plainTextMessage");
        print("encryptedMessage$recipient");
        await _telephony.sendSms(
          to: recipient,
          message: encryptedMessage,
        );
        // تخزين الرسالة الأصلية غير المشفرة محليًا
        Message localMessage = Message(
          sender: recipient,
          content: plainTextMessage, // حفظ النص الأصلي
          timestamp: DateTime.now(),
          isMe: true,
          isEncrypted: true, // الإشارة إلى أن الرسالة مرسلة مشفرة
        );
        await _insertMessage(localMessage);


        notifyListeners();
      }
    } catch (e) {
      throw "فشل في إرسال الرسالة: $e";
    }
  }

  Future<dynamic> getAndPrintPhoneNumber() async {
    final LocalDatabaseService localDatabaseService = LocalDatabaseService();
    var senderNumber = await localDatabaseService.getDeviceInfo();
    if (senderNumber != null) {
      print('UUID: ${senderNumber["phone_num"]}');
      return senderNumber["phone_num"];
    } else {
      print('لا يوجد Sender Phone Number');
      return null;
    }


  }
  Future<dynamic> getAndPrintUuid() async {
    // 2. استدعاء الدالة
    final LocalDatabaseService localDatabaseService = LocalDatabaseService();
    final deviceInfo = await localDatabaseService.getDeviceInfo();

    if (deviceInfo != null) {
      final senderUUID = deviceInfo['uuid']!;
      final senderNUM = deviceInfo['phone_num']!; // جلب رقم الهاتف من الجهاز
      print('UUID: $senderUUID');
      print('Phone Number: $senderNUM');
      return deviceInfo;
    } else {
      print('لا توجد معلومات جهاز محفوظة محلياً');
    }
  }
  Future<String?> findDeviceUuid(String searchValue) async {
    try {
      final response = await http.post(
        Uri.parse(
            'https://political-thoracic-spatula.glitch.me/api/find-device'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'searchValue': searchValue}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String receverUUID = data['uuid'] as String;
        print('UUID2: $receverUUID');
        return receverUUID;
      } else {
        print('فشل البحث: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('خطأ في الاتصال: $e');
      return null;
    }
  }
  String getLastNineDigits(String address) {
    // إزالة أي مسافات أو أحرف غير رقمية إن لزم الأمر
    String digits = address.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      return digits.substring(digits.length - 9);
    }
    return digits;
  }


  Future<List<Message>> getMessagesForThread(String address) async {
    print("okkk");
    // التأكد من صلاحية قراءة الرسائل.
    if (!await Permission.sms.status.isGranted) {
      throw Exception("تم رفض إذن قراءة الرسائل");
    }

    // 1. الحصول على كل الرسائل من الوارد والصادر.
    List<Message> allMessages = await _getAllMessages();
    // 2. تحديد نوع العنوان: نصي أم رقمي.
    bool isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(address);
    // 3. تصفية الرسائل بناءً على العنوان.
    List<Message> filteredMessages = _filterMessagesByAddress(allMessages, address, isTextAddress);
    // 4. في حالة كون العنوان رقمي يتم معالجة فك التشفير.
    if (!isTextAddress) {
      filteredMessages = await _processNumericDecryption(filteredMessages, address);
    }
    return filteredMessages;
  }

  /// 1. دالة لاسترجاع كل الرسائل من الوارد والصادر.
  Future<List<Message>> _getAllMessages() async {
    List<SmsMessage> inbox = await _telephony.getInboxSms();
    List<SmsMessage> sent = await _telephony.getSentSms();
    return [
      ...inbox.map((sms) => _convertSmsToMessage(sms, false)),
      ...sent.map((sms) => _convertSmsToMessage(sms, true)),
    ];
  }

  /// 2. دالة لتصفية الرسائل حسب العنوان.
  List<Message> _filterMessagesByAddress(List<Message> messages, String address, bool isTextAddress) {
    return messages.where((message) {
      if (message.sender == null) return false;
      if (isTextAddress) {
        // مقارنة نصية مباشرة.
        return message.sender == address;
      } else {
        // مقارنة تعتمد على آخر 9 أرقام.
        String messageDigits = _getLastNDigits(message.sender!, 9);
        String addressDigits = _getLastNDigits(address, 9);
        return messageDigits == addressDigits;
      }
    }).toList();
  }

  /// 3. دالة استخراج آخر [count] أرقام من السلسلة.
  String _getLastNDigits(String phone, int count) {
    String cleaned = phone.replaceAll(RegExp(r'[^0-9]'), '');
    return cleaned.length >= count ? cleaned.substring(cleaned.length - count) : cleaned;
  }
  Future<List<Message>> _processNumericDecryption(List<Message> messages, String address) async {
    // الحصول على بيانات الجهاز: senderData و senderNum.
    final senderData = await getAndPrintUuid(); // مثال: {'uuid': 'sender-123', 'phone_num': '0555123456'}
    final senderNum = await getAndPrintPhoneNumber(); // رقم المرسل الفعلي.
    String lastNine = _getLastNDigits(address, 9);
    final dbHelper = DatabaseHelper();
    String? receiverUUID;

    // محاولة البحث في قاعدة البيانات المحلية باستخدام (senderNUM, receiverNUM).
    receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
      senderNUM: senderNum,
      receiverNUM: lastNine,
    );
    print("نتيجة البحث الأولى - senderNum: $senderNum, lastNine: $lastNine, receiverUUID: $receiverUUID");

    // إذا لم توجد بيانات، نقوم بمحاولة البحث بترتيب معكوس.
    if (receiverUUID == null) {
      receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
        senderNUM: lastNine,
        receiverNUM: senderNum,
      );
      print("بحث بالترتيب المعكوس - lastNine: $lastNine, receiverUUID: $receiverUUID");
      // يمكننا أيضاً محاولة جلب البيانات عبر API باستخدام أرقام الهاتف
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
          // print('تم العثور على المفتاح: ${data['data']}');

          if (data['success']) {
            print('تم العثور على المفتاح: ${data['data']['senderUUID']}');
            // تأكد أن المفتاح هو 'receiverUUID' وليس 'receiverNUM'
            receiverUUID = data['data']['receiverUUID'];
            await dbHelper.storeKeysLocally(
              senderUUID: data['data']['senderUUID'],
              senderNUM: data['data']['senderNUM'],
              receiverUUID: data['data']['receiverUUID'], // <-- هنا يجب أن يكون receiverUUID
              receiverNUM: data['data']['receiverNUM'],
              sharedSecret: BigInt.parse(data['data']['sharedSecret']), // تأكد من التحويل الصحيح
            );
          } else {
            print('لا يوجد مفتاح مشترك.');
          }
        }
      }
    }

    if (receiverUUID == null) {
      print("receiverUUID: $receiverUUID");
      receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
        senderNUM: senderNum,
        receiverNUM: lastNine,
      );
      if (receiverUUID == null) {
        print("receiverUUID: $receiverUUID");
        receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
          senderNUM: lastNine,
          receiverNUM: senderNum,
        );
      }
      if (receiverUUID == null) {
        print("receiverUUID: $receiverUUID");
        return messages;
      }
    }
    // محاولة استرجاع المفتاح المشترك من قاعدة البيانات المحلية.
    BigInt? sharedSecret;
      print("receiverUUID: $receiverUUID");
    if (receiverUUID != null) {
      print("receiverUUID: $receiverUUID");
      List<Map<String, dynamic>> results = await dbHelper.fetchKeyInfoByNumbers(
        senderNUM: senderNum,
        receiverNUM: lastNine,
      );
      if (results.isEmpty) {
        List<Map<String, dynamic>> results = await dbHelper.fetchKeyInfoByNumbers(
          senderNUM: lastNine,
          receiverNUM: senderNum,
        );
        print("receiverUUID: $sharedSecret");

      }
      if (results.isNotEmpty) {
        final keyData = results.first;
        print('🔑 المفتاح المشترك: ${keyData['sharedSecret']}');
        _decryptMessages(messages, BigInt.parse(keyData['sharedSecret']));
      }
    }

    return messages;

  }

  /// دالة لفك تشفير الرسائل باستخدام المفتاح المشترك.
  void _decryptMessages(List<Message> messages, BigInt sharedSecret) {
    for (var message in messages) {
      try {
        final text = message.content.toString();
        final decryptedText = DiffieHellmanHelper.decryptMessage(
            text, sharedSecret.toString());
        message.content = decryptedText;
        print("asd$text");
      } catch (e) {
        print('فشل في فك تشفير الرسالة: $e');
      }
    }
  }
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
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].toString().isNotEmpty) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());
          // حفظ البيانات في قاعدة البيانات المحلية بعد الحصول منها عبر API
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

  /// دالة لاستدعاء API لجلب المفاتيح وتخزينها محلياً.
  /// تحاول الدالة أولاً استخدام الترتيب (senderUUID, receiverUUID)
  /// وإن لم تجد بيانات ثم تستخدم الترتيب المعكوس.
  Future<BigInt?> _fetchSharedSecretFromApi(
      String senderUUID,
      String receiverUUID,
      DatabaseHelper dbHelper) async {
    final String baseUrl = 'https://political-thoracic-spatula.glitch.me';
    print("okkkkkkkkkkkkkkkkkk");
    try {
      http.Response response;
      // استخدام payload بالترتيب الأصلي.
      response = await http.post(
        Uri.parse('$baseUrl/api/get-keys'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'senderUUID': senderUUID,
          'receiverUUID': receiverUUID,
        }),
      );

      // إذا كانت الاستجابة ناجحة ونحصل على بيانات.
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].toString().isNotEmpty) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());
          // تخزين المفتاح محلياً.
          await dbHelper.storeKeysLocally(
            senderUUID: senderUUID,
            senderNUM: keyInfo.senderNUM,
            receiverUUID: receiverUUID,
            receiverNUM: keyInfo.receiverNUM,
            sharedSecret: secret,
          );
          return secret;
        } else {
          print("API لم تُرجع بيانات بالترتيب الأصلي.");
        }
      } else {
        throw Exception('فشل في الحصول على المفاتيح: ${response.statusCode}');
      }

      // المحاولة الثانية: عكس القيم
      print("المحاولة الثانية لعكس القيم...");
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
        if (data['success'] == true &&
            data['data'] != null &&
            data['data'].toString().isNotEmpty) {
          final keyInfo = KeyInfo.fromJson(data['data']);
          final secret = BigInt.parse(keyInfo.sharedSecret.toString());
          // تخزين المفتاح محلياً.
          await dbHelper.storeKeysLocally(
            senderUUID: receiverUUID, // لاحظ التبديل
            senderNUM: keyInfo.senderNUM,
            receiverUUID: senderUUID,
            receiverNUM: keyInfo.receiverNUM,
            sharedSecret: secret,
          );
          return secret;
        } else {
          print("API لم تُرجع بيانات بالترتيب المعكوس.");
          return null;
        }
      }
      throw Exception('فشل في الحصول على المفاتيح بعد المحاولات: ${response.statusCode}');
    } on http.ClientException catch (e) {
      throw Exception('فشل الاتصال: ${e.message}');
    } on TimeoutException {
      throw Exception('انتهى وقت الانتظار');
    } catch (e) {
      throw Exception('خطأ غير متوقع: $e');
    }
  }
  Message _convertSmsToMessage(SmsMessage sms, bool isMe) {
    final body = sms.body ?? "";
    final isEncrypted = body.startsWith('ENC:'); // تحديد بادئة خاصة
    final content = isEncrypted ? body.substring(4) : body;

    return Message(
      sender: sms.address ?? "Unknown",
      content: content,
      timestamp: DateTime.fromMillisecondsSinceEpoch(sms.date ?? 0),
      isMe: isMe,
      isEncrypted: isEncrypted,
    );
  }

  Future<void> _insertConversationKey(ConversationKey key) async {
    await _keysDb?.insert(
      'conversation_keys',
      key.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
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

  Future<ConversationKey?> getConversationKey(String address) async {
    final keyPair = DiffieHellmanHelper.generateKeyPair();
    final ecPrivate = keyPair.privateKey as ECPrivateKey;
    final ecPublic = keyPair.publicKey as ECPublicKey;

    final ownPrivateKey = ecPrivate.d!.toRadixString(16); // تحويل الخاص إلى HEX
    final ownPublicKey = DiffieHellmanHelper.encodePublicKey(ecPublic);

    print("المفتاح العام المُنشأ: $ownPublicKey");
    print("طول المفتاح العام: ${ownPublicKey.length}"); // يجب أن يكون 130

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

    print("تم إنشاء زوج المفاتيح:");
    print("المفتاح العام: $recipient");
    print("المفتاح الخاص: $ownPrivateKey");

    ConversationKey newKey = ConversationKey(
      address: recipient,
      ownPrivateKey: ownPrivateKey,
      ownPublicKey: ownPublicKey,
      theirPublicKey: null,
      sharedSecret: null,
    );
    await _insertConversationKey(newKey);
  }
  String normalizePhoneNumber(String phoneNumber) {
    if (RegExp(r'[^0-9+]').hasMatch(phoneNumber)) {
      return phoneNumber;
    }

    // إذا كان النص رقمًا، قم بتطبيعه
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

  Map<String, List<SmsMessage>> _cachedConversations = {};

  Future<Map<String, List<SmsMessage>>> getConversations({bool forceRefresh = false}) async {
    // التأكد من صلاحية قراءة الرسائل
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
        // إذا كان العنوان يحتوي على أحرف يُعتبر نصي، وإلا نقوم بتطبيعه باستخدام normalizePhoneNumber.
        final isTextAddress = RegExp(r'[a-zA-Z]').hasMatch(rawAddress);
        final normalizedAddress = isTextAddress ? rawAddress : normalizePhoneNumber(rawAddress);
        groupedMessages.putIfAbsent(normalizedAddress, () => []);
        groupedMessages[normalizedAddress]!.add(message);
      }

      // تجميع الرسائل من الوارد والصادر
      for (var message in [...inbox, ...sent]) {
        groupMessages(message);
      }

      _cachedConversations = groupedMessages;
    }

    // إزالة أي محادثة لا تحتوي على رسائل
    return _cachedConversations..removeWhere((key, value) => value.isEmpty);
  }
}