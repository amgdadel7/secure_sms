// استيراد المكتبات اللازمة
import 'dart:async'; // للتعامل مع العمليات غير المتزامنة
import 'dart:convert'; // لتحويل النصوص إلى JSON والعكس
import 'package:flutter/material.dart'; // لإنشاء واجهات المستخدم
import 'package:flutter/services.dart'; // للتعامل مع الحافظة (Clipboard)
import 'package:pointycastle/ecc/api.dart'; // مكتبة للتشفير باستخدام Diffie-Hellman
import 'package:provider/provider.dart'; // لإدارة الحالة باستخدام Provider
import 'dart:ui' as ui; // للتعامل مع واجهات المستخدم
import 'package:telephony/telephony.dart'; // مكتبة للتعامل مع الرسائل النصية SMS
import 'package:untitled14/controllers/registration_controller.dart'; // وحدة التحكم بالتسجيل
import 'package:untitled14/controllers/store_key_controler.dart'; // وحدة التحكم بتخزين المفاتيح
import 'package:untitled14/utils/encryption.dart'; // أدوات التشفير
import '../controllers/message_controller.dart'; // وحدة التحكم بالرسائل
import '../models/message_model.dart'; // نموذج الرسائل
import 'package:http/http.dart' as http; // مكتبة لإجراء طلبات HTTP
import 'package:chat_bubbles/chat_bubbles.dart'; // مكتبة لإنشاء فقاعات الدردشة
import 'package:intl/intl.dart'; // مكتبة لتنسيق التاريخ والوقت
import 'package:url_launcher/url_launcher.dart'; // مكتبة لفتح الروابط والتطبيقات

// تعريف ألوان واجهة Google Messages
class GoogleMessagesColors {
  static const primary = Color(0xFF00897B); // اللون الأساسي
  static const primaryDark = Color(0xFF00796B); // اللون الأساسي الداكن
  static const accent = Color(0xFF80CBC4); // اللون الثانوي
  static const background = Color(0xFFEEEEEE); // لون الخلفية
  static const sentMessage = Color(0xFFDCF8C6); // لون الرسائل المرسلة
  static const receivedMessage = Colors.white; // لون الرسائل المستلمة
  static const textDark = Color(0xFF212121); // لون النص الداكن
  static const textLight = Color(0xFF757575); // لون النص الفاتح
  static const timeStamp = Color(0xFF9E9E9E); // لون الطابع الزمني
  static const appBar = Colors.white; // لون شريط التطبيق
  static const divider = Color(0xFFE0E0E0); // لون الفاصل
  static const unreadIndicator = Color(0xFF4CAF50); // لون مؤشر الرسائل غير المقروءة
}

// دالة تستدعي عند استقبال رسالة في الخلفية
onBackgroundMessage(SmsMessage message) {
  debugPrint("onBackgroundMessage called"); // طباعة رسالة عند استقبال رسالة في الخلفية
}

// تعريف واجهة الدردشة
class ChatScreen extends StatefulWidget {
  final String address; // عنوان المحادثة (مثل رقم الهاتف)
  final String recipient; // اسم المستلم
  final String? recipientImageUrl; // صورة المستلم (اختياري)
  final String? searchQuery; // استعلام البحث (اختياري)

  const ChatScreen({
    Key? key,
    required this.address, // عنوان المحادثة
    required this.recipient, // اسم المستلم
    this.recipientImageUrl, // صورة المستلم
    this.searchQuery, // استعلام البحث
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState(); // إنشاء الحالة
}

// تعريف حالة واجهة الدردشة
class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController(); // وحدة التحكم بحقل إدخال الرسائل
  final ScrollController _scrollController = ScrollController(); // وحدة التحكم بالتمرير
  final MessageController mess = MessageController(); // وحدة التحكم بالرسائل
  List<Message> _messages = []; // قائمة الرسائل
  String _message = ""; // الرسالة الحالية
  final telephony = Telephony.instance; // تهيئة مكتبة الرسائل النصية
  bool _isSelectionMode = false; // وضع التحديد
  Set<int> _selectedMessageIndices = {}; // الرسائل المحددة
  bool _isSearchMode = false; // وضع البحث
  String _searchQuery = ''; // استعلام البحث
  List<int> _searchResults = []; // نتائج البحث
  int _currentSearchIndex = -1; // مؤشر البحث الحالي
  final FocusNode _searchFocusNode = FocusNode(); // وحدة التحكم بالتركيز على البحث
  final TextEditingController _searchController = TextEditingController(); // وحدة التحكم بحقل البحث
  bool _loadingMessages = true; // حالة تحميل الرسائل
  late Timer _timer; // مؤقت

  @override
  void initState() {
    super.initState();
    _loadMessages(); // تحميل الرسائل
    initPlatformState(); // طلب الصلاحيات
    WidgetsBinding.instance?.addPostFrameCallback((_) async {
      final messageController = Provider.of<MessageController>(context, listen: false);
      await messageController.initDatabases(); // تهيئة قاعدة البيانات
      messageController.printMessages(); // طباعة الرسائل
      messageController.printConversationKeys(); // طباعة مفاتيح المحادثة
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        _isSearchMode = true; // تفعيل وضع البحث
        _searchController.text = widget.searchQuery!;
      }
    });

    // إذا كانت القائمة جاهزة لنقل المؤشر إلى آخر الرسائل.
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  @override
  void dispose() {
    _timer.cancel(); // إلغاء المؤقت
    _searchFocusNode.dispose(); // التخلص من وحدة التحكم بالتركيز
    _searchController.dispose(); // التخلص من وحدة التحكم بحقل البحث
    super.dispose();
  }

  // دالة تستدعي عند استقبال رسالة جديدة
  onMessage(SmsMessage message) async {
    setState(() {
      _senderNumber = message.address ?? "Unknown"; // حفظ رقم المرسل
      _message = message.body ?? ""; // حفظ محتوى الرسالة
      print("🚀 تم استلام رسالة من $_senderNumber: $_message");
      _loadMessages(); // إعادة تحميل الرسائل
      mess.processIncomingSms(message); // معالجة الرسالة الواردة
    });
  }

  // دالة لتنفيذ البحث في الرسائل
  void _performSearch(String query) {
    final lowerQuery = query.toLowerCase(); // تحويل النص إلى أحرف صغيرة
    List<int> results = [];
    for (int i = 0; i < _messages.length; i++) {
      if (_messages[i].content.toLowerCase().contains(lowerQuery)) {
        results.add(i); // إضافة الرسائل المطابقة إلى النتائج
      }
    }
    setState(() {
      _searchQuery = query; // تحديث استعلام البحث
      _searchResults = results; // تحديث نتائج البحث
      _currentSearchIndex = results.isNotEmpty ? 0 : -1; // تعيين المؤشر الحالي
    });
    if (results.isNotEmpty) {
      _jumpToResult(_currentSearchIndex); // الانتقال إلى النتيجة الأولى
    }
  }

  // دالة للانتقال إلى نتيجة البحث المحددة
  void _jumpToResult(int index) {
    if (index >= 0 && index < _searchResults.length) {
      setState(() => _currentSearchIndex = index); // تحديث المؤشر الحالي
      final messageIndex = _searchResults[index];
      WidgetsBinding.instance?.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(
            _scrollController.position.maxScrollExtent *
                (messageIndex / _messages.length), // الانتقال إلى الرسالة
          );
        }
      });
    }
  }

    // دالة للانتقال إلى النتيجة السابقة في البحث
  void _jumpToPreviousResult() {
    if (_currentSearchIndex > 0) {
      _jumpToResult(_currentSearchIndex - 1); // الانتقال إلى النتيجة السابقة
    }
  }
  
  // دالة للانتقال إلى النتيجة التالية في البحث
  void _jumpToNextResult() {
    if (_currentSearchIndex < _searchResults.length - 1) {
      _jumpToResult(_currentSearchIndex + 1); // الانتقال إلى النتيجة التالية
    }
  }
  
  // دالة لتبديل وضع البحث
  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode; // تبديل حالة البحث
      if (!_isSearchMode) {
        _searchQuery = ''; // إعادة تعيين استعلام البحث
        _searchResults.clear(); // مسح نتائج البحث
        _currentSearchIndex = -1; // إعادة تعيين المؤشر الحالي
      }
    });
  }
  
  // طلب صلاحيات الهاتف والرسائل والاستماع للرسائل الواردة
  Future<void> initPlatformState() async {
    bool? result = await telephony.requestPhoneAndSmsPermissions; // طلب الصلاحيات
    if (result != null && result) {
      telephony.listenIncomingSms(
        onNewMessage: onMessage, // استدعاء دالة عند استقبال رسالة جديدة
        onBackgroundMessage: onBackgroundMessage, // استدعاء دالة عند استقبال رسالة في الخلفية
        listenInBackground: true, // تمكين الاستماع في الخلفية
      );
    }
  
    if (!mounted) return; // التحقق من أن الواجهة لا تزال موجودة
  }
  
  // دالة لتحميل الرسائل
  Future<void> _loadMessages() async {
    final messageController = Provider.of<MessageController>(context, listen: false);
    List<Message> msgs = await messageController.getMessagesForThread(widget.address); // جلب الرسائل
    msgs.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // ترتيب الرسائل حسب الوقت
    setState(() {
      _messages = msgs; // تحديث قائمة الرسائل
      _loadingMessages = false; // إيقاف حالة التحميل
    });
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent); // الانتقال إلى آخر الرسائل
      }
      // تفعيل البحث إذا كان هناك استعلام
      if (widget.searchQuery != null && widget.searchQuery!.isNotEmpty) {
        _isSearchMode = true;
        _searchQuery = widget.searchQuery!;
        _searchController.text = _searchQuery;
        _performSearch(_searchQuery); // تنفيذ البحث
      }
    });
  }
  
  // تفعيل وضع التحديد عند الضغط المطول على رسالة
  void _onLongPressMessage(int index) {
    setState(() {
      _isSelectionMode = true; // تفعيل وضع التحديد
      _selectedMessageIndices.add(index); // إضافة الرسالة المحددة
    });
  }
  
  // عند النقر على الرسالة في وضع التحديد، يتم تبديل اختيارها
  void _onTapMessage(int index) {
    if (_isSelectionMode) {
      setState(() {
        if (_selectedMessageIndices.contains(index)) {
          _selectedMessageIndices.remove(index); // إزالة الرسالة من التحديد
          if (_selectedMessageIndices.isEmpty) {
            _isSelectionMode = false; // إلغاء وضع التحديد إذا لم تكن هناك رسائل محددة
          }
        } else {
          _selectedMessageIndices.add(index); // إضافة الرسالة إلى التحديد
        }
      });
    }
  }
  
  // دالة لنسخ الرسائل المحددة
  void _copySelectedMessages() {
    String copiedText = _selectedMessageIndices
        .map((index) => _messages[index].content) // جلب محتوى الرسائل المحددة
        .join("\n"); // دمج الرسائل في نص واحد
    Clipboard.setData(ClipboardData(text: copiedText)); // نسخ النص إلى الحافظة
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم نسخ الرسائل")), // عرض رسالة تأكيد النسخ
    );
    _exitSelectionMode(); // الخروج من وضع التحديد
  }
  
  // دالة لحذف الرسائل المحددة
  void _deleteSelectedMessages() {
    setState(() {
      // حذف الرسائل من القائمة المحلية (يمكن تعديلها لحذفها من قاعدة البيانات أيضاً)
      List<int> indices = _selectedMessageIndices.toList()..sort((a, b) => b.compareTo(a)); // ترتيب الرسائل
      for (var index in indices) {
        _messages.removeAt(index); // حذف الرسالة
      }
      _exitSelectionMode(); // الخروج من وضع التحديد
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("تم حذف الرسائل")), // عرض رسالة تأكيد الحذف
    );
  }
  
  // الخروج من وضع التحديد
  void _exitSelectionMode() {
    setState(() {
      _isSelectionMode = false; // إلغاء وضع التحديد
      _selectedMessageIndices.clear(); // مسح الرسائل المحددة
    });
  }
  
  // دالة للبحث عن UUID الجهاز باستخدام API
  Future<String?> findDeviceUuid(String searchValue) async {
    try {
      final response = await http.post(
        Uri.parse('https://political-thoracic-spatula.glitch.me/api/find-device'), // عنوان API
        headers: {'Content-Type': 'application/json'}, // تحديد نوع المحتوى
        body: jsonEncode({'searchValue': searchValue}), // إرسال القيمة للبحث
      );
  
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body); // فك تشفير الاستجابة
        String receverUUID = data['uuid'] as String; // استخراج UUID
        print('UUID2: $receverUUID'); // طباعة UUID
        return receverUUID; // إرجاع UUID
      } else {
        print('فشل البحث: ${response.statusCode}'); // طباعة رسالة خطأ
        return null;
      }
    } catch (e) {
      print('خطأ في الاتصال: $e'); // طباعة رسالة خطأ في الاتصال
      return null;
    }
  }
  
  // دالة للحصول على وطباعة UUID الجهاز
  Future<dynamic> getAndPrintUuid() async {
    final LocalDatabaseService localDatabaseService = LocalDatabaseService(); // تهيئة خدمة قاعدة البيانات المحلية
    final deviceInfo = await localDatabaseService.getDeviceInfo(); // جلب معلومات الجهاز
  
    if (deviceInfo != null) {
      final senderUUID = deviceInfo['uuid']!; // استخراج UUID
      final senderNUM = deviceInfo['phone_num']!; // استخراج رقم الهاتف
      print('UUID: $senderUUID'); // طباعة UUID
      print('Phone Number: $senderNUM'); // طباعة رقم الهاتف
      return deviceInfo; // إرجاع معلومات الجهاز
    } else {
      print('لا توجد معلومات جهاز محفوظة محلياً'); // طباعة رسالة في حالة عدم وجود بيانات
    }
  }

    // دالة للحصول على آخر 9 أرقام من العنوان (مثل رقم الهاتف)
  String getLastNineDigits(String address) {
    // إزالة أي مسافات أو أحرف غير رقمية
    String digits = address.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 9) {
      return digits.substring(digits.length - 9); // إرجاع آخر 9 أرقام
    }
    return digits; // إذا كان الرقم أقل من 9 أرقام، يتم إرجاعه كما هو
  }
  
  // دالة لإرسال الرسالة
  Future<void> _sendMessage() async {
    final messageController = Provider.of<MessageController>(context, listen: false); // الحصول على وحدة التحكم بالرسائل
    final text = _messageController.text.trim(); // جلب النص المدخل وإزالة المسافات الزائدة
    if (text.isEmpty) return; // إذا كان النص فارغاً، يتم إيقاف التنفيذ
  
    try {
      final address = widget.address; // جلب عنوان المحادثة
      final lastNine = getLastNineDigits(address); // استخراج آخر 9 أرقام من العنوان
  
      // الحصول على معرّفات الجهاز: senderUUID, senderNUM, receiverUUID
      final deviceIds = await _getDeviceIds(lastNine);
      final senderUUID = deviceIds['senderUUID']!; // UUID الخاص بالمرسل
      final senderNUM = deviceIds['senderNUM']!; // رقم الهاتف الخاص بالمرسل
      final receiverUUID = deviceIds['receiverUUID']!; // UUID الخاص بالمستلم
  
      // تجهيز مفتاح التشفير (shared secret)
      final secret = await _prepareSharedKey(senderUUID, senderNUM, receiverUUID, lastNine);
  
      // تشفير الرسالة باستخدام المفتاح المشترك وإرسالها
      await _processAndSendMessage(
        text,
        secret,
        messageController,
        widget.address,
      );
  
      // تحديث واجهة المستخدم (إضافة الرسالة الجديدة إلى القائمة وتحديث التمرير)
      _updateUIWithNewMessage(widget.address, text);
  
      _messageController.clear(); // مسح النص المدخل
      _scrollToBottom(); // التمرير إلى أسفل القائمة
    } catch (e) {
      // في حالة حدوث خطأ، يتم طباعة رسالة الخطأ وعرض رسالة للمستخدم
      print('خطأ غير متوقع: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء إرسال الرسالة: ${e.toString()}')),
      );
    }
  }
  
  // دالة للحصول على معرّفات الجهاز (sender و receiver)
  Future<Map<String, String>> _getDeviceIds(String lastNine) async {
    // الحصول على معرّف الجهاز ورقم الهاتف الخاص بالمرسل
    final senderData = await getAndPrintUuid();
    if (senderData == null || senderData['uuid'] == null || senderData['phone_num'] == null) {
      throw Exception('فشل في استرجاع UUID أو رقم الهاتف');
    }
  
    // البحث عن receiverUUID في قاعدة البيانات
    final dbHelper = DatabaseHelper();
    String? receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
      senderNUM: senderData['phone_num']!,
      receiverNUM: lastNine,
    );
  
    // إذا لم يتم العثور على UUID، يتم البحث بطريقة بديلة
    if (receiverUUID == null) {
      receiverUUID = await dbHelper.queryreceiverUUID_by_serderUUID(
        senderNUM: lastNine,
        receiverNUM: senderData['phone_num']!,
      );
    }
  
    // إذا لم يتم العثور على UUID، يتم البحث باستخدام الخادم
    if (receiverUUID == null) {
      receiverUUID = await findDeviceUuid(lastNine);
      if (receiverUUID == null) {
        throw Exception('فشل العثور على UUID بعد البحث');
      }
    }
  
    return {
      'senderUUID': senderData['uuid'], // UUID الخاص بالمرسل
      'senderNUM': senderData['phone_num'], // رقم الهاتف الخاص بالمرسل
      'receiverUUID': receiverUUID, // UUID الخاص بالمستلم
    };
  }
  
  // دالة لإعداد مفتاح التشفير (المفتاح المشترك) سواء عبر الاستعلام المحلي أو عبر تبادل المفاتيح مع الخادم
  Future<BigInt> _prepareSharedKey(
    String senderUUID,
    String senderNUM,
    String receiverUUID,
    String lastNine,
  ) async {
    final dbHelper = DatabaseHelper();
  
    // محاولة الحصول على المفتاح المشترك محلياً
    String? key = await dbHelper.queryKeysLocally(
      senderUUID: senderUUID,
      receiverNUM: lastNine,
    );
  
    // إذا لم يتم العثور على المفتاح محلياً، يتم البحث بطريقة بديلة
    if (key == null || key.isEmpty) {
      key = await dbHelper.queryKeysLocally1(
        senderNUM: lastNine,
        receiverNUM: senderNUM,
      );
    }
  
    // إذا لم يتم العثور على المفتاح، يتم توليد مفتاح جديد وتبادل المفاتيح مع الخادم
    if (key == null || key.isEmpty) {
      final messageController = Provider.of<MessageController>(context, listen: false);
      final keys = await messageController.getConversationKey(widget.address);
      if (keys == null || keys.ownPublicKey.isEmpty || keys.ownPrivateKey.isEmpty) {
        throw Exception('فشل في توليد مفاتيح التشفير');
      }
  
      // تبادل المفاتيح مع الخادم
      await _exchangeKeysWithServer(senderUUID, receiverUUID, keys, widget.address);
  
      // توليد زوج المفاتيح وحساب السر المشترك
      final keyPair = DiffieHellmanHelper.generateKeyPair();
      final myPrivateKey = keyPair.privateKey as ECPrivateKey;
      final peerPublicKey = keyPair.publicKey as ECPublicKey;
      final sharedSecret = DiffieHellmanHelper.computeSharedSecret(myPrivateKey, peerPublicKey);
  
      // تخزين المفتاح محلياً وفي الخادم
      await dbHelper.storeKeysLocally(
        senderUUID: senderUUID,
        senderNUM: senderNUM,
        receiverUUID: receiverUUID,
        receiverNUM: lastNine,
        sharedSecret: sharedSecret,
      );
      await _storeKeysToServer(senderUUID, senderNUM, receiverUUID, lastNine, sharedSecret);
  
      return BigInt.parse(sharedSecret.toString()); // إرجاع المفتاح المشترك
    } else {
      // إذا كان المفتاح موجوداً محلياً، يتم استخدامه
      return BigInt.parse(key);
    }
  }

   /// دالة لتبادل المفاتيح مع الخادم والحصول على المفتاح العام الخاص بالجهة المستلمة
  Future<void> _exchangeKeysWithServer(
    String senderUUID, // UUID الخاص بالمرسل
    String receiverUUID, // UUID الخاص بالمستلم
    dynamic keys, // مفاتيح المرسل (العامة والخاصة)
    String targetPhone, // رقم الهاتف الخاص بالمستلم
  ) async {
    // إرسال طلب POST إلى الخادم لتبادل المفاتيح
    final response = await http.post(
      Uri.parse('https://political-thoracic-spatula.glitch.me/api/exchange-keys'), // عنوان API
      headers: {'Content-Type': 'application/json'}, // تحديد نوع المحتوى
      body: jsonEncode({
        'senderUUID': senderUUID, // UUID الخاص بالمرسل
        'receiverUUID': receiverUUID, // UUID الخاص بالمستلم
        'senderPublicKey': keys.ownPublicKey, // المفتاح العام للمرسل
        'targetPhone': targetPhone, // رقم الهاتف الخاص بالمستلم
      }),
    ).timeout(const Duration(seconds: 10)); // تحديد مهلة الطلب
  
    // التحقق من نجاح الطلب
    if (response.statusCode != 200) {
      print('فشل تبادل المفاتيح. رمز الحالة: ${response.statusCode}');
      print('رد الخادم: ${response.body}');
      throw Exception('فشل تبادل المفاتيح مع الخادم');
    }
  
    // فك تشفير استجابة الخادم
    final exchangeData = jsonDecode(response.body);
    if (exchangeData['targetPublicKey'] == null) {
      throw Exception('لم يتم استلام المفتاح العام من الخادم');
    }
  }
  
  /// دالة لتخزين المفاتيح على الخادم
  Future<void> _storeKeysToServer(
    String senderUUID, // UUID الخاص بالمرسل
    String senderNUM, // رقم الهاتف الخاص بالمرسل
    String receiverUUID, // UUID الخاص بالمستلم
    String receiverNUM, // رقم الهاتف الخاص بالمستلم
    dynamic sharedSecret, // المفتاح المشترك
  ) async {
    // إرسال طلب POST إلى الخادم لتخزين المفاتيح
    final storeResponse = await http.post(
      Uri.parse('https://political-thoracic-spatula.glitch.me/api/store-keys'), // عنوان API
      headers: {'Content-Type': 'application/json'}, // تحديد نوع المحتوى
      body: jsonEncode({
        'senderUUID': senderUUID, // UUID الخاص بالمرسل
        'senderNUM': senderNUM, // رقم الهاتف الخاص بالمرسل
        'receiverUUID': receiverUUID, // UUID الخاص بالمستلم
        'receiverNUM': receiverNUM, // رقم الهاتف الخاص بالمستلم
        'sharedSecret': sharedSecret.toString(), // المفتاح المشترك
      }),
    ).timeout(const Duration(seconds: 10)); // تحديد مهلة الطلب
  
    // التحقق من نجاح الطلب
    if (storeResponse.statusCode != 200) {
      print('فشل حفظ المفاتيح. رمز الحالة: ${storeResponse.statusCode}');
      print('رد الخادم: ${storeResponse.body}');
      throw Exception('فشل تبادل المفاتيح مع الخادم');
    }
  
    // فك تشفير استجابة الخادم
    final storeData = jsonDecode(storeResponse.body);
    if (storeData['success'] != true) {
      throw Exception('فشل في تخزين المفاتيح على الخادم');
    }
  }
  
  /// دالة لتشفير الرسالة وإرسالها عبر SMS وتسجيلها
  Future<void> _processAndSendMessage(
    String plainText, // النص الأصلي للرسالة
    BigInt secret, // المفتاح المشترك
    MessageController messageController, // وحدة التحكم بالرسائل
    String address, // عنوان المحادثة (مثل رقم الهاتف)
  ) async {
    // تشفير الرسالة باستخدام المفتاح المشترك
    final encryptedMessage = DiffieHellmanHelper.encryptMessage(plainText, secret);
  
    // إرسال الرسالة المشفرة وتسجيلها
    await messageController.sendEncryptedMessage(encryptedMessage, plainText, address);
  }
  
  /// دالة لتحديث واجهة المستخدم بإضافة الرسالة الجديدة
  void _updateUIWithNewMessage(String address, String content) async {
    // إنشاء كائن الرسالة الجديدة
    Message newMessage = Message(
      sender: address, // عنوان المرسل
      content: content, // محتوى الرسالة
      timestamp: DateTime.now(), // الوقت الحالي
      isMe: true, // الإشارة إلى أن الرسالة مرسلة من المستخدم
      isEncrypted: true, // الإشارة إلى أن الرسالة مشفرة
    );
  
    // تحديث واجهة المستخدم
    setState(() {
      _messages.add(newMessage); // إضافة الرسالة إلى القائمة
      _messages.sort((a, b) => a.timestamp.compareTo(b.timestamp)); // ترتيب الرسائل حسب الوقت
    });
  }
  
  /// دالة لتحريك الـ Scroll إلى نهاية القائمة
  void _scrollToBottom() {
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent); // التمرير إلى الأسفل
      }
    });
  }
  
  /// دالة لإجراء مكالمة هاتفية
  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber); // إنشاء URI للمكالمة
    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(phoneUri); // فتح تطبيق الهاتف
      } else {
        throw 'تعذر فتح تطبيق الهاتف';
      }
    } catch (e) {
      // عرض رسالة خطأ في حالة الفشل
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ في الاتصال: $e')),
      );
    }
  }
  
  // دالة مقارنة بين تاريخين للتحقق إذا كانا في نفس اليوم
  bool _isSameDate(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day; // التحقق من تطابق السنة والشهر واليوم
  }
  
  // دالة تنسيق عنوان التاريخ والوقت (مثل: Today • 03:15 PM)
  String _formatDateHeader(DateTime dateTime) {
    final now = DateTime.now(); // الوقت الحالي
    if (_isSameDate(dateTime, now)) {
      return "Today • ${DateFormat('hh:mm a').format(dateTime)}"; // إذا كان التاريخ اليوم
    } else if (_isSameDate(dateTime, now.subtract(Duration(days: 1)))) {
      return "Yesterday • ${DateFormat('hh:mm a').format(dateTime)}"; // إذا كان التاريخ أمس
    } else {
      return "${DateFormat('dd MMM yyyy').format(dateTime)} • ${DateFormat('hh:mm a').format(dateTime)}"; // تنسيق التاريخ لباقي الأيام
    }
  }
  
  // ويدجت لبناء رأس التاريخ
  Widget _buildDateHeader(DateTime dateTime) {
    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 8), // إضافة مسافة عمودية
        child: Text(
          _formatDateHeader(dateTime), // تنسيق التاريخ
          style: TextStyle(
            fontSize: 13, // حجم النص
            color: Colors.grey, // لون النص
            fontWeight: FontWeight.bold, // جعل النص عريضاً
          ),
        ),
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    // بناء واجهة المستخدم الرئيسية
    return Scaffold(
      backgroundColor: GoogleMessagesColors.background, // تحديد لون الخلفية
      appBar: AppBar(
        backgroundColor: GoogleMessagesColors.appBar, // تحديد لون شريط التطبيق
        title: _buildAppBarTitle(), // بناء عنوان شريط التطبيق
        leading: _isSelectionMode // إذا كان وضع التحديد مفعلاً
            ? IconButton(
                icon: Icon(Icons.close, color: GoogleMessagesColors.textDark), // زر إغلاق وضع التحديد
                onPressed: _exitSelectionMode, // الخروج من وضع التحديد
              )
            : null, // إذا لم يكن وضع التحديد مفعلاً، لا يتم عرض أيقونة
        actions: _buildAppBarActions(), // بناء أزرار شريط التطبيق
        elevation: 1, // تحديد ارتفاع الظل لشريط التطبيق
        iconTheme: IconThemeData(color: GoogleMessagesColors.textDark), // تحديد لون الأيقونات
      ),
      body: Column(
        children: [
          if (_isSearchMode && _searchResults.isNotEmpty) // إذا كان وضع البحث مفعلاً وهناك نتائج
            _buildSearchHeader(), // بناء شريط البحث
          Expanded(
            child: _loadingMessages // إذا كانت الرسائل قيد التحميل
                ? Center(child: CircularProgressIndicator()) // عرض مؤشر التحميل
                : ListView.builder(
                    controller: _scrollController, // وحدة التحكم بالتمرير
                    itemCount: _messages.length, // عدد الرسائل
                    itemBuilder: (context, index) {
                      final message = _messages[index]; // الرسالة الحالية
  
                      // التحقق مما إذا كان يجب عرض رأس التاريخ
                      bool showHeader = false;
                      if (index == 0) {
                        showHeader = true; // عرض رأس التاريخ للرسالة الأولى
                      } else {
                        final prevMessage = _messages[index - 1]; // الرسالة السابقة
                        if (!_isSameDate(message.timestamp, prevMessage.timestamp))
                          showHeader = true; // عرض رأس التاريخ إذا كان التاريخ مختلفاً
                      }
  
                      return Column(
                        children: [
                          if (showHeader) _buildDateHeader(message.timestamp), // بناء رأس التاريخ إذا لزم الأمر
                          _buildMessageItem(index, message), // بناء عنصر الرسالة
                        ],
                      );
                    },
                  ),
          ),
          _buildMessageInput(), // بناء حقل إدخال الرسائل
        ],
      ),
    );
  }
  
  // دالة لبناء عنوان شريط التطبيق
  Widget _buildAppBarTitle() {
    if (_isSelectionMode) { // إذا كان وضع التحديد مفعلاً
      return Text(
        "${_selectedMessageIndices.length} محادثات مختارة", // عرض عدد الرسائل المحددة
        style: TextStyle(
          color: GoogleMessagesColors.textDark, // لون النص
          fontSize: 18, // حجم النص
        ),
      );
    }
    if (_isSearchMode) { // إذا كان وضع البحث مفعلاً
      return TextField(
        controller: _searchController, // وحدة التحكم بحقل البحث
        focusNode: _searchFocusNode, // وحدة التحكم بالتركيز
        decoration: InputDecoration(
          hintText: "ابحث في المحادثة...", // نص الإرشاد
          border: InputBorder.none, // إزالة الإطار
          hintStyle: TextStyle(color: GoogleMessagesColors.textLight), // لون نص الإرشاد
        ),
        style: TextStyle(color: GoogleMessagesColors.textDark), // لون النص المدخل
        onChanged: _performSearch, // تنفيذ البحث عند تغيير النص
      );
    }
    return Row(
      children: [
        CircleAvatar(
          radius: 20, // نصف قطر الصورة
          backgroundColor: GoogleMessagesColors.primary.withOpacity(0.1), // لون الخلفية
          backgroundImage: widget.recipientImageUrl != null
              ? NetworkImage(widget.recipientImageUrl!) // تحميل الصورة من الإنترنت إذا كانت موجودة
              : null,
          child: widget.recipientImageUrl == null // إذا لم تكن هناك صورة
              ? Text(
                  widget.recipient.isNotEmpty
                      ? widget.recipient[0].toUpperCase() // عرض الحرف الأول من اسم المستلم
                      : '?', // عرض علامة استفهام إذا كان الاسم فارغاً
                  style: TextStyle(
                    color: GoogleMessagesColors.primary, // لون النص
                    fontSize: 18, // حجم النص
                  ),
                )
              : null,
        ),
        SizedBox(width: 12), // إضافة مسافة أفقية
        Expanded(
          child: Row(
            mainAxisSize: MainAxisSize.min, // تقليل حجم الصف إلى الحد الأدنى
            children: [
              Expanded(
                child: Text(
                  widget.recipient, // اسم المستلم
                  style: TextStyle(
                    color: GoogleMessagesColors.textDark, // لون النص
                    fontSize: 18, // حجم النص
                    fontWeight: FontWeight.w500, // وزن النص
                  ),
                  overflow: TextOverflow.ellipsis, // اقتصاص النص إذا كان طويلاً
                ),
              ),
              Padding(
                padding: EdgeInsets.only(left: 8), // إضافة مسافة يسار
                child: IconButton(
                  icon: Icon(
                    Icons.call, // أيقونة الاتصال
                    size: 24, // حجم الأيقونة
                    color: GoogleMessagesColors.primary, // لون الأيقونة
                  ),
                  onPressed: () => _makePhoneCall(widget.address), // إجراء مكالمة عند الضغط
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
   // دالة لبناء أزرار شريط التطبيق
  List<Widget>? _buildAppBarActions() {
    if (_isSearchMode) return null; // إذا كان وضع البحث مفعلاً، لا يتم عرض أي أزرار
  
    if (_isSelectionMode) { // إذا كان وضع التحديد مفعلاً
      return [
        IconButton(
          icon: Icon(Icons.copy, color: GoogleMessagesColors.textDark), // زر نسخ الرسائل
          onPressed: _copySelectedMessages, // استدعاء دالة نسخ الرسائل المحددة
        ),
        IconButton(
          icon: Icon(Icons.delete, color: GoogleMessagesColors.textDark), // زر حذف الرسائل
          onPressed: _deleteSelectedMessages, // استدعاء دالة حذف الرسائل المحددة
        ),
      ];
    }
  
    // إذا لم يكن أي وضع مفعلاً، يتم عرض زر البحث
    return [
      IconButton(
        icon: Icon(Icons.search, color: GoogleMessagesColors.textDark), // زر البحث
        onPressed: _toggleSearchMode, // استدعاء دالة تبديل وضع البحث
      ),
    ];
  }
  
  // دالة لبناء شريط البحث
  Widget _buildSearchHeader() {
    return Container(
      color: GoogleMessagesColors.appBar, // لون الخلفية
      padding: EdgeInsets.symmetric(vertical: 8), // إضافة مسافة عمودية
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center, // محاذاة العناصر في المنتصف
        children: [
          IconButton(
            icon: Icon(Icons.arrow_upward, color: GoogleMessagesColors.primary), // زر الانتقال إلى النتيجة السابقة
            onPressed: _jumpToPreviousResult, // استدعاء دالة الانتقال إلى النتيجة السابقة
          ),
          Text(
            '${_currentSearchIndex + 1} من ${_searchResults.length}', // عرض رقم النتيجة الحالية من إجمالي النتائج
            style: TextStyle(
              color: GoogleMessagesColors.textDark, // لون النص
              fontSize: 16, // حجم النص
            ),
            textDirection: ui.TextDirection.rtl, // اتجاه النص من اليمين إلى اليسار
            textAlign: TextAlign.right, // محاذاة النص إلى اليمين
          ),
          IconButton(
            icon: Icon(Icons.arrow_downward, color: GoogleMessagesColors.primary), // زر الانتقال إلى النتيجة التالية
            onPressed: _jumpToNextResult, // استدعاء دالة الانتقال إلى النتيجة التالية
          ),
        ],
      ),
    );
  }
  
  // دالة لبناء عنصر الرسالة
  Widget _buildMessageItem(int index, Message message) {
    final bool isMe = message.isMe; // التحقق إذا كانت الرسالة مرسلة من المستخدم
    final bool isSelected = _selectedMessageIndices.contains(index); // التحقق إذا كانت الرسالة محددة
    final bool isSearchResult = _searchResults.contains(index) &&
        index == _searchResults[_currentSearchIndex]; // التحقق إذا كانت الرسالة نتيجة بحث
  
    return GestureDetector(
      onLongPress: () => _onLongPressMessage(index), // استدعاء دالة الضغط المطول لتفعيل وضع التحديد
      onTap: () => _onTapMessage(index), // استدعاء دالة النقر لتبديل اختيار الرسالة
      child: Container(
        color: isSelected
            ? GoogleMessagesColors.accent.withOpacity(0.3) // لون الخلفية إذا كانت الرسالة محددة
            : isSearchResult
                ? GoogleMessagesColors.primary.withOpacity(0.1) // لون الخلفية إذا كانت نتيجة بحث
                : Colors.transparent, // لون الخلفية الافتراضي
        padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8), // إضافة مسافة داخلية
        child: Row(
          mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, // محاذاة الرسالة حسب المرسل
          children: [
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.8, // تحديد الحد الأقصى لعرض الرسالة
                ),
                decoration: BoxDecoration(
                  color: isMe
                      ? GoogleMessagesColors.sentMessage // لون الرسائل المرسلة
                      : GoogleMessagesColors.receivedMessage, // لون الرسائل المستلمة
                  borderRadius: BorderRadius.circular(12), // زوايا دائرية
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12, // لون الظل
                      blurRadius: 2, // درجة التمويه
                      offset: Offset(0, 1), // إزاحة الظل
                    )
                  ],
                ),
                padding: EdgeInsets.symmetric(
                  vertical: 10, // مسافة عمودية داخل الرسالة
                  horizontal: 14, // مسافة أفقية داخل الرسالة
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start, // محاذاة النصوص إلى اليسار
                  children: [
                    Text(
                      message.content, // محتوى الرسالة
                      style: TextStyle(
                        color: GoogleMessagesColors.textDark, // لون النص
                        fontSize: 16, // حجم النص
                      ),
                    ),
                    SizedBox(height: 4), // إضافة مسافة بين النصوص
                    Row(
                      mainAxisSize: MainAxisSize.min, // تقليل حجم الصف إلى الحد الأدنى
                      children: [
                        Text(
                          DateFormat('hh:mm a').format(message.timestamp), // تنسيق وعرض وقت الرسالة
                          style: TextStyle(
                            color: GoogleMessagesColors.timeStamp, // لون النص
                            fontSize: 12, // حجم النص
                          ),
                        ),
                        if (isMe && message.isEncrypted) // إذا كانت الرسالة مرسلة ومشفرة
                          Padding(
                            padding: EdgeInsets.only(left: 4), // إضافة مسافة يسار
                            child: Icon(
                              Icons.lock_outline, // أيقونة القفل
                              size: 12, // حجم الأيقونة
                              color: GoogleMessagesColors.timeStamp, // لون الأيقونة
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
   // دالة لبناء واجهة إدخال الرسائل
  Widget _buildMessageInput() {
    return Container(
      margin: EdgeInsets.all(8), // إضافة مسافة حول حقل الإدخال
      decoration: BoxDecoration(
        color: Colors.white, // لون خلفية حقل الإدخال
        borderRadius: BorderRadius.circular(24), // زوايا دائرية للحقل
        boxShadow: [
          BoxShadow(
            color: Colors.black12, // لون الظل
            blurRadius: 4, // درجة التمويه للظل
            offset: Offset(0, 2), // إزاحة الظل
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16), // إضافة مسافة أفقية داخل الحقل
              child: TextField(
                controller: _messageController, // وحدة التحكم بحقل النص
                decoration: InputDecoration(
                  hintText: "اكتب رسالة...", // نص الإرشاد داخل الحقل
                  border: InputBorder.none, // إزالة الإطار الافتراضي للحقل
                  hintStyle: TextStyle(
                    color: GoogleMessagesColors.textLight, // لون نص الإرشاد
                  ),
                ),
                style: TextStyle(
                  color: GoogleMessagesColors.textDark, // لون النص المدخل
                ),
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.send, color: GoogleMessagesColors.primary), // أيقونة الإرسال
            onPressed: _sendMessage, // استدعاء دالة إرسال الرسالة عند الضغط
          ),
        ],
      ),
    );
  }
