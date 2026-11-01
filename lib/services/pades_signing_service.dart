import 'dart:typed_data';

import 'package:signer_pdf/signer_pdf.dart';

class PadesSigningService {
  final SignerPdf _kit = SignerPdf();

  Future<CertificateInfo> inspectCertificate({required Uint8List p12Bytes, required String password}) => _kit.validarCertificado(p12Bytes, password);

  Future<Uint8List> signPdf({required Uint8List pdfBytes, required Uint8List p12Bytes, required String password, required String signerName, required String reason, required String location}) => _kit.firmarPdf(pdfBytes: pdfBytes, p12Bytes: p12Bytes, password: password, sello: SelloVisualConfig(coordenadas: const [SelloCoordenada(page: 1, x: 40, y: 50)], scale: 'normal', reason: reason, location: location));

  Future<dynamic> validateSignedPdf(Uint8List bytes) => _kit.validarPdfFirmado(bytes);
}
