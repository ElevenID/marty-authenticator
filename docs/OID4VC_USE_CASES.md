# OID4VC Deep Linking Use Cases and Examples

This document provides practical examples of how deep linking enhances OID4VC workflows in the privacyIDEA Authenticator.

## Employee Digital Badge Example

### Scenario

A company wants to issue digital employee badges that can be used for:

- Building access control
- Single sign-on to corporate applications
- Identity verification for remote work

### Implementation Flow

#### 1. Employee Authentication

```
Employee logs into HR portal using existing 2FA token
→ privacyIDEA validates authentication
→ HR system triggers credential issuance event
```

#### 2. Backend Credential Offer Generation

```python
# In privacyIDEA OID4VC Event Handler
def _issue_employee_badge(self, user_info):
    # Create credential offer
    offer = {
        "credential_issuer": "https://hr.company.com",
        "credentials": [{
            "format": "jwt_vc_json",
            "types": ["VerifiableCredential", "EmployeeBadge"],
            "credentialSubject": {
                "id": user_info["did"],
                "employeeId": user_info["username"],
                "department": user_info["department"],
                "clearanceLevel": user_info["clearance"],
                "validFrom": "2025-01-01T00:00:00Z",
                "validUntil": "2025-12-31T23:59:59Z"
            }
        }],
        "grants": {
            "urn:ietf:params:oauth:grant-type:pre-authorized_code": {
                "pre-authorized_code": secrets.token_urlsafe(32),
                "user_pin_required": False
            }
        }
    }

    # Generate deep link
    encoded_offer = base64.encode(json.dumps(offer))
    deep_link = f"openid-credential-offer://?credential_offer={encoded_offer}"

    # Send to employee via SMS/email/push notification
    return self._deliver_credential_offer(user_info["phone"], deep_link)
```

#### 3. Mobile App Processing

```dart
// In OID4VCSchemeProcessor
Future<List<ProcessorResult<Token>>?> _handleCredentialOffer(
  Uri uri, bool fromInit
) async {
  // Parse the credential offer
  final client = OID4VCClient(baseUrl: 'https://hr.company.com');
  final offer = await client.parseCredentialOffer(uri.toString());

  // Show credential preview to user
  final approved = await _showCredentialPreview(offer);

  if (approved) {
    // Request credential from issuer
    final credential = await client.requestCredentialWithPreAuthCode(
      offer: offer,
      preAuthCode: offer.grants['pre-authorized_code'],
    );

    // Store in secure storage
    await _storeEmployeeCredential(credential);

    // Show success message
    _showSuccessNotification("Employee badge added successfully");
  }
}
```

#### 4. Building Access Verification

```
Security guard scans QR code at building entrance
→ QR contains: openid4vp://?request=<building_access_request>
→ Employee's app opens showing required credentials
→ Employee approves sharing of employee badge
→ Security system verifies badge authenticity
→ Access granted based on clearance level
```

## Healthcare Vaccination Credential

### Scenario

Healthcare provider wants to issue digital vaccination certificates that can be used for:

- Travel verification
- Workplace health compliance
- Event attendance verification

### Implementation

#### 1. Vaccination Record Creation

```python
# After vaccination is administered
def _issue_vaccination_credential(self, patient_info, vaccine_info):
    credential_data = {
        "credential_issuer": "https://health.state.gov",
        "credentials": [{
            "format": "jwt_vc_json",
            "types": ["VerifiableCredential", "VaccinationCertificate"],
            "credentialSubject": {
                "id": patient_info["patient_id"],
                "vaccine": {
                    "type": vaccine_info["vaccine_type"],
                    "manufacturer": vaccine_info["manufacturer"],
                    "lot": vaccine_info["lot_number"],
                    "date": vaccine_info["administration_date"]
                },
                "provider": {
                    "name": "State Health Department",
                    "license": "MD12345"
                }
            }
        }]
    }

    # Generate secure deep link
    deep_link = f"openid-credential-offer://?credential_offer={encode(credential_data)}"

    # Send to patient
    send_secure_message(patient_info["phone"], deep_link)
```

#### 2. Travel Verification

```
Airline check-in requests health credentials
→ openid4vp://?request=<health_verification>&callback=<airline_app>
→ Passenger authorizes sharing vaccination proof
→ Airline verifies credential authenticity
→ Health compliance confirmed for travel
```

## University Digital Diploma

### Scenario

University issues verifiable digital diplomas that:

- Prevent diploma fraud
- Enable instant employer verification
- Provide lifelong credential access

### Implementation

#### 1. Graduation Processing

```python
def _issue_digital_diploma(self, graduate_info):
    diploma = {
        "credential_issuer": "https://credentials.university.edu",
        "credentials": [{
            "format": "jwt_vc_json",
            "types": ["VerifiableCredential", "EducationalCredential", "Diploma"],
            "credentialSubject": {
                "id": graduate_info["student_id"],
                "alumniOf": {
                    "name": "State University",
                    "identifier": "university.edu"
                },
                "degree": {
                    "type": graduate_info["degree_type"],
                    "name": graduate_info["degree_name"],
                    "field": graduate_info["major"]
                },
                "graduationDate": graduate_info["graduation_date"],
                "honors": graduate_info.get("honors"),
                "gpa": graduate_info.get("gpa")
            },
            "expirationDate": None  # Diplomas don't expire
        }]
    }

    # Send to graduate's registered email/phone
    deep_link = f"openid-credential-offer://?credential_offer={encode(diploma)}"
    send_graduation_notification(graduate_info["contact"], deep_link)
```

#### 2. Employment Verification

```
Job application system requests education verification
→ openid4vp://?request=<education_verification>
→ Candidate selects relevant diplomas/certificates
→ Employer instantly verifies educational credentials
→ Hiring decision made with verified information
```

## Financial Services KYC Credential

### Scenario

Bank issues Know Your Customer (KYC) credentials that can be reused across financial services to reduce onboarding friction.

### Implementation

#### 1. KYC Completion

```python
def _issue_kyc_credential(self, customer_info, verification_data):
    kyc_credential = {
        "credential_issuer": "https://identity.bank.com",
        "credentials": [{
            "format": "jwt_vc_json",
            "types": ["VerifiableCredential", "IdentityVerification", "KYCCredential"],
            "credentialSubject": {
                "id": customer_info["customer_id"],
                "verificationLevel": verification_data["level"],  # Basic, Enhanced, Premium
                "documentsVerified": verification_data["documents"],
                "biometricVerified": verification_data["biometric_check"],
                "addressVerified": verification_data["address_check"],
                "verificationDate": datetime.now().isoformat(),
                "verifier": {
                    "name": "Big Bank Corp",
                    "license": "BANK12345",
                    "jurisdiction": "US"
                }
            },
            "expirationDate": (datetime.now() + timedelta(days=365)).isoformat()
        }]
    }

    deep_link = f"openid-credential-offer://?credential_offer={encode(kyc_credential)}"
    send_kyc_completion_notice(customer_info["phone"], deep_link)
```

#### 2. Cross-Institution Verification

```
Customer opens account at new financial institution
→ openid4vp://?request=<kyc_verification>
→ Customer shares existing KYC credential
→ New institution verifies credential authenticity
→ Reduced onboarding time and compliance costs
```

## Government Identity Document

### Scenario

DMV issues digital driver's licenses that work alongside or replace physical licenses.

### Implementation

#### 1. License Renewal/Issuance

```python
def _issue_digital_drivers_license(self, license_holder_info):
    dl_credential = {
        "credential_issuer": "https://dmv.state.gov",
        "credentials": [{
            "format": "mso_mdoc",  # Mobile Document format for government IDs
            "doctype": "org.iso.18013.5.1.mDL",
            "credentialSubject": {
                "family_name": license_holder_info["last_name"],
                "given_name": license_holder_info["first_name"],
                "birth_date": license_holder_info["birth_date"],
                "license_number": license_holder_info["license_number"],
                "license_class": license_holder_info["license_class"],
                "restrictions": license_holder_info["restrictions"],
                "expiry_date": license_holder_info["expiry_date"],
                "issuing_authority": "State DMV",
                "portrait": license_holder_info["photo_hash"]
            }
        }]
    }

    # Generate deep link with mDoc credential
    deep_link = f"openid-credential-offer://?credential_offer={encode(dl_credential)}"
    send_license_ready_notification(license_holder_info["phone"], deep_link)
```

#### 2. Age Verification Scenarios

```
# Scenario A: Retail age verification
Liquor store requests age verification
→ openid4vp://?request=<age_over_21>
→ Customer authorizes sharing birth_date only (selective disclosure)
→ Store verifies customer is over 21 without seeing full license details

# Scenario B: TSA checkpoint
Airport security scans QR code
→ openid4vp://?request=<government_id_verification>
→ Traveler authorizes sharing full license details
→ TSA verifies government-issued credential authenticity
```

## Integration Benefits Summary

### For Organizations

- **Reduced IT overhead**: Automated credential distribution
- **Lower support costs**: Fewer manual credential imports
- **Better compliance**: Auditable credential lifecycles
- **Enhanced security**: Cryptographic credential verification
- **Cost savings**: Reduced physical credential production

### For End Users

- **Instant setup**: No manual credential entry
- **Better privacy**: Selective disclosure of information
- **Universal access**: Works across different apps and services
- **Reduced friction**: Seamless verification workflows
- **Permanent access**: Credentials stored in user's control

### Technical Advantages

- **Standardized protocols**: OID4VC compliance ensures interoperability
- **Secure communication**: App-to-app flows reduce attack surface
- **Error reduction**: Eliminates manual data entry mistakes
- **Future-proof**: Built on emerging W3C and IETF standards
- **Scalable architecture**: Supports high-volume credential operations

These examples demonstrate how deep linking transforms traditional identity and credential workflows into modern, user-friendly, and secure digital experiences.
