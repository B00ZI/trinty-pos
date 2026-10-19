// Generates a valid activation key (Short + Long form) for THIS Windows
// machine, using the same RSA logic and fingerprint scheme as
// lib/service/activation_service.dart.
//
// Usage (from the project root):
//   dart run tool/generate_activation_key.dart
//
// NOTE: the fingerprint formula must stay in sync with
// ActivationService.getAndroidId() (Windows branch).
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:pointycastle/pointycastle.dart' as pc;
import 'package:pointycastle/asymmetric/api.dart' as pc_api;

const String _privateKeyPem = '''
-----BEGIN RSA PRIVATE KEY-----
MIIEpAIBAAKCAQEAqqI90Pduu4Sou6sPOjZvB5gb4L2NZTfd7GX9mpRdx4T81QgI
dDsQljIIi2Gh/i8bqBHjyfl98aEcz+mxYEtVPeWyQln1cHsMjJ2l2gjqEnmZSqD6
lJW+4DXZ5EhYCMzBp97upfwRq4mSFk92089u3frUynTy522zULBdvwcC4wqjJ7tW
AexruiRT2I1YObmh571fJ261aSA7sJLlOr+pAz/nqWODsqX+gYgITdNTNZBgvqh0
34WKxKvbKiQbfoCGza1uYz2ZrYL35q3xUXyZONxQowKUAMUo0zZL6p/be/8Wbhbg
1Y57KlpxrXoXXs9ioiK85VuCKnq927NnUNsJlQIDAQABAoIBADnF6/MsS7g+7th3
zxSRKJ+kH1BFLbInK8MmNysW7/elbet9KEueUfvgneb/XBdRgOYzhHI2wK9Gsxgs
Uku9xfNKqcPwbHs0lmen2udLXGF7/Wx4u88CMpn8cbVqzy/PkAQUJa5afescDbPz
HNMTaUDMdC7GURYNnQiFZoBO0enn+vAA1QGDRYh3Zjo/pC4CojovQfoqPh2afypx
8/lRpZve7lrHdVm3+h8BEFZHlDdziujNlR3ig3oAvTiiGuz6CRZ8Y8au8hItlop9
YsmuSQhpHd4+iI4nHPM4eQhw5wAbh4rYqKEJ3aFjnwkoweJLFCchMa5gr81BkjOr
LnFjEuMCgYEA2q6P+kTu0319g2c3dAjXzJliEez1ufZA3tGl7NrVUw5j08eqQci7
58eUs8ymbprGAKhTciKGO1dIWit8zaC2GXiEPCsfwpnHCnLrQG27UpGmhoiv+Grl
YHA81YrBHBWk/tneQ4MqRA1CfoLw8lZ5+bTdYWnduljMM1XNv1lWMqMCgYEAx8Cg
WV0IxgNQReYqlRR/X7M7AIOb2XrWZrTt/f7tpFas8kuN+xGdfCph0N6OhN7QvVYz
cGFi56hdAA2VmxIp0GxxXN7gGlAvop9Urr42eNY4u+QPQdNV5Di1qBafXTbTMDky
oItNsXFy+MgL/axstZ3XLO+CQTwoe1ZseeA1TmcCgYAgwBnx+lbmN5oPjurAJv7i
tmn4k0tt0VJ/zFgUM+XU7YfH1NRLy9tQaBR+JP0b/XP/7zWoF0GRK447at3jEdmT
0PfE5xR3mX40s2dGG+j9AbE13syz4JZ/re9+b6xiH1+5hzmBVOiEjpPRzJx3Pro/
ynWJPEinutrCKWyJ5sBBDwKBgQC7ZvfI/ySVCVTNT0QR+1oIwdEQCWk03y64yvQh
AIOZU4wMAWBh9UPH0sdUOwiAlb5Gc9HslCFDb0xZGWWLR74dATBVze94IFSggFTl
YCUgtvIhLLQ3sHr7k0yyNw8qV55IttDNmAO6/tG7n4rIYnTW6w+N4+JTK4pbNFiu
+u9n7wKBgQC6yb0I57f3WFFuC+TvKQ8SQuAcr9gX4m5XUD8f9mKOghFRjnTyVBKT
k47se6n6oPDk4OxJNzBkxJO8Zdn4ACbDmgwOaM9+5rkh2LNvPtZumAyhiqLWqWYD
d277L8iSfpacBpQzZ1rhAvlZm7Xp3IRr9gGCsZiuZj7pYMsGL9CMpw==
-----END RSA PRIVATE KEY-----
''';

/// Reads ProductId (String) and DigitalProductId (byte array) from the
/// registry — exactly the values device_info_plus exposes as
/// WindowsDeviceInfo.productId / .digitalProductId.
Map<String, String> _readWindowsIdentity() {
  final result = Process.runSync('powershell.exe', [
    '-NoProfile',
    '-Command',
    r'''
$v = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion'
Write-Output $v.ProductId
Write-Output ([byte[]]$v.DigitalProductId -join ',')
''',
  ]);
  if (result.exitCode != 0) {
    stderr.writeln('Failed to read Windows identity: ${result.stderr}');
    exit(1);
  }
  final lines = (result.stdout as String)
      .split('\r\n')
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.length < 2) {
    stderr.writeln('Unexpected registry output: ${result.stdout}');
    exit(1);
  }
  return {'productId': lines[0].trim(), 'digitalProductId': lines[1].trim()};
}

void main() {
  final identity = _readWindowsIdentity();

  // Must match ActivationService.getAndroidId() (Windows branch) exactly.
  final raw = '${identity['productId']}|${identity['digitalProductId']}';
  final deviceId = sha256.convert(utf8.encode(raw)).toString();

  final parser = encrypt.RSAKeyParser();
  final privateKey = parser.parse(_privateKeyPem) as pc_api.RSAPrivateKey;

  const expiry = 'never';
  const licenseType = 'PRO';
  final metadata = '$deviceId|$expiry|$licenseType';

  final signer = pc.Signer('SHA-256/RSA')
    ..init(true, pc.PrivateKeyParameter<pc_api.RSAPrivateKey>(privateKey));
  final sig =
      signer.generateSignature(utf8.encode(metadata)) as pc.RSASignature;
  final signatureBase64 = base64.encode(sig.bytes);

  // Short key: XXXX-XXXX (first 8 hex chars of sha256(signature)).
  final hash = sha256.convert(sig.bytes).toString().toUpperCase();
  final shortKey = '${hash.substring(0, 4)}-${hash.substring(4, 8)}';

  // Long key: Base64(deviceId|expiry|type|signatureBase64).
  final longKey =
      base64.encode(utf8.encode('$metadata|$signatureBase64'));

  stdout.writeln('');
  stdout.writeln('Device fingerprint : $deviceId');
  stdout.writeln('Short key (XXXX-XXXX) : $shortKey');
  stdout.writeln('Long key              : $longKey');
  stdout.writeln('');
  stdout.writeln('Enter either key in the activation dialog.');
}
