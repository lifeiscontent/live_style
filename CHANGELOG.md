# Changelog

All notable changes to this project will be documented in this file.
See [Conventional Commits](https://conventionalcommits.org) for commit guidelines.

<!-- changelog -->

## [v0.15.0](https://github.com/lifeiscontent/live_style/compare/v0.14.0...v0.15.0) (2026-01-31)




### Features:

* improve compilation, watcher, and add @import directive support by Aaron Reisman

## [v0.14.0](https://github.com/lifeiscontent/live_style/compare/v0.13.2...v0.14.0) (2026-01-23)

### Features:

* StyleX-style tree shaking: Only emit CSS for classes that are actually used via `css/1` macro calls
* New `UsageManifest` module for tracking class usage at compile time
* Usage tracking in `get_css/2` and `get_css_class/2` runtime functions
* `mark_all_used/2` helper for test environments (similar to StyleX's `treeshakeCompensation`)

### Bug Fixes:

* Fix compile task clearing usage manifest after elixir compiler records it
* Cross-module includes now properly record usage for tree shaking

### Improvements:

* Manifest version bumped to 8 (module keys now use canonical `Elixir.` prefix format)
* `Manifest.key/2` now uses `to_string(module)` instead of `inspect(module)` for consistent key format

## [v0.13.2](https://github.com/lifeiscontent/live_style/compare/v0.13.1...v0.13.2) (2026-01-15)

### Features:

* CSS variable override support in dynamic classes: Dynamic class functions can now override CSS variables defined in the base class, enabling runtime theming and customization

## [v0.13.1](https://github.com/lifeiscontent/live_style/compare/v0.13.0...v0.13.1) (2026-01-08)

### Features:

* Auto-recompile when manifest is empty: Mix compiler now detects empty manifests and automatically triggers `mix compile.elixir --force` to repopulate them
* Debug logging for unchanged CSS output in watch mode (`LiveStyle: CSS unchanged, skipping write → path`)

### Bug Fixes:

* Add consistent file locking in `Storage.write/update/clear` to prevent race conditions when `process_active?` is true
* Fix `manifest_empty?` to check all 7 collections, not just 3
* Add warning log when manifest version mismatch causes data discard
* Fix CSS writer to distinguish read errors from missing files
* Fix watcher debounce to use absolute deadline so non-manifest events don't reset the timer
* Remove redundant file delete in `Storage.clear()` (atomic write already overwrites)

## [v0.13.0](https://github.com/lifeiscontent/live_style/compare/v0.11.1...v0.13.0) (2026-01-03)

### Features:

* `LiveStyle.install_and_run/2` for Phoenix endpoint watcher integration
  - Follows the same pattern as Tailwind and esbuild
  - Watches manifest file for changes and regenerates CSS automatically
  - Configure in `config/dev.exs` under watchers
  - See Getting Started guide for setup instructions

### Breaking Changes:

* Renamed definition macros for consistency
  - `theme/2` → `theme_class/2`
  - `view_transition/2` → `view_transition_class/2`
  - Both now match their reference forms (`theme_class/1`, `view_transition_class/1`)

* Default manifest path changed from `priv/live_style_manifest.etf` to `_build/live_style/manifest.etf`
  - Manifest is now in dedicated subdirectory for faster file watching
  - Automatically cleaned by `mix clean`
  - No longer needs to be gitignored (already in `_build/`)
  - Override with `config :live_style, manifest_path: "custom/path.etf"`

* Consolidated storage modules into single `LiveStyle.Storage` module
  - Removed: `Storage.Adapter`, `Storage.Cache`, `Storage.FileAdapter`, `Storage.IO`, `Storage.Lock`, `Storage.Path`, `Storage.ProcessState`, `Storage.TableOwner`
  - Simpler architecture with direct file operations and directory-based locking

### Bug Fixes:

* File watcher now detects manifest changes on macOS
  - Atomic writes use rename, which triggers `:renamed` events instead of `:modified`
  - Watch mode now handles `:renamed` and `:moved` events in addition to `:modified`/`:created`
  - Added 50ms debouncing to coalesce rapid file events into single rebuild

* Theme variables now use correct CSS variable prefix from config
  - Previously theme overrides used hardcoded `--v` prefix instead of `--x` (from `Config.class_name_prefix()`)
  - This caused themes to define different variables than base vars, breaking theme switching

* StyleX-compatible property merging behavior
  - `default` condition now uses just the property name (e.g., `color`) instead of `color::default`
  - Each property key is completely independent - only exact key matches conflict
  - `color` and `color:::hover` are separate keys that coexist

## [v0.11.1](https://github.com/lifeiscontent/live_style/compare/v0.11.0...v0.11.1) (2026-01-02)

### Bug Fixes:

* Updated all documentation examples to use `MyAppWeb` namespace (Phoenix convention)
* Fixed `LiveStyle.CSS.Property` references to `LiveStyle.PropertyType` in design-tokens guide
* Updated default output path to `priv/static/assets/css/live.css` (Phoenix-compatible structure)
* Updated watcher configuration for development
* Fixed benchmark file reference to `LiveStyle.Compiler.CSS`

### Documentation:

* Improved Getting Started guide with esbuild CSS configuration
* Added development watcher setup instructions
* Updated configuration guide with Phoenix-compatible paths
* Standardized all code examples to keyword list syntax

## [v0.11.0](https://github.com/lifeiscontent/live_style/compare/v0.10.0...v0.11.0) (2025-01-01)

### Breaking Changes:

* Simplified API by removing `css_` prefix from all macros:
  - `css_class/2` → `class/2`
  - `css_vars/2` → `vars/1` (namespace is now the module)
  - `css_consts/2` → `consts/1` (namespace is now the module)
  - `css_keyframes/2` → `keyframes/2`
  - `css_theme/3` → `theme/2` (namespace is now the module)
  - `css_view_transition/2` → `view_transition_class/2`
  - `css_position_try/2` → `position_try/2`
  - `css_var/1` → `var/1` (2-tuple `{Module, :name}` instead of 3-tuple)
  - `css_const/1` → `const/1` (2-tuple `{Module, :name}` instead of 3-tuple)

* Unified module system - use `use LiveStyle` instead of:
  - `use LiveStyle.Sheet` (removed)
  - `use LiveStyle.Tokens` (removed)

* Token references now use 2-tuples instead of 3-tuples:
  ```elixir
  # Before
  css_var({MyApp.Tokens, :colors, :primary})
  css_const({MyApp.Tokens, :spacing, :md})

  # After
  var({MyApp.Colors, :primary})
  const({MyApp.Spacing, :md})
  ```

### Improvements:

* Major codebase restructuring for better organization:
  - Moved compiler-related code into `lib/live_style/compiler/`
  - Renamed `LiveStyle.Data` → `LiveStyle.PropertyMetadata`
  - Renamed `LiveStyle.Types` → `LiveStyle.PropertyType`
  - Renamed `LiveStyle.Value` → `LiveStyle.CSSValue`
  - Consolidated manifest and utility modules
* Added comprehensive snapshot tests for CSS output verification
* Added `LiveStyle.Registry` macro for DRY manifest registration
* Improved conditional detection for magic string keys

## [v0.10.0](https://github.com/lifeiscontent/live_style/compare/v0.9.0...v0.10.0) (2025-12-23)

### Breaking Changes:

* Removed nested at-rule map syntax in `class/2` (top-level keys like `"@media (...)" => %{...}`); use per-property conditional values instead.

## [v0.9.0](https://github.com/lifeiscontent/live_style/compare/v0.7.0...v0.9.0) (2024-12-21)

### Features:

* `css/2` macro with `:style` option for merging additional inline styles:
  ```elixir
  <div {css([:card], style: [
    view_transition_class: css_view_transition(:card),
    view_transition_name: "card-#{@id}"
  ])}>
  ```

* Comprehensive documentation for Phoenix LiveView View Transitions integration:
  - Complete JavaScript adapter code (`createViewTransitionDom`)
  - Reusable `ViewTransition` component with colocated hook
  - Step-by-step integration guide
  - Key insights for correct timing and element structure

* Documentation for CSS Scroll-Driven Animations:
  - Scroll progress timelines (`animation-timeline: scroll()`)
  - View progress timelines (`animation-timeline: view()`)
  - Named view timelines for parallax effects
  - Horizontal scroll progress with named scroll timelines
  - Animation range control

* `LiveStyle.Dev` module with development helpers for inspecting styles:
  - `class_info/2` - Returns detailed info about a class (CSS, properties, values)
  - `list/1,2` - Lists all class names in a module (with :static/:dynamic filtering)
  - `diff/2` - Shows how multiple classes merge with property-level detail
  - `css/2` - Returns raw CSS output for classes
  - `tokens/1` - Shows all tokens defined in a module
  - `pp/2`, `pp_list/1` - Pretty-print helpers for console output

* `mix live_style.audit` task to find potentially unused class definitions
* `mix live_style.inspect` task to inspect class definitions from CLI

### Bug Fixes:

* View transition class references are now resolved at compile time for better performance

## [v0.7.0](https://github.com/lifeiscontent/live_style/compare/v0.6.2...v0.7.0) (2024-12-20)

### Breaking Changes:

* CSS layers behavior now matches StyleX defaults:
  - `use_css_layers: false` (default) - Uses `:not(#\#)` selector hack for specificity (StyleX default)
  - `use_css_layers: true` - Groups rules by priority in `@layer priorityN` blocks (StyleX `useLayers: true`)
  - Removed `use_priority_layers` config option (no longer needed)

* Renamed shorthand behavior config and modes:
  - Config key: `shorthand_strategy` → `shorthand_behavior`
  - `:keep_shorthands` → `:accept_shorthands`
  - `:reject_shorthands` → `:forbid_shorthands`
  - `:expand_to_longhands` → `:flatten_shorthands`

### Features:

* CSS property validation with "did you mean?" suggestions for typos
* Configurable CSS prefixing via `prefix_css` config option
* Automatic selector prefixing for pseudo-elements (e.g., `::thumb`, `::placeholder`)

### Bug Fixes:

* Validation warnings now appear on recompile
* RTL type spec now correctly accepts `nil` for selector_suffix parameter
* Support for comma-separated keyframe keys like `"0%, 100%"`

## [v0.6.2](https://github.com/lifeiscontent/live_style/compare/v0.6.0...v0.6.2) (2024-12-19)

### Breaking Changes:

* Renamed all macros to use `css_` prefix for consistency with StyleX naming
* Moved tooling functions out of `LiveStyle` to `LiveStyle.Compiler`

## [v0.6.0](https://github.com/lifeiscontent/live_style/compare/v0.5.0...v0.6.0) (2024-12-17)

### Breaking Changes:

* Default shorthand behavior changed to `:accept_shorthands` for more intuitive CSS behavior (last style wins)

### Features:

* `LiveStyle.ShorthandBehavior` behaviour for custom shorthand handling strategies
* `LiveStyle.Storage` module for file-based manifest storage
* `LiveStyle.Config` module for unified configuration management

## [v0.5.0](https://github.com/lifeiscontent/live_style/compare/v0.4.1...v0.5.0) (2024-12-17)

### Breaking Changes:

* `css_keyframes/1` now takes only frames and returns the generated name (matching StyleX API)
* `css_view_transition/1` now takes only styles and returns the generated class name
* Keyframe names now use `x<hash>-B` format (matching StyleX) instead of `k<hash>`

### Features:

* `css_position_try/2` macro for CSS Anchor Positioning (`@position-try` at-rules)

## [v0.4.1](https://github.com/lifeiscontent/live_style/compare/v0.4.0...v0.4.1) (2024-12-17)

### Features:

* Tuple list syntax support for computed keys as an alternative to map syntax

### Bug Fixes:

* CI now only checks formatting on Elixir 1.17 to avoid formatter version differences

## [v0.4.0](https://github.com/lifeiscontent/live_style/compare/v0.2.0...v0.4.0) (2024-12-17)

### Features:

* Keyword list syntax support for all macros as an alternative to map syntax
* `normalize_to_map/1` helper function for recursively converting keyword lists to maps

## [v0.2.0](https://github.com/lifeiscontent/live_style/compare/v0.1.0...v0.2.0) (2024-12-17)

### Features:

* `LiveStyle.When` module with contextual selectors (inspired by StyleX's `stylex.when.*`)
* `LiveStyle.default_marker/0` - returns the default marker class for contextual selectors
* `LiveStyle.marker/1` - creates unique marker classes for custom contexts
* Nested pseudo-class conditions

## [v0.1.0](https://github.com/lifeiscontent/live_style/compare/v0.1.0) (2024-12-16)

### Features:

* Initial release of LiveStyle
* `css_class/2` macro for declaring named styles with CSS declarations
* `css_keyframes/2` macro for defining CSS animations
* `css_var/1` macro for referencing CSS custom properties
* `fallback/1` macro for CSS fallback values
* `css_vars/2` macro for defining CSS custom properties (design tokens)
* `css_consts/2` macro for defining compile-time constants
* `css_theme/3` macro for creating scoped theme overrides
* StyleX-inspired condition-in-value syntax for pseudo-classes and media queries
* Pseudo-element support (`::before`, `::after`, etc.)
* Atomic CSS generation with deterministic class name hashing
* CSS `@layer` support for predictable specificity
* Mix compiler (`Mix.Tasks.Compile.LiveStyle`) for automatic CSS generation
* Development watcher (`LiveStyle.Watcher`) for hot reloading
