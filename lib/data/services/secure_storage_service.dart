import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import '../models.dart';
import 'device_mapper.dart';

class SecureStorageService {
  static const String _magicHeaderStr = "SAM";
  static const int _version = 0x01;
  static const int _saltLength = 16;
  static const int _ivLength = 12;
  static const int _tagLength = 16;
  static const int _pbkdf2Iterations = 100000;

  final _algorithm = AesGcm.with256bits();
  final _kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _pbkdf2Iterations,
    bits: 256,
  );

  Future<Uint8List> exportDevice({
    required Device device,
    required String password,
    required bool includeSecrets,
  }) async {
    final jsonMap = DeviceMapper.toExportJson(
      device,
      includeSecrets: includeSecrets,
    );
    final jsonString = jsonEncode(jsonMap);
    final plainTextBytes = utf8.encode(jsonString);

    final random = Random.secure();
    final saltBytes = Uint8List(_saltLength);
    for (var i = 0; i < _saltLength; i++) {
      saltBytes[i] = random.nextInt(256);
    }

    final nonce = _algorithm.newNonce();

    final secretKey = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: saltBytes,
    );

    final secretBox = await _algorithm.encrypt(
      plainTextBytes,
      secretKey: secretKey,
      nonce: nonce,
    );

    final builder = BytesBuilder();

    builder.add(utf8.encode(_magicHeaderStr));
    builder.addByte(_version);

    builder.add(saltBytes);

    builder.add(secretBox.nonce);

    builder.add(secretBox.mac.bytes);

    builder.add(secretBox.cipherText);

    return builder.toBytes();
  }

  Future<Device> importDevice({
    required Uint8List fileBytes,
    required String password,
  }) async {
    final totalHeaderSize = 3 + 1 + _saltLength + _ivLength + _tagLength;

    if (fileBytes.length < totalHeaderSize) {
      throw FormatException("File is too small to be a valid .sam file");
    }

    final headerBytes = fileBytes.sublist(0, 3);
    final versionByte = fileBytes[3];

    if (utf8.decode(headerBytes) != _magicHeaderStr) {
      throw FormatException("Invalid file format: Header mismatch");
    }
    if (versionByte != _version) {
      throw FormatException("Unsupported file version: $versionByte");
    }

    final saltBytes = fileBytes.sublist(4, 4 + _saltLength);
    final ivBytes = fileBytes.sublist(20, 20 + _ivLength);
    final tagBytes = fileBytes.sublist(32, 32 + _tagLength);
    final ciphertextBytes = fileBytes.sublist(48);

    final secretKey = await _kdf.deriveKeyFromPassword(
      password: password,
      nonce: saltBytes,
    );

    try {
      final secretBox = SecretBox(
        ciphertextBytes,
        nonce: ivBytes,
        mac: Mac(tagBytes),
      );

      final decryptedBytes = await _algorithm.decrypt(
        secretBox,
        secretKey: secretKey,
      );

      final jsonString = utf8.decode(decryptedBytes);
      return DeviceMapper.fromExportJson(jsonString);
    } on SecretBoxAuthenticationError {
      throw const FormatException("Incorrect Password or Corrupted File");
    } catch (e) {
      throw FormatException("Decryption failed: $e");
    }
  }
}
