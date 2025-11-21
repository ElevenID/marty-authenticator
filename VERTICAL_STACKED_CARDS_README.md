# Vertical Stacked Cards Implementation

This document describes the new vertical stacked cards feature implemented in the Marty Authenticator wallet interface, inspired by the iOS Wallet app's stacked cards design.

## Overview

The vertical stacked cards feature provides a visually appealing way to display multiple credentials from the same issuer, using a stacking effect similar to the iOS Wallet app. Cards are vertically offset to create the appearance of a stack, with interactive expansion and selection capabilities.

## Implementation Details

### Core Components

#### 1. VerticalStack Widget (`lib/widgets/vertical_stack.dart`)

A simple widget that creates the vertical stacking effect using `Transform.translate`:

```dart
Widget build(BuildContext context) {
  return Transform.translate(
    offset: Offset(0, -dy * order),  // Key: vertical offset calculation
    child: child,
  );
}
```

- `dy`: Vertical spacing between cards (typically 20px)
- `order`: Stack position (0 = top, higher = lower in stack)
- Creates the stacked appearance by translating each card vertically

#### 2. VerticalStackedCredentials Widget (`lib/views/main_view/main_view_widgets/card_widgets/vertical_stacked_credentials.dart`)

The main widget that orchestrates the stacked cards display:

**Features:**

- **Visual Stacking**: Cards are offset vertically using the VerticalStack widget
- **Interactive Expansion**: Tap cards to expand and reveal more details
- **Animation**: Smooth transitions between collapsed and expanded states
- **Touch Handling**: Intelligent tap handling for expansion and action triggering
- **Dynamic Spacing**: Cards adjust spacing when expanded to prevent overlap

**Key Properties:**

- `stackSpacing: 20.0`: Base vertical spacing between cards
- Animated expansion with `AnimationController` and `CurvedAnimation`
- Stack height calculation: `200 + (credentials.length - 1) * stackSpacing`

#### 3. Enhanced CredentialsList (`lib/views/main_view/main_view_widgets/credentials_list.dart`)

Updated to support both horizontal (original) and vertical stacking modes:

**Toggle Feature:**

- Toggle button in the UI to switch between stacking styles
- `useVerticalStacking` boolean controls which widget to use
- Applies vertical stacking only to groups with multiple credentials

### Usage

The feature is automatically available in the main wallet view:

1. **Single Credentials**: Display normally without stacking
2. **Multiple Credentials**: Use vertical stacking when enabled
3. **Toggle Control**: Users can switch between horizontal and vertical stacking modes

### Visual Design

#### Stacking Effect

- Cards are vertically offset by 20px intervals
- Each card maintains a subtle shadow for depth
- Cards animate smoothly during interactions

#### Interaction States

- **Collapsed**: All cards visible with stacking effect
- **Expanding**: Selected card scales slightly (1.02x) and animates
- **Expanded**: Selected card fully visible, others pushed down
- **Action Ready**: Tap expanded card to trigger main action

#### Color and Theming

- Uses existing credential card themes and gradients
- Maintains visual consistency with the rest of the app
- Supports both light and dark modes

## Integration with Existing Code

### Compatibility

- Fully backward compatible with existing credential display
- Non-breaking integration with current `GroupedCredentialStack`
- Preserves all existing functionality (share, verify, present, etc.)

### Conditional Usage

```dart
child: useVerticalStacking && group.hasMultiple
    ? VerticalStackedCredentials(...)
    : GroupedCredentialStack(...),
```

### Benefits

1. **Improved Visual Hierarchy**: Better organization of multiple credentials
2. **Space Efficiency**: More compact display for credential groups
3. **Enhanced UX**: Familiar iOS Wallet-style interaction patterns
4. **Flexible Design**: Easy to toggle between stacking modes

## Future Enhancements

### Potential Improvements

1. **Persistence**: Save user's stacking preference
2. **Gestures**: Add swipe gestures for card navigation
3. **Animation Customization**: Allow different animation styles
4. **Auto-Stacking**: Intelligently choose stacking mode based on content
5. **Accessibility**: Enhanced screen reader support for stacked cards

### Performance Considerations

- Efficient rendering using `Stack` and `Transform.translate`
- Minimal widget rebuilds during animations
- Optimized for large numbers of credentials

## Code Example

```dart
// Simple vertical stack usage
VerticalStack(
  dy: 20.0,        // 20px spacing
  order: 0,        // Top card
  child: MyCard(),
)

// Multiple stacked cards
for (int i = 0; i < cards.length; i++)
  VerticalStack(
    dy: 20.0,
    order: i,
    child: cards[i],
  )
```

## Testing

The implementation has been tested for:

- ✅ Compilation without errors
- ✅ Flutter analyze passes
- ✅ Visual consistency across platforms
- ✅ Animation smoothness
- ✅ Touch interaction accuracy

## References

This implementation was inspired by the [Flutter Intro Wallet UI](https://github.com/minhosong88/flutter_intro_wallet_UI) tutorial, particularly the vertical stacking technique using `Transform.translate` with offset calculations.
