# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.5.0] - 2024-12-19

### Changed

- **BREAKING**: Renamed all macros to use `css_` prefix for consistency with StyleX naming:
  - `style/2` → `css_rule/2`
  - `defvars/2` → `css_vars/2`
  - `defconsts/2` → `css_consts/2`
  - `defkeyframes/2` → `css_keyframes/2`
  - `keyframes/1` → `css_keyframes/1` (reference form)
  - `var/1` → `css_var/1`
  - `create_theme/3` → `css_theme/3`
  - `position_try/1` → `css_position_try/1`
  - `view_transition/2` → `css_view_transition/2`
  - `view_transition_class/1` → `css_view_transition/1` (reference form)
  
- **BREAKING**: Configuration changes:
  - `style_resolution` replaced with `shorthand_strategy` config
  
  ```elixir
  # Before
  config :live_style,
    manifest_path: "_build/live_style_manifest.etf",
    style_resolution: :atomic
  
  # After  
  config :live_style,
    manifest_path: "_build/live_style_manifest.etf",
    shorthand_strategy: :keep_shorthands
  ```

- **BREAKING**: Style resolution modes renamed:
  - `:atomic` → `:keep_shorthands`
  - `:strict` → `:reject_shorthands`
  - `:expanded` → `:expand_to_longhands`

- **BREAKING**: Moved tooling functions out of `LiveStyle`:
  - `run/2` → `LiveStyle.Compiler.run/2`
  - `install_and_run/2` → `LiveStyle.Compiler.install_and_run/2`
  - `write_css/1` → `LiveStyle.Compiler.write_css/1`
  - `validate_var_references!/0` → `LiveStyle.Vars.validate_references!/0`
  
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

### Internal

- Removed all `# ===...===` section divider comments from source files

## [0.6.0] - 2024-12-17

### Changed

- **BREAKING**: Default style resolution changed from `:strict` to `:atomic` for more intuitive CSS behavior (last style wins)
- **BREAKING**: Renamed style resolution modes for clarity:
  - `:property_specificity` → `:strict`
  - `:application_order` → `:atomic`
  - `:legacy_expand` → `:expanded`

- Simplified `props/1` API - now only accepts a single value or a list (removed variadic `props/2-5`)

### Added

- `LiveStyle.StyleResolution` behaviour for custom style resolution strategies
- `LiveStyle.StyleResolution.Strict`, `LiveStyle.StyleResolution.Atomic`, `LiveStyle.StyleResolution.Expanded` implementations
- `LiveStyle.Storage` module for file-based manifest storage
- `LiveStyle.Config` module for unified configuration management with per-process overrides
- `LiveStyle.Compiler.write_css/1` function for writing CSS with change detection
- `LiveStyle.Storage.has_styles?/1` helper function

### Removed

- Removed legacy backward compatibility code for old style reference formats
- Removed unused variadic `props/2-5` functions

### Internal

- All tests now run with `async: true` using in-memory storage
- Deduplicated code across compiler, watcher, and style resolution modules
- Improved test isolation with `LiveStyle.TestCase` and `LiveStyle.TestHelper`

## [0.5.0] - 2024-12-17

### Changed

- **BREAKING**: `css_keyframes/1` (was `keyframes/1`) now takes only frames and returns the generated name (matching StyleX API)
  ```elixir
  # Before (0.4.x)
  keyframes :spin, from: [...], to: [...]
  style :spinner, animation_name: :spin

  # After (0.5.0+)
  css_keyframes :spin,
    from: [...],
    to: [...]
  
  css_rule :spinner,
    animation_name: css_keyframes(:spin)
  ```

- **BREAKING**: `css_view_transition/1` (was `view_transition_class/1`) now takes only styles and returns the generated class name

- Keyframe names now use `x<hash>-B` format (matching StyleX) instead of `k<hash>`

### Added

- `css_position_try/2` (was `position_try/1`) macro for CSS Anchor Positioning (`@position-try` at-rules)
  - Creates fallback positioning options for anchor-positioned elements
  - Returns a dashed-ident string (e.g., `"--x1a2b3c4"`) for use with `position_try_fallbacks`
  - Validates that only allowed properties are used (position, inset, margin, size, self-alignment)
  - Supports RTL/LTR transformations for logical properties

## [0.4.1] - 2024-12-17

### Added

- Tuple list syntax support for computed keys as an alternative to map syntax:
  ```elixir
  # Now you can use tuple lists with computed keys
  css_rule :responsive,
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

- `css_keyframes/2` (was `defkeyframes/2`) now defines a function that returns the hashed keyframe name
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
- `LiveStyle.define_marker/1` - creates unique marker classes for custom contexts
- Nested pseudo-class conditions - combine selectors like `:nth-child(2):where(.marker:hover *)`

## [0.1.0] - 2024-12-16

### Added

- Initial release of LiveStyle
- `css_rule/2` macro for declaring named styles with CSS declarations
- `css_keyframes/2` macro for defining CSS animations
- `css_var/1` macro for referencing CSS custom properties
- `first_that_works/1` macro for CSS fallback values
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
