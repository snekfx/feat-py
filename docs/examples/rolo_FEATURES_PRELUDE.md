# FEATURES_PRELUDE.md - Module Export System

**Version**: v0.1.0
**Date**: 2025-09-15
**Tasks**: TASK-003 (2 Story Points)
**Status**: Complete ✅

## Overview

The Prelude module provides a curated, single-import API surface for all rolo functionality. Following RSB MODULE_SPEC patterns, it exports essential functions, types, and macros from all modules in a coherent, discoverable interface.

## Core Features

### 1. Layout Functionality
- **Functions**: `format_columns`, `format_table`, `format_list`
- **Configuration**: `LayoutConfig` struct with sensible defaults
- **Flexibility**: Multiple formatting modes for different text structures

### 2. Width Calculation
- **Display Width**: `get_display_width` with Unicode/ANSI awareness
- **Terminal Width**: `get_terminal_width` with system detection
- **Validation**: `validate_width` with range checking (10-200)

### 3. Error Handling
- **Width Errors**: `WidthError` for calculation and validation failures
- **Layout Errors**: `LayoutError` for formatting failures
- **Comprehensive**: Typed errors with descriptive messages

### 4. Configuration Macros
- **layout_config!**: Flexible macro for creating layout configurations
- **Parameter Variations**: Support for width-only, width+gap, width+gap+padding

## Usage Patterns

### Single Import
```rust
use rolo::prelude::*;

// All functionality immediately available
let width = get_terminal_width();
let config = layout_config!(width, gap: 2);
let result = format_columns("text", 2)?;
```

### Selective Imports
```rust
use rolo::prelude::{get_display_width, LayoutConfig, WidthError};

// Only import what you need
let width = get_display_width("text")?;
```

### Error Handling
```rust
use rolo::prelude::*;

match get_display_width("text") {
    Ok(width) => println!("Width: {}", width),
    Err(WidthError::InvalidInput(msg)) => eprintln!("Input error: {}", msg),
    Err(e) => eprintln!("Error: {}", e),
}
```

## API Reference

### Layout Functions

#### `format_columns(text: &str, cols: usize) -> Result<String, LayoutError>`
Format text into specified number of columns.
- **Parameters**: Input text, number of columns
- **Returns**: Formatted string or layout error
- **Status**: Placeholder implementation (TASK-007)

#### `format_table(text: &str, delimiter: &str) -> Result<String, LayoutError>`
Format text as table with specified delimiter.
- **Parameters**: Input text, column delimiter
- **Returns**: Formatted table or layout error
- **Status**: Placeholder implementation (TASK-008)

#### `format_list(text: &str) -> Result<String, LayoutError>`
Format text as bulleted list.
- **Parameters**: Input text
- **Returns**: Formatted list or layout error
- **Status**: Placeholder implementation (TASK-009)

### Width Functions

#### `get_terminal_width() -> usize`
Returns current terminal width in columns.
- **Feature-aware**: Full functionality with `width-boxy`, fallback without
- **System detection**: `tput cols`, `stty size`, environment variables
- **Minimum**: Always returns at least 10 columns

#### `get_display_width(text: &str) -> Result<usize, WidthError>`
Calculate display width considering Unicode and ANSI sequences.
- **ANSI-aware**: Strips escape sequences before calculation
- **Unicode-safe**: Proper width calculation for wide characters
- **Fallback**: Character count when `width-boxy` disabled

#### `validate_width(width_str: &str) -> Result<usize, WidthError>`
Parse and validate width input string.
- **Range**: 10-200 columns (matching terminal standards)
- **Parsing**: String to usize conversion with error handling
- **Descriptive errors**: Clear messages for invalid input

### Configuration Types

#### `LayoutConfig`
```rust
pub struct LayoutConfig {
    pub width: usize,   // Terminal/desired width
    pub gap: usize,     // Gap between columns
    pub padding: usize, // Padding around content
}
```

**Default values**: width=80, gap=2, padding=1

### Macros

#### `layout_config!`
Flexible configuration macro with multiple forms:

```rust
// Width only (gap=2, padding=1)
let config = layout_config!(100);

// Width + gap (padding=1)
let config = layout_config!(120, gap: 4);

// Width + gap + padding
let config = layout_config!(140, gap: 3, padding: 2);
```

### Error Types

#### `WidthError`
```rust
pub enum WidthError {
    InvalidInput(String),           // Malformed input
    CalculationError(String),       // Width calculation failed
    InvalidRange(usize, usize, usize), // Value outside 10-200
    TerminalError(String),          // Terminal access failed
}
```

#### `LayoutError`
```rust
pub enum LayoutError {
    InvalidColumnCount(usize),      // Invalid column specification
    FormattingError(String),        // Text formatting failed
}
```

## Module Structure

### RSB MODULE_SPEC Compliance
```
src/lib.rs
└── prelude module
    ├── Layout exports (format_*, LayoutConfig)
    ├── Width exports (get_*, validate_width)
    ├── Error exports (WidthError, LayoutError)
    └── Macro exports (layout_config!)
```

### Re-export Strategy
- **utils.rs**: Public functions from each module
- **error.rs**: Typed error enums for comprehensive handling
- **macros.rs**: Module-owned macros via re-export chain
- **Convenience**: Root-level `pub use prelude::*` for easy access

## Testing Strategy

### Test Categories
- **Prelude Tests**: Dedicated test suite for export verification
- **Integration Tests**: Cross-module functionality testing
- **Error Tests**: Error type accessibility and usage

### Test Coverage
```rust
// 5 comprehensive prelude tests
test_prelude_layout_exports()     // Layout function access
test_prelude_width_exports()      // Width function access
test_prelude_error_exports()      // Error type availability
test_prelude_macro_exports()      // Macro functionality
test_prelude_comprehensive()      // End-to-end integration
```

## Design Principles

### Discoverability
- **Single Import**: `use rolo::prelude::*` provides full functionality
- **Logical Grouping**: Related functions grouped by purpose
- **Consistent Naming**: Clear, descriptive function names

### Flexibility
- **Selective Import**: Import only needed items if desired
- **Error Handling**: Comprehensive error types available
- **Feature Awareness**: Graceful degradation without optional features

### Future Compatibility
- **Extensible**: Easy to add new modules to prelude
- **Stable API**: Core exports remain consistent across versions
- **Semantic Versioning**: Breaking changes only in major versions

## Integration Points

### CLI Module (Future)
Will add CLI argument parsing and command dispatch to prelude.

### Stream Module (Future)
Will add streaming text processing functions to prelude.

### Extension Pattern
New modules follow the same pattern:
1. Implement functionality in `mod/utils.rs`
2. Add exports to `mod/mod.rs`
3. Include in `lib.rs` prelude
4. Add comprehensive tests

## Performance

### Import Cost
- **Zero runtime cost**: Re-exports are compile-time only
- **Selective compilation**: Feature flags prevent unused code
- **Optimal binary size**: Only used functions included in final binary

### API Efficiency
- **Direct access**: No indirection through prelude
- **Type safety**: Full type checking at compile time
- **IDE support**: Complete autocomplete and documentation

---

**RSB Compliance**: ✅ MODULE_SPEC prelude patterns, ✅ Curated exports, ✅ Error handling
**Integration**: ✅ Cross-module access, ✅ Macro re-exports, ✅ Feature awareness
**Quality**: ✅ 12/12 tests passing, ✅ Comprehensive API, ✅ Future extensibility