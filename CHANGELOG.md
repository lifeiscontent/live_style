# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.12.0] - 2026-01-03

### Added

- `LiveStyle.install_and_run/2` for Phoenix endpoint watcher integration
  - Follows the same pattern as Tailwind and esbuild
  - Watches manifest file for changes and regenerates CSS automatically
  - Configure in `config/dev.exs` under watchers
  - See Getting Started guide for setup instructions

### Changed

- **BREAKING**: Default manifest path changed from `priv/live_style_manifest.etf` to `_build/live_style/manifest.etf`
  - Manifest is now in dedicated subdirectory for faster file watching
  - Automatically cleaned by `mix clean`
  - No longer needs to be gitignored (already in `_build/`)
  - Override with `config :live_style, manifest_path: "custom/path.etf"`

- Consolidated storage modules into single `LiveStyle.Storage` module
  - Removed: `Storage.Adapter`, `Storage.Cache`, `Storage.FileAdapter`, `Storage.IO`, `Storage.Lock`, `Storage.Path`, `Storage.ProcessState`, `Storage.TableOwner`
  - Simpler architecture with direct file operations and directory-based locking

### Fixed

- File watcher now detects manifest changes on macOS
  - Atomic writes use rename, which triggers `:renamed` events instead of `:modified`
  - Watch mode now handles `:renamed` and `:moved` events in addition to `:modified`/`:created`
  - Added 50ms debouncing to coalesce rapid file events into single rebuild

- Theme variables now use correct CSS variable prefix from config
  - Previously theme overrides used hardcoded `--v` prefix instead of `--x` (from `Config.class_name_prefix()`)
  - This caused themes to define different variables than base vars, breaking theme switching

- StyleX-compatible property merging behavior
  - `default` condition now uses just the property name (e.g., `color`) instead of `color::default`
  - Each property key is completely independent - only exact key matches conflict
  - `color` and `color:::hover` are separate keys that coexist

## [0.11.1] - 2026-01-02

### Fixed

- Updated all documentation examples to use `MyAppWeb` namespace (Phoenix convention)
- Fixed `LiveStyle.CSS.Property` references to `LiveStyle.PropertyType` in design-tokens guide
- Updated default output path to `priv/static/assets/css/live.css` (Phoenix-compatible structure)
- Updated watcher configuration for development
- Fixed benchmark file reference to `LiveStyle.Compiler.CSS`

### Documentation

- Improved Getting Started guide with esbuild CSS configuration
- Added development watcher setup instructions
- Updated configuration guide with Phoenix-compatible paths
- Standardized all code examples to keyword list syntax

## [0.11.0] - 2025-01-01

### Changed

- **BREAKING**: Simplified API by removing `css_` prefix from all macros:
  - `css_class/2` → `class/2`
  - `css_vars/2` → `vars/1` (namespace is now the module)
  - `css_consts/2` → `consts/1` (namespace is now the module)
  - `css_keyframes/2` → `keyframes/2`
  - `css_theme/3` → `theme/2` (namespace is now the module)
  - `css_view_transition/2` → `view_transition_class/2`
  - `css_position_try/2` → `position_try/2`
  - `css_var/1` → `var/1` (2-tuple `{Module, :name}` instead of 3-tuple)
  - `css_const/1` → `const/1` (2-tuple `{Module, :name}` instead of 3-tuple)

- **BREAKING**: Unified module system - use `use LiveStyle` instead of:
  - `use LiveStyle.Sheet` (removed)
  - `use LiveStyle.Tokens` (removed)

- **BREAKING**: Token references now use 2-tuples instead of 3-tuples:
  ```elixir
  # Before
  css_var({MyApp.Tokens, :colors, :primary})
  css_const({MyApp.Tokens, :spacing, :md})

  # After
  var({MyApp.Colors, :primary})
  const({MyApp.Spacing, :md})
  ```

### Internal

- Major codebase restructuring for better organization:
  - Moved compiler-related code into `lib/live_style/compiler/`
  - Renamed `LiveStyle.Data` → `LiveStyle.PropertyMetadata`
  - Renamed `LiveStyle.Types` → `LiveStyle.PropertyType`
  - Renamed `LiveStyle.Value` → `LiveStyle.CSSValue`
  - Consolidated manifest and utility modules
- Added comprehensive snapshot tests for CSS output verification
- Added `LiveStyle.Registry` macro for DRY manifest registration
- Improved conditional detection for magic string keys

## [0.10.0] - 2025-12-23

### Removed

- Removed nested at-rule map syntax in `class/2` (top-level keys like `"@media (...)" => %{...}`); use per-property conditional values instead.

## [0.9.0] - 2024-12-21

### Added

- `css/2` macro with `:style` option for merging additional inline styles:
  ```elixir
  <div {css([:card], style: [
    view_transition_class: css_view_transition(:card),
    view_transition_name: "card-#{@id}"
  ])}>
  ```

- Comprehensive documentation for Phoenix LiveView View Transitions integration:
  - Complete JavaScript adapter code (`createViewTransitionDom`)
  - Reusable `ViewTransition` component with colocated hook
  - Step-by-step integration guide
  - Key insights for correct timing and element structure

- Documentation for CSS Scroll-Driven Animations:
  - Scroll progress timelines (`animation-timeline: scroll()`)
  - View progress timelines (`animation-timeline: view()`)
  - Named view timelines for parallax effects
  - Horizontal scroll progress with named scroll timelines
  - Animation range control

- `LiveStyle.Dev` module with development helpers for inspecting styles:
  - `class_info/2` - Returns detailed info about a class (CSS, properties, values)
  - `list/1,2` - Lists all class names in a module (with :static/:dynamic filtering)
  - `diff/2` - Shows how multiple classes merge with property-level detail
  - `css/2` - Returns raw CSS output for classes
  - `tokens/1` - Shows all tokens defined in a module
  - `pp/2`, `pp_list/1` - Pretty-print helpers for console output

- `mix live_style.audit` task to find potentially unused class definitions:
  - Scans codebase for `css_class/2` definitions
  - Searches for references in `.ex`, `.exs`, and `.heex` files
  - Reports classes with no apparent references
  - Supports `--format json` for tooling integration

- `mix live_style.inspect` task to inspect class definitions from CLI:
  - Shows generated CSS and property breakdown
  - Supports inspecting multiple classes with merged result
  - `--css` flag for raw CSS output

### Changed

- `css_view_transition/1` macro now returns compile-time values instead of runtime lookups

### Fixed

- View transition class references are now resolved at compile time for better performance

## [0.7.0] - 2024-12-20

### Changed

- **BREAKING**: CSS layers behavior now matches StyleX defaults:
  - `use_css_layers: false` (default) - Uses `:not(#\#)` selector hack for specificity (StyleX default)
  - `use_css_layers: true` - Groups rules by priority in `@layer priorityN` blocks (StyleX `useLayers: true`)
  - Removed `use_priority_layers` config option (no longer needed)

- **BREAKING**: Renamed shorthand behavior config and modes:
  - Config key: `shorthand_strategy` → `shorthand_behavior`
  - `:keep_shorthands` → `:accept_shorthands`
  - `:reject_shorthands` → `:forbid_shorthands`
  - `:expand_to_longhands` → `:flatten_shorthands`

- **BREAKING**: Renamed shorthand modules:
  - `LiveStyle.Shorthand.Strategy` → `LiveStyle.ShorthandBehavior`
  - `LiveStyle.Shorthand.Strategy.KeepShorthands` → `LiveStyle.ShorthandBehavior.AcceptShorthands`
  - `LiveStyle.Shorthand.Strategy.ExpandToLonghands` → `LiveStyle.ShorthandBehavior.FlattenShorthands`
  - `LiveStyle.Shorthand.Strategy.RejectShorthands` → `LiveStyle.ShorthandBehavior.ForbidShorthands`

- **BREAKING**: Renamed config function:
  - `shorthand_strategy/0` → `LiveStyle.Config.shorthand_behavior/0`

- Renamed internal terminology from "null" to "nil" (Elixir idiom):
  - `%{null: true}` → `%{unset: true}` in atomic class maps
  - `:__null__` → `:__unset__` sentinel atom

- CSS variable prefix now uses configurable `class_name_prefix` instead of hardcoded `--x-`

### Added

- CSS property validation with "did you mean?" suggestions for typos
  - `validate_properties: true` config option (default: true)
  - `unknown_property_level: :warn` - `:error`, `:warn`, or `:ignore`
  - `vendor_prefix_level: :warn` - warns when vendor prefixes are used unnecessarily
  - `deprecated_property_level: :warn` - warns when deprecated properties are used
  - `deprecated?: &MyApp.CSS.deprecated?/1` - configurable deprecation check function

- Configurable CSS prefixing via `prefix_css` config option
  - `prefix_css: &MyApp.CSS.prefix/2` - function to add vendor prefixes
  - `LiveStyle.Config.apply_prefix_css/2` - applies configured prefixer

- Automatic selector prefixing for pseudo-elements (e.g., `::thumb`, `::placeholder`)
  - Generates vendor-prefixed variants automatically

### Fixed

- Validation warnings now appear on recompile (file/line info threaded through call chain)
- RTL type spec now correctly accepts `nil` for selector_suffix parameter
- Support for comma-separated keyframe keys like `"0%, 100%"`

### Internal

- Extracted SRP-focused modules from monolithic `LiveStyle.Class` and `LiveStyle.CSS`
- Optimized `Property.Validation.known?` with pattern matching (~7% faster)
- Optimized `Selector.Prefixer.prefix` with binary slicing (~43% faster)
- Extracted `LiveStyle.Hash.Murmur` module for MurmurHash3 implementation
- Removed specific package references from documentation (now uses generic examples)

## [0.6.2] - 2024-12-19

### Changed

- **BREAKING**: Renamed all macros to use `css_` prefix for consistency with StyleX naming:
  - `style/2` → `css_class/2`
  - `defvars/2` → `css_vars/2`
  - `defconsts/2` → `css_consts/2`
  - `defkeyframes/2` → `css_keyframes/2`
  - `keyframes/1` → `css_keyframes/1` (reference form)
  - `var/1` → `css_var/1`
  - `const/1` → `css_const/1`
  - `create_theme/3` → `css_theme/3`
  - `position_try/1` → `css_position_try/1`
  - `view_transition/2` → `css_view_transition/2`
  - `view_transition_class/1` → `css_view_transition/1` (reference form)

- **BREAKING**: Moved tooling functions out of `LiveStyle`:
  - run/2 → LiveStyle.Compiler.run/2
  - install_and_run/2 → LiveStyle.Compiler.Runner.install_and_run/2
  - write_css/1 → LiveStyle.Compiler.Writer.write_css/1
  
  Update your Phoenix watcher config:
  ```elixir
  # Before
  watchers: [live_style: {LiveStyle, :install_and_run, [:default, ~w(--watch)]}]
  
  # After
  watchers: [live_style: {LiveStyle.Compiler, :run, [:default, ~w(--watch)]}]
  ```

- Removed `manifest_path/0`, `style_resolution/0`, `output_path/0`, `config_for!/1` delegates from `LiveStyle`
- Config functions now accessed via `LiveStyle.Config` module directly

### Added

- `LiveStyle.Compiler` module for all tooling/compilation functions

## [0.6.0] - 2024-12-17

### Changed

- **BREAKING**: Default shorthand behavior changed to `:accept_shorthands` for more intuitive CSS behavior (last style wins)
- Simplified `props/1` API - now only accepts a single value or a list (removed variadic `props/2-5`)

### Added

- `LiveStyle.ShorthandBehavior` behaviour for custom shorthand handling strategies
- `LiveStyle.ShorthandBehavior.AcceptShorthands`, `FlattenShorthands`, `ForbidShorthands` implementations
- `LiveStyle.Storage` module for file-based manifest storage
- `LiveStyle.Config` module for unified configuration management with per-process overrides
- LiveStyle.Compiler.Writer.write_css/1 function for writing CSS with change detection

### Removed

- Removed legacy backward compatibility code for old style reference formats
- Removed unused variadic `props/2-5` functions

### Internal

- All tests now run with `async: true` using in-memory storage
- Deduplicated code across compiler, watcher, and style resolution modules
- Improved test isolation with `LiveStyle.TestCase` and `LiveStyle.TestHelper`

## [0.5.0] - 2024-12-17

### Changed

- **BREAKING**: `css_keyframes/1` now takes only frames and returns the generated name (matching StyleX API)
  ```elixir
  # Before (0.4.x)
  keyframes :spin, from: [...], to: [...]
  style :spinner, animation_name: :spin

  # After (0.5.0+)
  css_keyframes :spin,
    from: [...],
    to: [...]
  
  css_class :spinner,
    animation_name: css_keyframes(:spin)
  ```

- **BREAKING**: `css_view_transition/1` now takes only styles and returns the generated class name

- Keyframe names now use `x<hash>-B` format (matching StyleX) instead of `k<hash>`

### Added

- `css_position_try/2` macro for CSS Anchor Positioning (`@position-try` at-rules)
  - Creates fallback positioning options for anchor-positioned elements
  - Returns a dashed-ident string (e.g., `"--x1a2b3c4"`) for use with `position_try_fallbacks`
  - Validates that only allowed properties are used (position, inset, margin, size, self-alignment)
  - Supports RTL/LTR transformations for logical properties

## [0.4.1] - 2024-12-17

### Added

- Tuple list syntax support for computed keys as an alternative to map syntax:
  ```elixir
  # Now you can use tuple lists with computed keys
  css_class :responsive,
    font_size: [
      {:default, "1rem"},
      {css_const({MyApp.Tokens, :breakpoint, :lg}), "1.5rem"}
    ]
  ```

### Fixed

- CI now only checks formatting on Elixir 1.17 to avoid formatter version differences

## [0.4.0] - 2024-12-17

### Added

- Keyword list syntax support for all macros as an alternative to map syntax
- `normalize_to_map/1` helper function for recursively converting keyword lists to maps
- Dedicated test file for keyword syntax coverage

### Changed

- All style macros now accept both map syntax (`%{key: value}`) and keyword list syntax (`key: value`)
- Documentation updated with keyword list examples throughout

### Notes

- Keyword list syntax is more idiomatic Elixir and recommended for most use cases
- For computed keys, use either map syntax with `=>` or tuple list syntax `[{key, value}]`

## [0.3.0] - 2024-12-17

### Added

- `LiveStyle.ViewTransitions` module for CSS View Transitions API support:
  - `css_view_transition/2` macro for defining transitions by name pattern
  - Automatic keyframe name resolution in view transition styles
  - Support for `:old`, `:new`, `:group`, `:image_pair` pseudo-element keys
  - Support for `:only-child` variants (`:old_only_child`, `:new_only_child`, etc.)
  - Media query conditions (e.g., `prefers-reduced-motion`)
  - Compile-time validation for keyframe references in `animation_name`

### Changed

- `css_keyframes/2` now defines a function that returns the hashed keyframe name
  - Allows keyframes to be used in both styles and view transitions
  - Example: `MyApp.Tokens.spin()` returns `"x1a2b3c4-B"`

## [0.2.0] - 2024-12-17

### Added

- `LiveStyle.When` module with contextual selectors (inspired by StyleX's `stylex.when.*`):
  - `ancestor/1,2` - style when ancestor has pseudo-state
  - `descendant/1,2` - style when descendant has pseudo-state
  - `sibling_before/1,2` - style when preceding sibling has pseudo-state
  - `sibling_after/1,2` - style when following sibling has pseudo-state
  - `any_sibling/1,2` - style when any sibling has pseudo-state
- `LiveStyle.default_marker/0` - returns the default marker class for contextual selectors
- `LiveStyle.marker/1` - creates unique marker classes for custom contexts
- Nested pseudo-class conditions - combine selectors like `:nth-child(2):where(.marker:hover *)`

## [0.1.0] - 2024-12-16

### Added

- Initial release of LiveStyle
- `css_class/2` macro for declaring named styles with CSS declarations
- `css_keyframes/2` macro for defining CSS animations
- `css_var/1` macro for referencing CSS custom properties
- `fallback/1` macro for CSS fallback values
- `css_vars/2` macro for defining CSS custom properties (design tokens)
- `css_consts/2` macro for defining compile-time constants
- `css_theme/3` macro for creating scoped theme overrides
- `LiveStyle.Types` module with type helpers for CSS `@property` rules:
  - `color/1`, `length/1`, `angle/1`, `integer/1`, `number/1`, `time/1`, `percentage/1`
- `__include__` key for style composition (external modules and self-references)
- StyleX-inspired condition-in-value syntax for pseudo-classes and media queries
- Pseudo-element support (`::before`, `::after`, etc.)
- Atomic CSS generation with deterministic class name hashing
- CSS `@layer` support for predictable specificity
- Mix compiler (`Mix.Tasks.Compile.LiveStyle`) for automatic CSS generation
- Mix task (`mix live_style.gen.css`) for manual CSS generation
- Development watcher (`LiveStyle.Watcher`) for hot reloading
- CSS variable reference validation at compile time
- File-based manifest locking for parallel compilation safety
- Configurable `output_path` for CSS file location
- Configurable `storage` for manifest storage backend
