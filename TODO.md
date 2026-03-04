# TODO - Signature Canvas Feature

## Completed Tasks:
- [x] Backend API - generate_pilot_certificate.php - updated to accept POST with signature
- [x] Backend API - generate_mooring_certificate.php - already supports signature
- [x] Frontend - Signature canvas appears only for "Aktif" status
- [x] Frontend - Signature NOT saved to database (stored in state only)
- [ ] Frontend - Send signature to API during PDF generation (PENDING - edit_file issues)

## Current Issue:
The edit_file tool is not executing properly for the frontend pemanduan_page.dart file.
The code change needed is to replace the GET request with POST that includes signature.

## Code Change Required in frontend/lib/pages/pemanduan/pemanduan_page.dart:

Replace this code block:
```
dart
      // Prepare URL
      final url = type == 'pandu'
          ? '$baseUrl/generate_pilot_certificate.php?id=$id'
          : '$baseUrl/generate_mooring_certificate.php?id=$id';

      print('Requesting PDF from: $url'); // Debug log

      // Download PDF file with timeout
      final response = await http
          .get(Uri.parse(url))
```

With this:
```
dart
      // Check if there's a pending signature for this pemanduan
      String? signatureBase64;
      if (_pendingSignatureId == id && _pendingSignature != null) {
        signatureBase64 = _pendingSignature;
      }

      // Prepare API endpoint
      final String apiEndpoint = type == 'pandu'
          ? '$baseUrl/generate_pilot_certificate.php'
          : '$baseUrl/generate_mooring_certificate.php';

      print('Requesting PDF from: $apiEndpoint with signature: ${signatureBase64 != null}'); // Debug log

      // Send POST request with signature if available
      http.Response response;
      if (signatureBase64 != null) {
        // POST request with signature
        response = await http.post(
          Uri.parse(apiEndpoint),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            'id': id,
            'signature': signatureBase64,
          }),
        ).timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw Exception('Request timeout - server tidak merespon');
          },
        );
      } else {
        // GET request without signature (backward compatible)
        response = await http
            .get(Uri.parse('$apiEndpoint?id=$id'))
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () {
                throw Exception('Request timeout - server tidak merespon');
              },
            );
      }
