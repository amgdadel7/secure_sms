// استيراد المكتبات اللازمة
const express = require('express'); // لإنشاء خادم ويب
const mysql = require('mysql2/promise'); // للتعامل مع قاعدة البيانات MySQL باستخدام وعود
const crypto = require('crypto'); // لتوليد المفاتيح والتشفير
const EC = require('elliptic').ec; // مكتبة لتشفير ECC
const app = express(); // إنشاء تطبيق Express
const port = process.env.PORT || 3000; // تحديد المنفذ الذي سيعمل عليه الخادم

app.use(express.json()); // تمكين معالجة JSON في الطلبات

// إعداد الاتصال بقاعدة البيانات باستخدام Connection Pooling
const pool = mysql.createPool({
  host: 'sql.freedb.tech', // عنوان الخادم
  port: 3306, // المنفذ
  user: 'freedb_phone_info', // اسم المستخدم
  password: 'GwUR7uUZ@p#P2?z', // كلمة المرور
  database: 'freedb_massege', // اسم قاعدة البيانات
  waitForConnections: true, // انتظار الاتصالات عند الوصول إلى الحد الأقصى
  connectionLimit: 10, // الحد الأقصى للاتصالات
  queueLimit: 0 // عدم وجود حد للطلبات في قائمة الانتظار
});

// دالة لإنشاء جدول device_info إذا لم يكن موجودًا
async function initializeDatabase() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS device_info (
        id INT AUTO_INCREMENT PRIMARY KEY,
        uuid VARCHAR(255) UNIQUE NOT NULL,
        code VARCHAR(255) NOT NULL,
        phone_num VARCHAR(255) NOT NULL UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )
    `);
    console.log('✅ جدول device_info جاهز');
  } catch (err) {
    console.error('❌ خطأ في إنشاء الجدول:', err);
    process.exit(1); // إنهاء التطبيق إذا فشل إنشاء الجدول
  }
}

// نقطة API لتسجيل الجهاز
app.post('/api/device-info', async (req, res) => {
  const { uuid, code, phone_num } = req.body; // استخراج البيانات من الطلب
  await initializeDatabase(); // التأكد من أن الجدول موجود
  const connection = await pool.getConnection(); // الحصول على اتصال من المسبح
  try {
    await connection.query('START TRANSACTION'); // بدء معاملة
    const query = `
      INSERT INTO device_info (uuid, code, phone_num)
      VALUES (?, ?, ?)
      ON DUPLICATE KEY UPDATE
        code = VALUES(code),
        phone_num = VALUES(phone_num)
    `;
    await connection.query(query, [uuid, code, phone_num]); // إدخال البيانات أو تحديثها
    await connection.query('COMMIT'); // تأكيد المعاملة
    res.json({ success: true });
  } catch (err) {
    await connection.query('ROLLBACK'); // التراجع عن المعاملة في حالة الخطأ
    console.error('❌ خطأ في التسجيل:', err);
    res.status(500).json({ error: 'فشل في التسجيل' });
  } finally {
    connection.release(); // تحرير الاتصال
  }
});

// نقطة API للبحث عن جهاز باستخدام رقم الهاتف
app.post('/api/find-device', async (req, res) => {
  const { searchValue } = req.body;

  if (!searchValue) {
    return res.status(400).json({ error: 'يجب إرسال قيمة للبحث' });
  }

  try {
    // إنشاء نسختين من قيمة البحث (مع وبدون +)
    const searchVariants = [
      searchValue,
      searchValue.startsWith('+') ? searchValue.substring(1) : `+${searchValue}`
    ];

    const query = `
      SELECT uuid
      FROM device_info
      WHERE phone_num = ? OR phone_num = ?
      LIMIT 1
    `;

    const [results] = await pool.query(query, searchVariants); // تنفيذ الاستعلام

    if (results.length > 0) {
      return res.json({ uuid: results[0].uuid }); // إرجاع UUID إذا تم العثور عليه
    } else {
      return res.status(404).json({ error: 'لا يوجد جهاز مطابق' });
    }
  } catch (err) {
    console.error('خطأ في البحث:', err);
    return res.status(500).json({ error: 'خطأ داخلي في الخادم' });
  }
});

// دالة لتوليد مفاتيح ECDH
const generateECDHKeys = () => {
  const ecdh = crypto.createECDH('secp256k1'); // إنشاء كائن ECDH باستخدام منحنى secp256k1
  ecdh.generateKeys(); // توليد المفاتيح
  return {
    publicKey: ecdh.getPublicKey('hex'), // المفتاح العام
    privateKey: ecdh.getPrivateKey('hex') // المفتاح الخاص
  };
};

// نقطة API لتبادل المفاتيح
app.post('/api/exchange-keys', async (req, res) => {
  const { senderUUID, receiverUUID, senderPublicKey, targetPhone } = req.body;

  try {
    // التحقق من وجود البيانات المطلوبة
    if (!senderUUID || !senderPublicKey || !targetPhone) {
      return res.status(400).json({ error: 'جميع الحقول مطلوبة' });
    }

    // التحقق من تنسيق المفتاح العام
    if (!senderPublicKey.startsWith('04') || senderPublicKey.length !== 130) {
      return res.status(400).json({ error: 'تنسيق المفتاح العام غير صالح' });
    }

    const ec = new EC('secp256k1'); // إنشاء كائن EC باستخدام منحنى secp256k1
    let publicKey;
    try {
      publicKey = ec.keyFromPublic(senderPublicKey, 'hex'); // تحليل المفتاح العام
      if (!publicKey.validate()) {
        return res.status(400).json({ error: 'المفتاح العام غير صالح' });
      }
    } catch (e) {
      return res.status(400).json({ error: 'فشل في تحليل المفتاح العام' });
    }

    // البحث عن الجهاز المستقبل باستخدام رقم الهاتف
    const [targetDevice] = await pool.query(
      'SELECT uuid, phone_num FROM device_info WHERE phone_num = ?',
      [targetPhone]
    );

    if (!targetDevice || targetDevice.length === 0) {
      return res.status(404).json({ error: 'الجهاز المستقبل غير مسجل' });
    }

    // توليد مفاتيح جديدة للجهاز المستقبل
    const ecdh = crypto.createECDH('secp256k1');
    ecdh.generateKeys();

    // إرجاع المفتاح العام غير المضغوط
    const targetPublicKey = ecdh.getPublicKey('hex', 'uncompressed');

    res.json({
      success: true,
      targetUUID: targetDevice[0].uuid,
      targetPublicKey: targetPublicKey,
      targetPhone: targetDevice[0].phone_num
    });

  } catch (e) {
    console.error('❌ خطأ في تبادل المفاتيح:', e);
    res.status(500).json({
      error: 'حدث خطأ في الخادم',
      details: e.message
    });
  }
});

// دالة لإنشاء جدول key_info إذا لم يكن موجودًا
async function createKeyInfoTable() {
  try {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS key_info (
        id INT AUTO_INCREMENT PRIMARY KEY,
        senderUUID VARCHAR(255) NOT NULL,
        senderNUM VARCHAR(255),
        receiverUUID VARCHAR(255) NOT NULL,
        receiverNUM VARCHAR(255),
        sharedSecret TEXT NOT NULL,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        UNIQUE KEY unique_pair (senderUUID, receiverUUID)
      )
    `);
    console.log('✅ جدول key_info جاهز');
  } catch (err) {
    console.error('❌ خطأ في إنشاء جدول key_info:', err);
    throw err;
  }
}

// نقطة API لحفظ المفاتيح
app.post('/api/store-keys', async (req, res) => {
  const { senderUUID, senderNUM, receiverUUID, receiverNUM, sharedSecret } = req.body;

  try {
    await createKeyInfoTable(); // التأكد من وجود الجدول

    const query = `
      INSERT INTO key_info (senderUUID, senderNUM, receiverUUID, receiverNUM, sharedSecret)
      VALUES (?, ?, ?, ?, ?)
      ON DUPLICATE KEY UPDATE
        sharedSecret = VALUES(sharedSecret),
        created_at = CURRENT_TIMESTAMP
    `;

    await pool.query(query, [senderUUID, senderNUM, receiverUUID, receiverNUM, sharedSecret]); // إدخال البيانات أو تحديثها
    res.json({ success: true });
  } catch (err) {
    console.error('❌ خطأ في حفظ المفاتيح:', err);
    res.status(500).json({
      error: 'فشل في حفظ المفاتيح',
      details: err.message
    });
  }
});

// نقطة API لاسترجاع المفاتيح باستخدام UUID
app.post('/api/get-keys', async (req, res) => {
  const { senderUUID, receiverUUID } = req.body;

  try {
    if (!senderUUID || !receiverUUID) {
      return res.status(400).json({
        error: 'يجب إرسال senderUUID و receiverUUID'
      });
    }

    const query = `
      SELECT
        senderUUID,
        senderNUM,
        receiverUUID,
        receiverNUM,
        sharedSecret,
        created_at
      FROM key_info
      WHERE senderUUID = ?
        AND receiverUUID = ?
    `;

    const [rows] = await pool.query(query, [senderUUID, receiverUUID]);

    if (rows.length === 0) {
      return res.status(404).json({
        message: 'لا توجد بيانات مطابقة'
      });
    }

    res.json({
      success: true,
      data: rows[0]
    });

  } catch (err) {
    console.error('❌ خطأ في استرجاع البيانات:', err);
    res.status(500).json({
      error: 'فشل في استرجاع البيانات',
      details: err.message
    });
  }
});

// نقطة API لاسترجاع المفاتيح باستخدام أرقام الهواتف
app.post('/api/get-keys-by-num', async (req, res) => {
  const { senderNUM, receiverNUM } = req.body;

  try {
    if (!senderNUM || !receiverNUM) {
      return res.status(400).json({
        error: 'يجب إرسال senderNUM و receiverNUM'
      });
    }

    const query = `
      SELECT
        senderUUID,
        senderNUM,
        receiverUUID,
        receiverNUM,
        sharedSecret,
        created_at
      FROM key_info
      WHERE senderNUM = ?
        AND receiverNUM = ?
    `;

    const [rows] = await pool.query(query, [senderNUM, receiverNUM]);

    if (rows.length === 0) {
      return res.status(404).json({
        message: 'لا توجد بيانات مطابقة'
      });
    }

    res.json({
      success: true,
      data: rows[0]
    });

  } catch (err) {
    console.error('❌ خطأ في استرجاع البيانات:', err);
    res.status(500).json({
      error: 'فشل في استرجاع البيانات',
      details: err.message
    });
  }
});

// نقطة API للتحقق من وجود مفتاح مشترك
app.post('/api/check-key', async (req, res) => {
  const { senderNUM, receiverNUM } = req.body;

  if (!senderNUM || !receiverNUM) {
    return res.status(400).json({ error: 'يرجى إرسال senderNUM و receiverNUM' });
  }

  try {
    const [rows] = await pool.query(`
      SELECT * FROM key_info
      WHERE (senderNUM = ? AND receiverNUM = ?)
         OR (senderNUM = ? AND receiverNUM = ?)
      LIMIT 1
    `, [senderNUM, receiverNUM, receiverNUM, senderNUM]);

    if (rows.length > 0) {
      return res.json({ success: true, data: rows[0] });
    } else {
      return res.json({ success: false, message: 'لا توجد نتيجة مطابقة' });
    }
  } catch (err) {
    console.error('❌ خطأ أثناء تنفيذ الاستعلام:', err);
    return res.status(500).json({ error: 'حدث خطأ في السيرفر' });
  }
});

// بدء تشغيل الخادم
app.listen(port, () => {
  console.log(`🚀 الخادم يعمل على المنفذ ${port}`);
});