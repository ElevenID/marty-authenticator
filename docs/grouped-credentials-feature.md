# Grouped Credentials Feature Implementation

## Overview

Implemented a credential grouping system that organizes active (non-expired) credentials by their issuer, displaying them as stackable cards with horizontal scrolling capability when expanded.

## New Components

### 1. `CredentialGroup` Class

**Location**: `lib/views/main_view/main_view_widgets/card_widgets/grouped_credential_stack.dart`

**Purpose**: Data structure to hold credentials from the same issuer

- Groups both VerifiableCredentials and MDocCredentials by issuer name
- Provides utility methods: `totalCount`, `hasSingle`, `hasMultiple`, `allCredentials`, `primaryCredential`

### 2. `GroupedCredentialStack` Widget

**Location**: `lib/views/main_view/main_view_widgets/card_widgets/grouped_credential_stack.dart`

**Features**:

- **Single Credential**: Displays as regular credential card
- **Multiple Credentials**: Shows as a visual stack with:
  - Stack indicator showing credential count
  - Issuer name header
  - Expand/collapse functionality
  - Horizontal PageView for scrolling through credentials
  - Page indicators when expanded

**Visual Design**:

- **Collapsed**: Stacked cards with offset shadows for depth effect
- **Expanded**: Full-width horizontal scroll with page indicators
- **Stack Header**: Shows layers icon + count + issuer name + expand button

## Updated Components

### 3. `CredentialsState` (Enhanced)

**Location**: `lib/utils/riverpod/providers/credentials_provider.dart`

**New Features**:

- `groupedCredentials` getter that groups active credentials by issuer
- `_isMDocExpired()` helper method for mDoc expiration checking
- Automatic filtering of expired credentials

**Grouping Logic**:

- Groups VerifiableCredentials by `issuerName` property
- Groups MDocCredentials by `issuingAuthority` property
- Only includes non-expired credentials
- Sorts groups alphabetically by issuer name

### 4. `CredentialsList` (Refactored)

**Location**: `lib/views/main_view/main_view_widgets/credentials_list.dart`

**Changes**:

- Replaced individual VC/mDoc sections with single grouped section
- Uses `GroupedCredentialStack` widgets instead of individual cards
- Simplified state management (removed unused `_expandedCredentialId`)
- Updated age verification function signature

## User Experience

### Stack Interaction Flow:

1. **Single Credential**: Behaves like existing individual cards
2. **Multiple Credentials**:
   - Shows as stacked cards with visual depth
   - Displays issuer name and credential count
   - Tap stack or expand button to reveal individual cards
   - Horizontal swipe to navigate between credentials
   - Page indicators show current position
   - Tap individual credentials to view details

### Visual Indicators:

- **Stack Icon**: Layers icon with credential count badge
- **Depth Effect**: Offset cards create 3D stack appearance
- **Page Dots**: Show current credential position when expanded
- **Issuer Header**: Clear identification of credential source

## Benefits

1. **Organization**: Credentials naturally grouped by issuer reduces visual clutter
2. **Scalability**: Handles multiple credentials from same issuer elegantly
3. **Discovery**: Easy to find credentials from specific issuers
4. **Consistency**: Maintains same interaction patterns as individual cards
5. **Space Efficiency**: Stacked view saves vertical space

## Technical Implementation

### Key Design Patterns:

- **Composition**: GroupedCredentialStack wraps existing card widgets
- **State Management**: Leverages existing Riverpod providers
- **Polymorphism**: Handles both VC and mDoc types transparently
- **Responsive**: Adapts to single vs multiple credential scenarios

### Performance Considerations:

- Lazy grouping via getter (computed on demand)
- Efficient filtering of expired credentials
- PageView uses builder pattern for memory efficiency
- Maintains existing card widget optimizations

The implementation maintains backward compatibility while adding the new grouping functionality, ensuring a smooth user experience for both single and multiple credentials per issuer.
