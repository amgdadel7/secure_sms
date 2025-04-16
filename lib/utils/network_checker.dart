import 'dart:io';

Future<bool> hasInternetConnection() async {
  try {
    final result = await InternetAddress.lookup('google.com');
    if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
      print("✅ Device is connected to the internet");
      return true;
    }
  } on SocketException catch (_) {
    print("❌ No internet connection");
    return false;
  }
  return false;
}

