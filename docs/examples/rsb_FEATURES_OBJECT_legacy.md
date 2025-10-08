# RSB Feature: OBJECT

> **Heads up (2025-10-07):** This document is being rewritten. The concrete `Object<T>`
> implementation now lives in `src/object/core.rs` and implements the shared
> `object::ObjectLike` trait. Legacy references in this file describe the pre-refactor
> design and will be cleaned up in a follow-up pass.

## Overview

RSB now uses the external `oodx/object` foundation library with RSB-specific extensions for configuration and dynamic data management. This integration provides a clean separation between the universal Object foundation (zero dependencies, dependency injection) and RSB-specific conveniences (global store integration, RSB shapes).

**Key Benefits**:
- **External Foundation**: Standalone `oodx/object` library shared across projects
- **Dependency Injection**: ContextStore trait for flexible storage backends
- **RSB Integration**: Convenient wrappers for global variable store
- **Dual Implementation**: External (new, preferred) + Legacy (deprecated, backward compat)
- **96 Tests Passing**: Comprehensive validation of both implementations

## Architecture

The Object feature follows a layered architecture:

```
┌─────────────────────────────────────────────┐
│  oodx/object (External Foundation)          │
│  - Object<T>, ContextStore trait            │
│  - GenericShape, JSONShape                  │
│  - Zero RSB dependencies                    │
└─────────────────────────────────────────────┘
                    ↓ (dependency)
┌─────────────────────────────────────────────┐
│  RSB (This Project)                         │
│  - GlobalStore implements ContextStore      │
│  - RSB shapes (Hub/Inf/RSB)                 │
│  - Extension functions (from_global)        │
│  - Legacy object (temporary, deprecated)    │
└─────────────────────────────────────────────┘
                    ↓ (used by)
┌─────────────────────────────────────────────┐
│  Applications (meteor, etc.)                │
│  - Can use oodx/object directly             │
│  - Or use RSB's convenient wrappers         │
└─────────────────────────────────────────────┘
```

### Component Breakdown

1. **External Object Foundation** (`oodx/object`)
   - Core `Object<T>` type with phantom type parameters
   - `ContextStore` trait for storage abstraction
   - Foundation shapes: `GenericShape`, `JSONShape`
   - Reference implementation: `InMemoryStore`

2. **RSB-Specific Layers** (this project)
   - `ContextStore` implementation for RSB's `Global` store
   - RSB shapes: `HubShape`, `InfShape`, `RSBShape`
   - Convenience functions: `object_from_global()`, `object_sync_to_global()`
   - Legacy Object (deprecated, for backward compatibility)

3. **Application Layer**
   - Use external Object with RSB extensions
   - Or use legacy Object (will be removed in Phase 2)

## Core Concepts

### External Object (Preferred)

The external `Object<T>` is the new, recommended implementation from `oodx/object`:

```rust
use object::Object;
use rsb::object::rsb_extensions::{object_from_global, object_sync_to_global};

// Create new object
let mut config: Object = Object::new("config");
config.set("host", "localhost");

// Load from RSB global store
let hub: Object = object_from_global("hub");

// Sync to RSB global store
object_sync_to_global(&config);
```

**Key Features**:
- Generic `Object<T>` with phantom type for shape hinting
- String-based storage (all values are `&str`)
- Dependency injection via `ContextStore` trait
- No hard-coded dependencies on RSB globals

### ContextStore Trait

The `ContextStore` trait provides storage abstraction for Object:

```rust
pub trait ContextStore {
    /// Load all variables with namespace prefix
    fn load(&self, prefix: &str) -> HashMap<String, String>;

    /// Save all variables with namespace prefix
    fn save(&mut self, prefix: &str, data: &HashMap<String, String>);
}
```

**RSB Implementation**:
```rust
// In src/global/store.rs
impl ContextStore for Global {
    fn load(&self, prefix: &str) -> HashMap<String, String> {
        // Load hub_key1, hub_key2 -> {"key1": "...", "key2": "..."}
        let namespace_prefix = format!("{}_", prefix);
        self.vars
            .iter()
            .filter_map(|(k, v)| {
                k.strip_prefix(&namespace_prefix)
                    .map(|stripped| (stripped.to_string(), v.clone()))
            })
            .collect()
    }

    fn save(&mut self, prefix: &str, data: &HashMap<String, String>) {
        // Save {"key1": "val"} -> hub_key1 = "val"
        for (key, value) in data {
            let full_key = format!("{}_{}", prefix, key);
            self.vars.insert(full_key, value.clone());
        }
    }
}
```

### RSB-Specific Shapes

RSB defines three shape types for compile-time documentation:

```rust
// In src/object/shapes.rs

/// Hub framework configuration shape
pub struct HubShape;

/// Infrastructure metadata shape
pub struct InfShape;

/// RSB framework settings shape
pub struct RSBShape;

// Type aliases for convenience
pub type HubConfig = Object<HubShape>;
pub type InfConfig = Object<InfShape>;
pub type RSBConfig = Object<RSBShape>;
```

**Usage Example**:
```rust
use rsb::object::{HubConfig, InfConfig, RSBConfig};
use rsb::object::rsb_extensions::object_from_global;

// Function signatures document expected shape
fn configure_hub(config: &HubConfig) {
    let api_url = config.get("api_url");
    // Reader knows this is hub configuration
}

// Load from global store
let hub: HubConfig = object_from_global("hub");
```

### RSB Convenience Functions

Since we can't add inherent impl to external types, RSB provides free functions:

```rust
// In src/object/rsb_extensions.rs

/// Load Object from RSB global store
pub fn object_from_global<T>(namespace: impl Into<String>) -> Object<T> {
    let global = crate::global::GLOBAL.lock().unwrap();
    Object::from_store(&namespace.into(), &*global)
}

/// Sync Object to RSB global store
pub fn object_sync_to_global<T>(obj: &Object<T>) {
    let mut global = crate::global::GLOBAL.lock().unwrap();
    obj.sync_to_store(&mut *global);
}
```

### Legacy Object (Deprecated)

The original RSB Object implementation is still available for backward compatibility:

```rust
// Legacy usage (will be removed in Phase 2)
use rsb::object::Object;  // This is the old implementation

let hub = Object::<HubShape>::from_global("hub");
hub.sync_to_global();
```

**Deprecation Notice**: This implementation will be removed once all RSB code migrates to the external Object.

## API Reference

### Using External Object

#### Creation
```rust
use object::Object;
use rsb::object::rsb_extensions::{object_from_global, object_sync_to_global};

// Create new object
let obj: Object = Object::new("namespace");

// Load from RSB global store
let obj: Object = object_from_global("namespace");
```

#### Basic Operations
```rust
// Set values
obj.set("key", "value");

// Get values
let value = obj.get("key");              // Returns &str or ""
let value = obj.get_or("key", "default"); // With default

// Check existence
if obj.has("key") { /* ... */ }
```

#### Storage Integration
```rust
// Sync to RSB global store
object_sync_to_global(&obj);

// Load from RSB global store
let obj: Object = object_from_global("namespace");
```

#### Direct ContextStore Usage
```rust
use object::Object;
use object::store::ContextStore;
use rsb::global::GLOBAL;

// Load using ContextStore directly
let global = GLOBAL.lock().unwrap();
let obj: Object = Object::from_store("namespace", &*global);

// Sync using ContextStore directly
drop(global);  // Release read lock
let mut global = GLOBAL.lock().unwrap();
obj.sync_to_store(&mut *global);
```

### ContextStore Trait

Implement for custom storage backends:

```rust
use object::store::ContextStore;
use std::collections::HashMap;

struct MyStore {
    data: HashMap<String, HashMap<String, String>>,
}

impl ContextStore for MyStore {
    fn load(&self, prefix: &str) -> HashMap<String, String> {
        self.data.get(prefix).cloned().unwrap_or_default()
    }

    fn save(&mut self, prefix: &str, data: &HashMap<String, String>) {
        self.data.insert(prefix.to_string(), data.clone());
    }
}
```

### RSB Shapes and Type Aliases

```rust
use rsb::object::{HubShape, InfShape, RSBShape};
use rsb::object::{HubConfig, InfConfig, RSBConfig};
use rsb::object::rsb_extensions::object_from_global;

// Load with shape types
let hub: HubConfig = object_from_global("hub");
let inf: InfConfig = object_from_global("inf");
let rsb: RSBConfig = object_from_global("rsb");

// Or use shape markers directly
let config: Object<HubShape> = object_from_global("hub");
```

### RSB Extension Functions

#### object_from_global()

Load Object from RSB global variable store:

```rust
use rsb::object::rsb_extensions::object_from_global;

// Load from global store with "config" namespace
// If global has: config_host="localhost", config_port="8080"
let config: Object = object_from_global("config");

assert_eq!(config.get("host"), "localhost");
assert_eq!(config.get("port"), "8080");
```

#### object_sync_to_global()

Sync Object to RSB global variable store:

```rust
use rsb::object::rsb_extensions::object_sync_to_global;

let mut obj: Object = Object::new("config");
obj.set("host", "localhost");
obj.set("port", "8080");

object_sync_to_global(&obj);

// Now global has: config_host="localhost", config_port="8080"
assert_eq!(rsb::global::get_var("config_host"), "localhost");
assert_eq!(rsb::global::get_var("config_port"), "8080");
```

### Legacy Object API (Deprecated)

The legacy Object is temporarily available for backward compatibility:

```rust
use rsb::object::Object;

// Creation
let obj = Object::new("namespace");
let obj = Object::<HubShape>::from_global("hub");

// Access
let value = obj["key"];              // Bracket notation
let value = obj.get("key");
let value = obj.get_or("key", "default");

// Modification
obj.set("key", "value");

// Global sync
obj.sync_to_global();

// Macros (legacy)
let hub = get_hub!();    // Returns Object<HubShape>
let inf = get_inf!();
let rsb = get_rsb!();
```

**Migration Note**: Replace legacy usage with external Object + rsb_extensions functions.

## Usage Examples

### Creating Objects with External Object

```rust
use object::Object;
use rsb::object::rsb_extensions::{object_from_global, object_sync_to_global};

// Create empty object
let mut config: Object = Object::new("app");
config.set("version", "1.0.0");
config.set("debug", "true");

// Sync to global store
object_sync_to_global(&config);

// Later, load back
let config: Object = object_from_global("app");
assert_eq!(config.get("version"), "1.0.0");
```

### Loading from Global Store

```rust
use rsb::object::HubConfig;
use rsb::object::rsb_extensions::object_from_global;

// If global store has:
// hub_api_url = "https://api.example.com"
// hub_timeout = "30"

let hub: HubConfig = object_from_global("hub");
assert_eq!(hub.get("api_url"), "https://api.example.com");
assert_eq!(hub.get("timeout"), "30");
```

### Using RSB Shapes

```rust
use object::Object;
use rsb::object::{HubShape, InfShape, RSBShape};
use rsb::object::rsb_extensions::object_from_global;

// Function signatures document expected shape
fn configure_api(config: &Object<HubShape>) {
    let url = config.get("api_url");
    let timeout = config.get("timeout");
    // Reader knows this is hub configuration
}

fn process_metadata(metadata: &Object<InfShape>) {
    let team = metadata.get("team");
    let version = metadata.get("version");
    // Reader knows this is infrastructure metadata
}

// Load and use
let hub: Object<HubShape> = object_from_global("hub");
configure_api(&hub);

let inf: Object<InfShape> = object_from_global("inf");
process_metadata(&inf);
```

### ContextStore Roundtrip

```rust
use object::Object;
use object::store::ContextStore;

// Using RSB's global store directly
let mut obj: Object = Object::new("config");
obj.set("host", "localhost");
obj.set("port", "8080");

// Sync to store
{
    let mut global = rsb::global::GLOBAL.lock().unwrap();
    obj.sync_to_store(&mut *global);
}

// Load back
let obj2: Object = {
    let global = rsb::global::GLOBAL.lock().unwrap();
    Object::from_store("config", &*global)
};

assert_eq!(obj2.get("host"), "localhost");
assert_eq!(obj2.get("port"), "8080");
```

### Complete Configuration Example

```rust
use object::Object;
use rsb::object::{HubConfig, InfConfig};
use rsb::object::rsb_extensions::{object_from_global, object_sync_to_global};

// Create app configuration
let mut app_config: Object = Object::new("app");
app_config.set("name", "MyApp");
app_config.set("version", "1.0.0");
app_config.set("debug", "false");
object_sync_to_global(&app_config);

// Load system configurations
let hub: HubConfig = object_from_global("hub");
let inf: InfConfig = object_from_global("inf");

// Use configurations
println!("App: {} v{}",
    app_config.get("name"),
    app_config.get("version"));
println!("Hub API: {}", hub.get("api_url"));
println!("Team: {}", inf.get("team"));
```

## Migration Guide

### From Legacy to External Object

#### Before (Legacy)
```rust
use rsb::object::Object;

let hub = Object::<HubShape>::from_global("hub");
hub.sync_to_global();

let value = hub["key"];
```

#### After (External)
```rust
use object::Object;
use rsb::object::HubShape;
use rsb::object::rsb_extensions::{object_from_global, object_sync_to_global};

let hub: Object<HubShape> = object_from_global("hub");
object_sync_to_global(&hub);

let value = hub.get("key");
```

#### Key Differences

1. **Imports**: Use `object::Object` instead of `rsb::object::Object`
2. **Loading**: Use `object_from_global()` instead of `Object::from_global()`
3. **Syncing**: Use `object_sync_to_global()` instead of `obj.sync_to_global()`
4. **Access**: Use `obj.get("key")` instead of `obj["key"]` (bracket notation not in external)

#### Migration Checklist

- [ ] Replace `use rsb::object::Object` with `use object::Object`
- [ ] Add `use rsb::object::rsb_extensions::*` for convenience functions
- [ ] Replace `Object::from_global()` with `object_from_global()`
- [ ] Replace `obj.sync_to_global()` with `object_sync_to_global(&obj)`
- [ ] Replace bracket notation `obj["key"]` with `obj.get("key")`
- [ ] Update shape type imports to use `rsb::object::{HubShape, InfShape, RSBShape}`
- [ ] Run tests to verify migration

#### Gradual Migration Strategy

You can migrate incrementally:

1. **Start with new code**: Use external Object for all new features
2. **Migrate modules one-by-one**: Convert existing modules as you touch them
3. **Keep tests passing**: Run full test suite after each module migration
4. **Final cleanup**: Once all code uses external Object, remove legacy implementation

## Testing

### Test Coverage Summary

**Total Tests**: 96 (91 original + 5 new)

**External Object Tests** (in `oodx/object` repo):
- 84 comprehensive unit tests
- Object creation, manipulation, storage roundtrips
- ContextStore trait implementations
- Shape type conversions
- All edge cases covered

**RSB Integration Tests**:
- 5 ContextStore implementation tests (`src/global/store.rs`)
  - `test_global_contextstore_load`
  - `test_global_contextstore_save`
  - `test_global_contextstore_roundtrip`
  - `test_global_contextstore_empty_prefix`
  - `test_global_contextstore_no_matches`

- 3 RSB extensions tests (`src/object/rsb_extensions.rs`)
  - `test_from_global_free_function`
  - `test_sync_to_global_free_function`
  - `test_roundtrip_with_free_functions`

- 91 legacy Object tests (for backward compatibility)

### Running Tests

```bash
# Run all RSB tests
cargo test

# Run only object-related tests
cargo test object

# Run only external object integration tests
cargo test --test sanity object
cargo test --test uat object

# Run with features
cargo test --features object
```

### Example Test

```rust
use object::Object;
use rsb::object::rsb_extensions::{object_from_global, object_sync_to_global};

#[test]
fn test_external_object_roundtrip() {
    // Create and populate
    let mut obj1: Object = Object::new("test");
    obj1.set("host", "localhost");
    obj1.set("port", "8080");

    // Sync to global
    object_sync_to_global(&obj1);

    // Load back
    let obj2: Object = object_from_global("test");

    // Verify
    assert_eq!(obj2.get("host"), "localhost");
    assert_eq!(obj2.get("port"), "8080");
    assert_eq!(obj2.len(), 2);
}
```

## Module Status

### Current State

**Implementation**: Dual implementation strategy
- **External Object** (new, preferred): Available via `rsb::object::ExternalObject` and extension functions
- **Legacy Object** (old, deprecated): Default export for backward compatibility

**Test Status**: 96 tests passing
- External object foundation: 84 tests
- RSB integration: 5 ContextStore + 3 extensions tests
- Legacy compatibility: 91 tests

**Feature Flag**: External object available with `object` feature (enabled by default in Cargo.toml)

### Phase 2 Plans (Future)

The integration is complete, but full migration is planned for a future phase:

1. **Switch Default Exports**
   - Make external Object the default export
   - Move legacy Object behind feature flag or deprecation warning

2. **Update All Macros**
   - Migrate `get_hub!()`, `get_inf!()`, `get_rsb!()` to use external Object
   - Update all convenience macros

3. **Full Migration**
   - Convert all RSB internal code to use external Object
   - Remove legacy Object implementation completely
   - Update all tests to use external Object

4. **Documentation Updates**
   - Rewrite `GUIDE_OBJECT_SHAPES.md` for external object patterns
   - Update all code examples in documentation
   - Create comprehensive migration guide

### Known Items

- Some duplicate tests existed in the legacy implementation (`helpers_old.rs`); the new `core.rs`
  module replaces those helpers entirely.
- Legacy warnings from `mod_impl_old.rs` are gone; the new implementation in `core.rs`
  compiles cleanly against the shared traits.
- Documentation still references legacy patterns (will be updated in Phase 2)

## Design Principles

### Dependency Injection Pattern

**Old Way** (hard-coded globals):
```rust
impl Object {
    pub fn from_global(namespace: &str) -> Self {
        // Directly accesses rsb::global::*
        let vars = rsb::global::get_all_with_prefix(namespace);
        // ...
    }
}
```

**New Way** (dependency injection):
```rust
// Foundation provides the interface
pub trait ContextStore {
    fn load(&self, prefix: &str) -> HashMap<String, String>;
    fn save(&mut self, prefix: &str, data: &HashMap<String, String>);
}

// Object accepts any ContextStore
impl<T> Object<T> {
    pub fn from_store<S: ContextStore>(namespace: &str, store: &S) -> Self {
        // ...
    }
}

// RSB implements the interface
impl ContextStore for Global { /* ... */ }

// RSB provides convenience wrapper
pub fn object_from_global<T>(namespace: &str) -> Object<T> {
    let global = GLOBAL.lock().unwrap();
    Object::from_store(namespace, &*global)
}
```

**Benefits**:
- Foundation library has no RSB dependency
- Other projects can use Object with their own storage
- RSB keeps its ergonomic API
- Testing is easier (can use InMemoryStore)

### Marker Type Ownership

**Foundation** (`oodx/object`):
- `GenericShape` - general-purpose objects
- `JSONShape` - JSON-style data

**RSB** (this project):
- `HubShape` - hub framework configuration
- `InfShape` - infrastructure metadata
- `RSBShape` - RSB framework settings

**Meteor** (`oodx/meteor` with object feature):
- `MeteorShape` - meteor data representations

**Rule**: Shape types are defined by the crate that uses them, not the foundation.

### String-First Philosophy

All values in Object are strings, aligning with RSB's string-biased philosophy:

```rust
let obj: Object = Object::new("config");
obj.set("count", "42");      // Not i32
obj.set("enabled", "true");  // Not bool
obj.set("rate", "3.14");     // Not f64

// Parse when needed
let count: i32 = obj.get("count").parse().unwrap_or(0);
let enabled = obj.get("enabled") == "true";
```

## Related Documentation

### External oodx/object
- [oodx/object README](https://gitlab.com/oodx/object) - Foundation library overview
- Repository tests - 84 comprehensive unit tests

### RSB Documentation
- `OBJECT_UPDATE.md` - Integration plan and implementation notes
- `docs/procs/RSB_OBJECT_INTEGRATION_SUMMARY.md` - Integration summary
- `docs/guides/GUIDE_OBJECT_SHAPES.md` - Shape pattern guide (needs update for external object)

### Source Files
- `src/object/mod.rs` - Module orchestrator (dual implementation)
- `src/object/shapes.rs` - RSB-specific shape types
- `src/object/rsb_extensions.rs` - Convenience functions for global store
- `src/global/store.rs` - ContextStore implementation for Global

## Best Practices

### DO

- Use external Object for all new code
- Use `object_from_global()` and `object_sync_to_global()` for RSB integration
- Use shape types for compile-time documentation
- Keep values as strings, parse when needed
- Implement ContextStore for custom storage backends

### DON'T

- Don't use legacy Object for new code
- Don't rely on phantom types for runtime behavior
- Don't store complex nested structures (keep it flat)
- Don't parse values repeatedly (cache parsed values)
- Don't mix external and legacy Object in the same module

### Migration Tips

1. Start with new features - use external Object from the beginning
2. Migrate existing code incrementally, one module at a time
3. Run tests frequently to catch issues early
4. Use type aliases (`HubConfig`, etc.) for cleaner code
5. Remember: external Object uses `get()` instead of bracket notation

## Implementation History

**Sept 2025**: RSB v2.0 with internal Object implementation
**Oct 2025**: Object extracted to `oodx/object` foundation library
**Oct 2025**: External object integrated back into RSB with ContextStore trait
**Oct 2025**: Dual implementation (external + legacy) for gradual migration

### Commit History (Integration Phase)

1. `24cef19` - feat(object): implement ContextStore trait for Global store
2. `9d70af4` - feat(object): define RSB-specific shape types
3. `adfc98e` - feat(object): add RSB convenience extensions for Object
4. `d07fe52` - feat(object): update module structure for external object integration
5. `568c6d5` - fix(object): correct RsbConfig typo to RSBConfig in tests

---

## Code Inventory

Once the Object module is implemented, run:
```bash
python3 bin/feat.py object --update-doc
```

This will populate the code inventory below with actual exports from `src/object/`.

**Note**: After implementation, update `FEATURE_MAP` in `bin/feat.py` to include:
```python
'object': ['src/object', 'src/macros/object.rs'],
```

<!-- feat:object -->

_Generated by bin/feat2.py --update-doc._

* `src/object/core.rs`
  - fn load_globals_with_prefix (line 6)
  - fn normalize_key (line 25)

* `src/object/macros.rs`
  - macro hub_config! (line 5)
  - macro inf_config! (line 13)
  - macro rsb_config! (line 21)
  - macro hub_object! (line 29)
  - macro inf_object! (line 37)
  - macro rsb_object! (line 45)

* `src/object/mod.rs`
  - pub use object::ObjectLike (line 23)
  - pub use shapes::{HubShape, InfShape, RSBShape, HubConfig, InfConfig, RSBConfig} (line 29)
  - pub use core::{AnyObject, GenericObject, JSONObject, Object} (line 4)
  - pub use utils::* (line 58)
  - pub use objectlike::ObjectLike as OldObjectLike (line 61)

* `src/object/core.rs`
  - struct Object (line 14)
  - fn new (line 22)
  - fn from_global (line 32)
  - fn get (line 44)
  - fn get_or (line 53)
  - fn has (line 62)
  - fn set (line 68)
  - fn as_map (line 74)
  - fn keys (line 79)
  - fn namespace (line 84)
  - fn sync_to_global (line 89)
  - fn as_type (line 96)
  - fn merge (line 123)
  - fn from_map (line 144)
  - fn iter (line 172)
  - fn filter_prefix (line 192)
  - fn to_vec (line 223)
  - fn is_empty (line 234)
  - fn len (line 239)
  - fn require (line 258)
  - fn require_all (line 284)
  - fn dump (line 307)
  - struct HubShape (line 361)
  - struct InfShape (line 362)
  - struct RSBShape (line 363)
  - struct GenericShape (line 364)
  - struct JSONShape (line 365)
  - struct MeteorShape (line 366)
  - type AnyObject (line 369)
  - type HubConfig (line 370)
  - type InfConfig (line 371)
  - type RSBConfig (line 372)
  - type GenericObject (line 373)
  - type JSONObject (line 374)
  - type MeteorObject (line 375)

* `src/object/core.rs`
  - trait ObjectLike (line 30)
  - fn clone_into (line 137)
  - fn merge_all (line 166)
  - fn filter (line 197)
  - fn map_values (line 232)

* `src/object/rsb_extensions.rs`
  - fn object_from_global (line 25)
  - fn object_sync_to_global (line 53)

* `src/object/shapes.rs`
  - struct HubShape (line 13)
  - struct InfShape (line 20)
  - struct RSBShape (line 27)
  - type HubConfig (line 31)
  - type InfConfig (line 34)
  - type RSBConfig (line 37)

* `src/object/utils.rs`
  - fn get_object (line 6)
  - fn get_hub (line 11)
  - fn get_inf (line 16)
  - fn get_rsb (line 21)

<!-- /feat:object -->




---

*Generated for RSB v2.0 - Object Feature*
*Updated: 2025-10-07 - External Object Integration*
