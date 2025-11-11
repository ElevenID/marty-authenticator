# Android Code Structure

This document describes the refactored Android code structure for better maintainability and separation of concerns.

## Overview

The MainActivity class has been split into several focused components to improve code organization and maintainability:

## File Structure

```
src/main/kotlin/it/netknights/piauthenticator/
├── MainActivity.kt (removed - handled by flavor)
├── channels/
│   └── ChannelRegistry.kt
├── config/
│   └── SecurityConfig.kt
└── handlers/
    └── FileHandler.kt
```

```
src/netknights/kotlin/it/netknights/piauthenticator/
└── MainActivity.kt (flavor-specific)
```

## Components

### 1. MainActivity.kt (NetKnights flavor)

- **Responsibility**: Main entry point for the Flutter application
- **Key Functions**:
  - Configure Flutter engine
  - Register plugins
  - Apply security settings
  - Initialize method channels
  - Handle cleanup

### 2. ChannelRegistry.kt

- **Responsibility**: Centralized management of all Flutter method channels
- **Key Functions**:
  - Register method channels with handlers
  - Provide clean separation of channel logic
  - Handle channel cleanup to prevent memory leaks

### 3. SecurityConfig.kt

- **Responsibility**: Security configurations for the application
- **Key Functions**:
  - Apply FLAG_SECURE to prevent screenshots
  - Centralize all security-related settings

### 4. FileHandler.kt

- **Responsibility**: Handle file reading operations
- **Key Functions**:
  - Read JSON data from files using ObjectInputStream
  - Handle file operation errors gracefully
  - Provide type-safe file reading methods

## Benefits of This Structure

1. **Separation of Concerns**: Each class has a single, well-defined responsibility
2. **Maintainability**: Easier to locate and modify specific functionality
3. **Testability**: Individual components can be tested in isolation
4. **Reusability**: Components like SecurityConfig can be reused across different activities
5. **Memory Management**: Proper cleanup prevents memory leaks

## Usage

The refactored code maintains the same external interface, so no changes are required in the Flutter/Dart code. The functionality remains identical:

- File reading through the `readValueFromFile` channel
- Security settings (FLAG_SECURE) are still applied
- Plugin registration works as before

## Future Extensions

This structure makes it easy to add new functionality:

1. **New Handlers**: Add new handler classes in the `handlers/` package
2. **New Channels**: Register them in `ChannelRegistry`
3. **New Security Features**: Add them to `SecurityConfig`
4. **Configuration**: Add app configuration classes in the `config/` package

## Migration Notes

- The original MainActivity functionality is preserved
- No breaking changes to the Flutter interface
- All existing method channels continue to work
- Security settings are still applied
- Memory management has been improved with proper cleanup
