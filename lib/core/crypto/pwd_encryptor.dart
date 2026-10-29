import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// 统一身份认证密码加密。
///
/// 与服务端 `encrypt.js` 的 `encryptPassword` 完全一致：
///   plaintext = randomString(64) + password
///   key       = UTF8(pwdEncryptSalt)
///   iv        = randomString(16)
///   AES/CBC/PKCS7 → Base64
///
/// 前 64 位随机串用于填充首块，服务端解密后按固定长度截断取密码，
/// 因此 IV 随机不影响服务端还原。
class PwdEncryptor {
  PwdEncryptor._();

  static const String _chars =
      'ABCDEFGHJKMNPQRSTWXYZabcdefhijkmnprstwxyz2345678';

  static final Random _random = Random.secure();

  static String _randomString(int length) {
    final buffer = StringBuffer();
    for (var i = 0; i < length; i++) {
      buffer.write(_chars[_random.nextInt(_chars.length)]);
    }
    return buffer.toString();
  }

  /// 返回可直接提交的密文；salt 为空时退化为明文（与网页行为一致）。
  static String encrypt(String password, String salt) {
    if (salt.isEmpty) return password;
    final plain = utf8.encode(_randomString(64) + password);
    final key = _normalizeKey(utf8.encode(salt));
    final iv = utf8.encode(_randomString(16));

    final cipher = PaddedBlockCipherImpl(
      PKCS7Padding(),
      CBCBlockCipher(AESEngine()),
    );
    cipher.init(
      true,
      PaddedBlockCipherParameters<CipherParameters, CipherParameters>(
        ParametersWithIV<KeyParameter>(KeyParameter(key), Uint8List.fromList(iv)),
        null,
      ),
    );
    final encrypted = cipher.process(Uint8List.fromList(plain));
    return base64Encode(encrypted);
  }

  /// AES 仅接受 16/24/32 字节密钥，异常长度按截断/补零处理以保持可用性。
  static Uint8List _normalizeKey(List<int> raw) {
    const allowed = [16, 24, 32];
    if (allowed.contains(raw.length)) return Uint8List.fromList(raw);
    final size = raw.length <= 16
        ? 16
        : raw.length <= 24
            ? 24
            : 32;
    final out = Uint8List(size);
    for (var i = 0; i < size; i++) {
      out[i] = i < raw.length ? raw[i] : 0;
    }
    return out;
  }
}
