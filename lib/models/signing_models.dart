class InstitutionalIdentity {
  const InstitutionalIdentity({this.centerName = '', this.centerCode = '', this.address = '', this.signerName = '', this.signerRole = '', this.logoPath = '', this.sealPath = '', this.signaturePath = ''});
  final String centerName;
  final String centerCode;
  final String address;
  final String signerName;
  final String signerRole;
  final String logoPath;
  final String sealPath;
  final String signaturePath;
}

class SigningProfile {
  const SigningProfile({required this.id, required this.label, required this.subject, required this.issuer, required this.serialNumber, required this.notBefore, required this.notAfter, required this.certificatePath, this.active = false});
  final String id;
  final String label;
  final String subject;
  final String issuer;
  final String serialNumber;
  final DateTime notBefore;
  final DateTime notAfter;
  final String certificatePath;
  final bool active;
}
