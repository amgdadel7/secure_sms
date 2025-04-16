// استيراد المكتبات اللازمة
import 'dart:async'; // للتعامل مع العمليات غير المتزامنة
import 'package:flutter/material.dart'; // لإنشاء واجهات المستخدم
import 'package:intl/intl.dart'; // لتنسيق التاريخ والوقت
import 'package:provider/provider.dart'; // لإدارة الحالة باستخدام Provider
import 'package:shimmer/shimmer.dart'; // لإنشاء تأثير الوميض (Shimmer)
import 'package:telephony/telephony.dart'; // للتعامل مع الرسائل النصية SMS
import 'package:fast_contacts/fast_contacts.dart'; // للوصول إلى جهات الاتصال
import 'package:permission_handler/permission_handler.dart'; // لإدارة الأذونات
import 'package:badges/badges.dart' as badges; // لإضافة شارات (Badges)
import '../controllers/message_controller.dart'; // وحدة التحكم بالرسائل
import 'chat_screen.dart'; // شاشة المحادثة
import 'new_message_screen.dart'; // شاشة الرسائل الجديدة

// دالة تُستدعى عند استقبال رسالة في الخلفية
onBackgroundMessage(SmsMessage message) {
  debugPrint("onBackgroundMessage called"); // طباعة رسالة عند استقبال رسالة في الخلفية
}

// تعريف واجهة شاشة المحادثات
class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  _ConversationsScreenState createState() => _ConversationsScreenState();
}

// تعريف حالة شاشة المحادثات
class _ConversationsScreenState extends State<ConversationsScreen>
    with WidgetsBindingObserver {
  late Future<List<Contact>> _contactsFuture; // قائمة جهات الاتصال المستقبلية
  final Telephony _telephony = Telephony.instance; // تهيئة مكتبة الرسائل النصية
  Map<String, List<SmsMessage>> _conversations = {}; // قائمة المحادثات
  Map<String, int> _unreadCounts = {}; // عدد الرسائل غير المقروءة لكل محادثة
  String _message = ""; // الرسالة الحالية

  // متغيرات البحث
  bool _isSearching = false; // حالة البحث
  String _searchQuery = ""; // نص البحث الحالي

  // مراقبة حالة التطبيق (Foreground/Background)
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadConversations(); // إعادة تحميل المحادثات عند العودة إلى التطبيق
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance?.addObserver(this); // إضافة مراقب لحالة التطبيق
    _requestSmsPermission(); // طلب إذن الرسائل النصية
    _contactsFuture = FastContacts.getAllContacts(); // تحميل جهات الاتصال
    _loadConversations(); // تحميل المحادثات
    initPlatformState(); // تهيئة حالة المنصة
  }

  @override
  void dispose() {
    WidgetsBinding.instance?.removeObserver(this); // إزالة مراقب حالة التطبيق
    super.dispose();
  }

  // دالة تُستدعى عند استقبال رسالة جديدة
  onMessage(SmsMessage message) async {
    setState(() {
      _message = message.body ?? "Error reading message body."; // حفظ محتوى الرسالة
      print("🚀 تم استلام رسالة واردة: $_message");
    });
    final String address = message.address ?? 'Unknown'; // عنوان المرسل
    final String normalizedAddress = _normalizePhoneNumber(address); // تطبيع العنوان
    setState(() {
      _conversations.putIfAbsent(normalizedAddress, () => []); // إضافة المحادثة إذا لم تكن موجودة
      _conversations[normalizedAddress]!.add(message); // إضافة الرسالة إلى المحادثة
      _unreadCounts[normalizedAddress] =
          (_unreadCounts[normalizedAddress] ?? 0) + 1; // تحديث عدد الرسائل غير المقروءة
    });
    await _loadConversations(); // إعادة تحميل المحادثات
  }

  // تهيئة حالة المنصة وطلب الأذونات
  Future<void> initPlatformState() async {
    bool? result = await _telephony.requestPhoneAndSmsPermissions; // طلب أذونات الرسائل النصية
    if (result ?? false) {
      _telephony.listenIncomingSms(
        onNewMessage: onMessage, // استدعاء دالة عند استقبال رسالة جديدة
        onBackgroundMessage: onBackgroundMessage, // استدعاء دالة عند استقبال رسالة في الخلفية
        listenInBackground: true, // تمكين الاستماع في الخلفية
      );
      await _loadConversations(); // تحميل المحادثات
    } else {
      openAppSettings(); // فتح إعدادات التطبيق إذا لم تُمنح الأذونات
    }
  }

  // طلب إذن الرسائل النصية
  Future<void> _requestSmsPermission() async {
    await Permission.sms.request(); // طلب إذن الرسائل النصية
  }

  // تحميل المحادثات
  Future<void> _loadConversations() async {
    final messageController =
        Provider.of<MessageController>(context, listen: false); // الحصول على وحدة التحكم بالرسائل
    final conversations =
        await messageController.getConversations(forceRefresh: true); // جلب المحادثات
    // دمج المحادثات القديمة مع الجديدة
    final mergedConversations = {..._conversations, ...conversations};
    setState(() {
      _conversations = mergedConversations; // تحديث المحادثات
      _unreadCounts = {}; // إعادة تعيين عدد الرسائل غير المقروءة
      mergedConversations.forEach((address, messages) {
        final normalizedAddress =
            messageController.normalizePhoneNumber(address); // تطبيع العنوان
        final unread = messages.where((msg) => !(msg.read ?? true)).length; // حساب الرسائل غير المقروءة
        if (unread > 0) {
          _unreadCounts[normalizedAddress] = unread; // تحديث عدد الرسائل غير المقروءة
        }
      });
    });
  }

  // دالة لتطبيع أرقام الهاتف
  String _normalizePhoneNumber(String phoneNumber) {
    String normalized = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), ''); // إزالة الأحرف غير الرقمية

    // معالجة الأرقام الدولية
    if (normalized.startsWith('+')) {
      return normalized.substring(normalized.length - 9); // الاحتفاظ بآخر 9 أرقام
    }

    if (normalized.length >= 9) {
      return normalized.substring(normalized.length - 9); // الاحتفاظ بآخر 9 أرقام
    }
    print("Input: $phoneNumber, Output: ${normalized}");
    return normalized;
  }

  // التحقق إذا كان النص يحتوي على أحرف
  bool _containsLetters(String text) {
    return RegExp(r'[a-zA-Z]').hasMatch(text); // التحقق من وجود أحرف
  }

  // الحصول على اسم جهة الاتصال بناءً على العنوان
  String getContactName(String address, List<Contact> contacts) {
    if (_containsLetters(address)) {
      print("Jaib$address");
      return address; // إذا كان العنوان يحتوي على أحرف، عرضه كما هو
    }

    final normalizedAddress = _normalizePhoneNumber(address); // تطبيع العنوان

    if (normalizedAddress.length <= 7) {
      return address; // إذا كان الرقم قصير جدًا، عرضه كما هو
    }

    // البحث في جهات الاتصال
    for (var contact in contacts) {
      for (var phone in contact.phones) {
        String normalizedContact = _normalizePhoneNumber(phone.number); // تطبيع رقم الهاتف
        if (normalizedContact == normalizedAddress) {
          return contact.displayName.isNotEmpty
              ? contact.displayName // عرض اسم جهة الاتصال إذا كان موجودًا
              : address; // عرض العنوان إذا لم يكن هناك اسم
        }
      }
    }

    return address; // إرجاع العنوان الأصلي إذا لم يُعثر على تطابق
  }

  // تنسيق التاريخ حسب الشروط المطلوبة
  String _formatDate(int timestamp) {
    final now = DateTime.now(); // الوقت الحالي
    final date = DateTime.fromMillisecondsSinceEpoch(timestamp); // تحويل الطابع الزمني إلى تاريخ
    if (date.year == now.year && date.month == now.month) {
      return DateFormat('h:mm a').format(date); // تنسيق الوقت إذا كان في نفس الشهر
    } else if (date.year == now.year) {
      return DateFormat('MMM d').format(date); // تنسيق الشهر واليوم إذا كان في نفس السنة
    } else {
      return DateFormat('M/d/yy').format(date); // تنسيق التاريخ الكامل إذا كان في سنة مختلفة
    }
  }

  // الحصول على لون بناءً على الحرف الأول
  Color _getColorFromChar(String char) {
    final code = char.codeUnitAt(0); // الحصول على الكود الرقمي للحرف
    return Colors.primaries[code % Colors.primaries.length]; // اختيار لون بناءً على الكود
  }

  // تحديث استعلام البحث
  void _updateSearchQuery(String query) {
    setState(() {
      _searchQuery = query; // تحديث نص البحث
    });
  }

  // تصفية المحادثات بناءً على البحث
  List<String> _filterConversations(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return _conversations.keys.toList(); // إذا كان البحث فارغًا، عرض جميع المحادثات
    List<String> results = [];
    _conversations.forEach((key, messages) {
      final name = getContactName(key, contacts); // الحصول على اسم جهة الاتصال
      if (name.toLowerCase().contains(_searchQuery.toLowerCase())) {
        results.add(key); // إضافة المحادثة إذا تطابق الاسم مع البحث
      } else {
        bool found = messages.any((msg) =>
            (msg.body != null &&
                msg.body!.toLowerCase().contains(_searchQuery.toLowerCase()))); // التحقق من تطابق نص الرسالة
        if (found) results.add(key); // إضافة المحادثة إذا تطابق النص مع البحث
      }
    });
    return results;
  }

  // تصفية جهات الاتصال بناءً على البحث
  List<Contact> _filterContacts(List<Contact> contacts) {
    if (_searchQuery.isEmpty) return contacts; // إذا كان البحث فارغًا، عرض جميع جهات الاتصال
    return contacts
        .where((contact) => contact.displayName
            .toLowerCase()
            .contains(_searchQuery.toLowerCase())) // التحقق من تطابق الاسم مع البحث
        .toList();
  }

  // تمييز النص الذي يتطابق مع استعلام البحث
  Widget _buildHighlightedText(String text, String query) {
    if (query.isEmpty) return Text(text, style: TextStyle(color: Colors.grey[600])); // إذا كان البحث فارغًا، عرض النص كما هو
    List<TextSpan> spans = [];
    String lowerText = text.toLowerCase();
    String lowerQuery = query.toLowerCase();
    int start = 0;
    while (true) {
      int index = lowerText.indexOf(lowerQuery, start); // البحث عن النص المطابق
      if (index < 0) {
        spans.add(TextSpan(
            text: text.substring(start),
            style: TextStyle(color: Colors.grey[600]))); // إضافة النص المتبقي
        break;
      }
      if (index > start) {
        spans.add(TextSpan(
            text: text.substring(start, index),
            style: TextStyle(color: Colors.grey[600]))); // إضافة النص قبل المطابقة
      }
      spans.add(TextSpan(
          text: text.substring(index, index + query.length),
          style: const TextStyle(
              backgroundColor: Colors.yellow, color: Colors.black))); // تمييز النص المطابق
      start = index + query.length;
    }
    return RichText(text: TextSpan(children: spans, style: const TextStyle(fontSize: 14))); // عرض النص المميز
  }

  // بناء شريط التطبيق مع وضع البحث
  PreferredSizeWidget _buildAppBar() {
    if (_isSearching) { // إذا كان وضع البحث مفعلاً
      return AppBar(
        backgroundColor: Colors.white, // لون الخلفية
        foregroundColor: Colors.black, // لون النص
        leading: IconButton(
          icon: const Icon(Icons.arrow_back), // زر الرجوع
          onPressed: () {
            setState(() {
              _isSearching = false; // إلغاء وضع البحث
              _searchQuery = ""; // إعادة تعيين نص البحث
            });
          },
        ),
        title: TextField(
          autofocus: true, // تفعيل التركيز تلقائيًا
          decoration: const InputDecoration(
              hintText: "Search...", border: InputBorder.none), // نص الإرشاد
          onChanged: _updateSearchQuery, // تحديث نص البحث عند تغييره
        ),
      );
    } else { // إذا لم يكن وضع البحث مفعلاً
      return AppBar(
        backgroundColor: Colors.white, // لون الخلفية
        elevation: 0, // إزالة الظل
        title: const Text("Messages"), // عنوان الشريط
        foregroundColor: Colors.black, // لون النص
        actions: [
          IconButton(
            icon: const Icon(Icons.search), // زر البحث
            onPressed: () {
              setState(() {
                _isSearching = true; // تفعيل وضع البحث
              });
            },
          ),
          IconButton(
              icon: const Icon(Icons.more_vert), onPressed: () {}), // زر الخيارات
        ],
      );
    }
  }

  // بناء واجهة الوميض (Shimmer) أثناء التحميل
  Widget buildShimmerScaffold() {
    int itemCount = _conversations.isNotEmpty ? _conversations.keys.length : 11; // عدد العناصر
    return Scaffold(
      backgroundColor: Colors.white, // لون الخلفية
      appBar: AppBar(
        backgroundColor: Colors.white, // لون الخلفية
        elevation: 0, // إزالة الظل
        title: Shimmer.fromColors(
          baseColor: Colors.grey.shade300, // اللون الأساسي للوميض
          highlightColor: Colors.grey.shade100, // لون التمييز
          child: Container(
            width: 150, // عرض العنصر
            height: 20, // ارتفاع العنصر
            color: Colors.white, // لون العنصر
          ),
        ),
      ),
      // بناء واجهة المستخدم باستخدام ListView.builder
body: ListView.builder(
  itemCount: itemCount, // عدد العناصر في القائمة
  itemBuilder: (context, index) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0), // إضافة مسافة حول كل عنصر
      child: Shimmer.fromColors(
        baseColor: Colors.grey.shade300, // اللون الأساسي لتأثير الوميض
        highlightColor: Colors.grey.shade100, // لون التمييز لتأثير الوميض
        child: Row(
          children: [
            Container(
              width: 48, // عرض الصورة الرمزية
              height: 48, // ارتفاع الصورة الرمزية
              decoration: const BoxDecoration(
                color: Colors.white, // لون الخلفية
                shape: BoxShape.circle, // شكل دائري
              ),
            ),
            const SizedBox(width: 16), // مسافة أفقية بين الصورة والنص
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, // محاذاة النص إلى اليسار
                children: [
                  Container(
                    width: double.infinity, // عرض النص بالكامل
                    height: 12, // ارتفاع النص
                    color: Colors.white, // لون الخلفية
                  ),
                  const SizedBox(height: 8), // مسافة عمودية بين النصوص
                  Container(
                    width: double.infinity, // عرض النص بالكامل
                    height: 12, // ارتفاع النص
                    color: Colors.white, // لون الخلفية
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16), // مسافة أفقية بين النصوص والعنصر الأخير
            Container(
              width: 40, // عرض العنصر الأخير
              height: 12, // ارتفاع العنصر الأخير
              color: Colors.white, // لون الخلفية
            )
          ],
        ),
      ),
    );
  },
),

// زر عائم مع تأثير الوميض
floatingActionButton: Shimmer.fromColors(
  baseColor: Colors.grey.shade300, // اللون الأساسي لتأثير الوميض
  highlightColor: Colors.grey.shade100, // لون التمييز لتأثير الوميض
  child: FloatingActionButton.extended(
    onPressed: () {}, // إجراء عند الضغط على الزر
    backgroundColor: Colors.lightBlue[100], // لون الخلفية
    icon: const Icon(Icons.message_outlined, color: Colors.blue), // أيقونة الزر
    label: const Text("Start chat", style: TextStyle(color: Colors.blue)), // نص الزر
  ),
),

// بناء واجهة المستخدم الرئيسية باستخدام FutureBuilder
@override
Widget build(BuildContext context) {
  return FutureBuilder<List<Contact>>(
    future: _contactsFuture, // جلب جهات الاتصال
    builder: (context, contactsSnapshot) {
      if (contactsSnapshot.connectionState == ConnectionState.waiting) {
        return buildShimmerScaffold(); // عرض واجهة الوميض أثناء التحميل
      } else if (contactsSnapshot.hasError) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Messages"), // عنوان الشريط العلوي
            backgroundColor: Colors.white, // لون الخلفية
            foregroundColor: Colors.black, // لون النص
          ),
          body: Center(child: Text("Error: ${contactsSnapshot.error}")), // عرض رسالة الخطأ
        );
      } else if (!contactsSnapshot.hasData || contactsSnapshot.data!.isEmpty) {
        return Scaffold(
          appBar: AppBar(
            title: const Text("Messages"), // عنوان الشريط العلوي
            backgroundColor: Colors.white, // لون الخلفية
            foregroundColor: Colors.black, // لون النص
          ),
          body: const Center(child: Text("No contacts available")), // عرض رسالة عدم وجود جهات اتصال
        );
      } else {
        final contacts = contactsSnapshot.data!; // جهات الاتصال المحملة

        // إذا كان المستخدم في وضع البحث
        if (_isSearching) {
          final filteredConversations = _filterConversations(contacts); // تصفية المحادثات
          final filteredContacts = _filterContacts(contacts); // تصفية جهات الاتصال
          return Scaffold(
            backgroundColor: Colors.white, // لون الخلفية
            appBar: _buildAppBar(), // بناء شريط التطبيق
            body: ListView(
              children: [
                if (filteredConversations.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // مسافة حول النص
                    child: Text(
                      "Conversations", // عنوان قسم المحادثات
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // تنسيق النص
                    ),
                  ),
                ...filteredConversations.map((address) {
                  final messages = _conversations[address]!; // جلب الرسائل للمحادثة
                  final lastMessage = messages.reduce(
                      (a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b); // الحصول على آخر رسالة
                  final name = getContactName(address, contacts); // اسم جهة الاتصال
                  final char = name.isNotEmpty ? name[0] : "?"; // الحرف الأول من الاسم
                  final color = _getColorFromChar(char); // لون بناءً على الحرف
                  final unreadCount = _unreadCounts[address] ?? 0; // عدد الرسائل غير المقروءة
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: color, // لون الصورة الرمزية
                      child: Text(
                        char, // الحرف الأول
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // تنسيق النص
                      ),
                    ),
                    title: Text(
                      name, // اسم جهة الاتصال
                      style: const TextStyle(fontWeight: FontWeight.w600), // تنسيق النص
                    ),
                    subtitle: _buildHighlightedText(lastMessage.body ?? "", _searchQuery), // النص المميز
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center, // محاذاة النصوص في المنتصف
                      children: [
                        if (lastMessage.date != null)
                          Text(
                            _formatDate(lastMessage.date!), // تنسيق التاريخ
                            style: TextStyle(fontSize: 12, color: Colors.grey[600]), // تنسيق النص
                          ),
                        if (unreadCount > 0)
                          badges.Badge(
                            badgeContent: Text(
                              '$unreadCount', // عدد الرسائل غير المقروءة
                              style: const TextStyle(color: Colors.white, fontSize: 10), // تنسيق النص
                            ),
                            badgeColor: Colors.blueAccent, // لون الشارة
                            padding: const EdgeInsets.all(6), // مسافة داخلية
                          ),
                      ],
                    ),
                    onTap: () {
                      final messageController = Provider.of<MessageController>(context, listen: false); // وحدة التحكم بالرسائل
                      final normalizedAddress = messageController.normalizePhoneNumber(address); // تطبيع العنوان
                      setState(() {
                        _unreadCounts[normalizedAddress] = 0; // إعادة تعيين عدد الرسائل غير المقروءة
                      });
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChatScreen(
                            address: address, // عنوان المحادثة
                            recipient: name, // اسم جهة الاتصال
                            recipientImageUrl: null, // صورة جهة الاتصال
                            searchQuery: _searchQuery, // تمرير استعلام البحث
                          ),
                        ),
                      ).then((_) => _loadConversations()); // إعادة تحميل المحادثات عند العودة
                    },
                  );
                }).toList(),
                if (filteredContacts.isNotEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8), // مسافة حول النص
                    child: Text(
                      "Contacts", // عنوان قسم جهات الاتصال
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold), // تنسيق النص
                    ),
                  ),
                ...filteredContacts.map((contact) {
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade400, // لون الصورة الرمزية
                      child: Text(
                        contact.displayName.isNotEmpty ? contact.displayName[0] : "?", // الحرف الأول من الاسم
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // تنسيق النص
                      ),
                    ),
                    title: Text(
                      contact.displayName, // اسم جهة الاتصال
                      style: const TextStyle(fontWeight: FontWeight.w600), // تنسيق النص
                    ),
                    onTap: () async {
                      final messageController = Provider.of<MessageController>(context, listen: false); // وحدة التحكم بالرسائل
                      String? existingAddress;

                      // إذا كان اسم الجهة يحتوي على أحرف غير رقمية
                      if (_containsLetters(contact.displayName)) {
                        existingAddress = contact.displayName;
                      } else {
                        // البحث في أرقام الهاتف
                        for (var phone in contact.phones) {
                          String normalizedPhone = messageController.normalizePhoneNumber(phone.number); // تطبيع الرقم
                          for (var convAddress in _conversations.keys) {
                            String normalizedConv = messageController.normalizePhoneNumber(convAddress); // تطبيع العنوان
                            if (normalizedConv == normalizedPhone) {
                              existingAddress = convAddress; // العثور على العنوان المطابق
                              break;
                            }
                          }
                          if (existingAddress != null) break;
                        }
                      }
                      if (existingAddress != null) {
                        final validAddress = existingAddress!;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              address: validAddress, // عنوان المحادثة
                              recipient: contact.displayName, // اسم جهة الاتصال
                              recipientImageUrl: null, // صورة جهة الاتصال
                            ),
                          ),
                        );
                      } else {
                        if (contact.phones.isEmpty) {
                          if (_containsLetters(contact.displayName)) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  address: contact.displayName, // عنوان المحادثة
                                  recipient: contact.displayName, // اسم جهة الاتصال
                                  recipientImageUrl: null, // صورة جهة الاتصال
                                ),
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text("لا يوجد رقم هاتف لهذه الجهة")), // رسالة خطأ
                            );
                          }
                          return;
                        }

                        String phoneNumber = contact.phones.first.number; // رقم الهاتف الأول
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatScreen(
                              address: phoneNumber, // عنوان المحادثة
                              recipient: contact.displayName, // اسم جهة الاتصال
                            ),
                          ),
                        );
                      }
                    },
                  );
                }).toList(),
              ],
            ),
          );
        } else {
          final addresses = _conversations.keys.toList(); // قائمة العناوين
          addresses.sort((a, b) {
            final messagesA = _conversations[a]!; // رسائل المحادثة A
            final messagesB = _conversations[b]!; // رسائل المحادثة B
            final lastA = messagesA.reduce((a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b); // آخر رسالة في A
            final lastB = messagesB.reduce((a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b); // آخر رسالة في B
            return (lastB.date ?? 0).compareTo(lastA.date ?? 0); // ترتيب المحادثات حسب التاريخ
          });
          return Scaffold(
            backgroundColor: Colors.white, // لون الخلفية
            appBar: _buildAppBar(), // بناء شريط التطبيق
            body: ListView.builder(
              itemCount: addresses.length, // عدد المحادثات
              itemBuilder: (context, index) {
                final address = addresses[index]; // عنوان المحادثة
                final messages = _conversations[address]!; // رسائل المحادثة
                final lastMessage = messages.reduce((a, b) => (a.date ?? 0) > (b.date ?? 0) ? a : b); // آخر رسالة
                final name = getContactName(address, contacts); // اسم جهة الاتصال
                final char = name.isNotEmpty ? name[0] : "?"; // الحرف الأول من الاسم
                final color = _getColorFromChar(char); // لون بناءً على الحرف
                final unreadCount = _unreadCounts[address] ?? 0; // عدد الرسائل غير المقروءة
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color, // لون الصورة الرمزية
                    child: Text(
                      char, // الحرف الأول
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), // تنسيق النص
                    ),
                  ),
                  title: Text(
                    name, // اسم جهة الاتصال
                    style: const TextStyle(fontWeight: FontWeight.w600), // تنسيق النص
                  ),
                  subtitle: Text(
                    lastMessage.body ?? "", // النص الأخير
                    maxLines: 1, // عدد الأسطر
                    overflow: TextOverflow.ellipsis, // اقتصاص النص إذا كان طويلًا
                    style: TextStyle(color: Colors.grey[600]), // تنسيق النص
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center, // محاذاة النصوص في المنتصف
                    children: [
                      if (lastMessage.date != null)
                        Text(
                          _formatDate(lastMessage.date!), // تنسيق التاريخ
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]), // تنسيق النص
                        ),
                      if (unreadCount > 0)
                        badges.Badge(
                          badgeContent: Text(
                            '$unreadCount', // عدد الرسائل غير المقروءة
                            style: const TextStyle(color: Colors.white, fontSize: 10), // تنسيق النص
                          ),
                          badgeColor: Colors.blueAccent, // لون الشارة
                          padding: const EdgeInsets.all(6), // مسافة داخلية
                        ),
                    ],
                  ),
                  onTap: () {
                    final messageController = Provider.of<MessageController>(context, listen: false); // وحدة التحكم بالرسائل
                    final normalizedAddress = messageController.normalizePhoneNumber(address); // تطبيع العنوان
                    setState(() {
                      _unreadCounts[normalizedAddress] = 0; // إعادة تعيين عدد الرسائل غير المقروءة
                    });
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          address: address, // عنوان المحادثة
                          recipient: name, // اسم جهة الاتصال
                          recipientImageUrl: null, // صورة جهة الاتصال
                        ),
                      ),
                    ).then((_) => _loadConversations()); // إعادة تحميل المحادثات عند العودة
                  },
                );
              },
            ),
            floatingActionButton: FloatingActionButton.extended(
              backgroundColor: Colors.lightBlue[100], // لون الخلفية
              icon: const Icon(Icons.message_outlined, color: Colors.blue), // أيقونة الزر
              label: const Text("Start chat", style: TextStyle(color: Colors.blue)), // نص الزر
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (_) => NewMessageScreen())); // الانتقال إلى شاشة الرسائل الجديدة
              },
            ),
          );
        }
      }
    },
  );
}