/// Advisory consent wording, never evidence of verifier or credential trust.
bool requestsSensitivePresentationFields(Iterable<String> fields) {
  const sensitive = {
    'ssn',
    'driverlicense',
    'creditcard',
    'biometricdata',
    'medicalrecords',
    'phonenumber',
    'address',
    'email',
    'idnumber',
    'socialsecuritynumber',
    'nationalid',
    'nationalidentificationnumber',
    'passportnumber',
    'bankaccount',
    'bankaccountnumber',
    'creditcardnumber',
    'dateofbirth',
    'birthdate',
    'medicalrecord',
    'healthinformation',
  };
  return fields.any((field) {
    final name = field
        .split('/')
        .last
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]'), '');
    return sensitive.any(name.contains);
  });
}
