# Stacked Credentials Demo Data

## Overview

Added comprehensive example data to demonstrate the grouped credentials stacking feature. The app now shows multiple credentials from the same issuers, displaying them as interactive stacked cards.

## Demo Credential Groups

### 1. **Stanford University** (2 Credentials - Stacked)

- **University Degree Credential**
  - Bachelor of Computer Science
  - Issued: 2023-05-15
  - Expires: 2028-05-15

- **Professional Certificate**
  - Advanced Machine Learning Certification
  - Issued: 2024-01-20
  - Expires: 2027-01-20

### 2. **TechCorp Inc** (3 Credentials - Stacked)

- **Employee Credential**
  - Senior Developer in Engineering
  - Employee ID: EMP001
  - Issued: 2023-08-01
  - Expires: 2025-08-01

- **Access Credential**
  - Level 3 Access (Building A, Lab 1, Conference Rooms)
  - Issued: 2023-08-01
  - Expires: 2025-08-01

- **Training Certificate**
  - Security Awareness Training (98% score)
  - Issued: 2024-03-15
  - Expires: 2025-03-15

### 3. **Department of Health** (1 Credential - Single)

- **Health Credential**
  - COVID-19 Vaccination Record (3 doses)
  - Last dose: 2023-09-20
  - Expires: 2025-09-20

### 4. **State DMV** (2 mDoc Credentials - Stacked)

- **Mobile Driver's License (mDL)**
  - Document: DL123456789
  - Issued: 2023-06-01
  - Expires: 2028-06-01

- **Mobile ID (mID)**
  - Document: ID987654321
  - Issued: 2024-01-15
  - Expires: 2029-01-15

### 5. **US State Department** (1 mDoc Credential - Single)

- **Mobile Passport**
  - Document: P123456789
  - Nationality: US
  - Issued: 2023-03-10
  - Expires: 2033-03-10

## User Experience Demonstrations

### Stack Behaviors:

1. **Single Credentials**: Department of Health and US State Department credentials display as individual cards

2. **Stacked Credentials**: Stanford University, TechCorp Inc, and State DMV credentials show as:
   - Collapsed view with stack indicator (layers icon + count)
   - Visual depth effect with offset shadow cards
   - Issuer name clearly displayed
   - Tap to expand or use expand/collapse button

3. **Expanded Stacks**: When expanded, users can:
   - Horizontally swipe through individual credentials
   - See page indicators at the bottom
   - Tap individual credentials for detail view
   - Perform credential-specific actions (share, verify, present)

### Visual Indicators:

- **Stack Badge**: Shows credential count (e.g., "2", "3")
- **Depth Effect**: Layered card appearance when collapsed
- **Page Dots**: Current position indicator when expanded
- **Consistent Sizing**: All credentials maintain same card dimensions

## Technical Implementation Details

### Data Characteristics:

- **Realistic Dates**: All credentials have proper issuance and expiration dates
- **Varied Content**: Different credential types showcase various use cases
- **Expiration Handling**: Only active (non-expired) credentials are shown
- **Mixed Types**: Both Verifiable Credentials and mDoc credentials included

### Grouping Logic:

- VerifiableCredentials grouped by `issuerName` property
- mDoc credentials grouped by `issuingAuthority` property
- Groups sorted alphabetically by issuer name
- Expired credentials automatically filtered out

### Benefits for Testing:

1. **Multiple Scenarios**: Shows both single and stacked credential behaviors
2. **Real-world Data**: Realistic credential types and information
3. **Visual Validation**: Easy to verify grouping and stacking works correctly
4. **Interaction Testing**: Multiple credentials per stack enable testing of swipe navigation
5. **Edge Cases**: Mix of short and long issuer names, various credential types

The demo data provides a comprehensive showcase of the stacked credentials feature, demonstrating how the UI gracefully handles both single credentials and groups of multiple credentials from the same issuer.
