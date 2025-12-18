# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.0] - 2024-12-17

### Changed

- **BREAKING**: Default style resolution changed from `:strict` to `:atomic` for more intuitive CSS behavior (last style wins)
- **BREAKING**: Renamed style resolution modes for clarity:
  - `:property_specificity` → `:strict`
  - `:application_order` → `:atomic`
  - `:legacy_expand` → `:expanded`
  
  ```elixir
  # Before
  config :live_style, style_resolution: :property_specificity
  
  # After
  config :live_style, style_resolution: :strict
  ```

- Simplified `props/1` API - now only accepts a single value or a list (removed variadic `props/2-5`)

### Added

- `LiveStyle.StyleResolution` behaviour for custom style resolution strategies
- `LiveStyle.StyleResolution.Strict`, `LiveStyle.StyleResolution.Atomic`, `LiveStyle.StyleResolution.Expanded` implementations
- `LiveStyle.Storage` behaviour for manifest storage abstraction
- `LiveStyle.Storage.File` (default) and `LiveStyle.Storage.Memory` (for testing) implementations
- `LiveStyle.Config` module for unified configuration management with per-process overrides
- `LiveStyle.write_css/1` function for writing CSS with change detection
- `LiveStyle.Storage.has_styles?/1` helper function
- `LiveStyle.to_css_property/1` now public for use by style resolution modules

### Removed

- Removed legacy backward compatibility code for old style reference formats
- Removed unused variadic `props/2-5` functions

### Internal

- All tests now run with `async: true` using in-memory storage
- Deduplicated code across compiler, watcher, and style resolution modules
- Improved test isolation with `LiveStyle.TestCase` and `LiveStyle.TestHelper`

## [0.5.0] - 2024-12-17

### Changed

- **BREAKING**: `keyframes/1` now takes only frames and returns the generated name (matching StyleX API)
  ```elixir
  # Before (0.4.x)
  keyframes :spin, from: [...], to: [...]
  style :spinner, animation_name: :spin

  # After (0.5.0)
  @spin keyframes(from: [...], to: [...])
  style :spinner, animation_name: @spin
  ```

- **BREAKING**: `view_transition_class/1` now takes only styles and returns the generated class name
  ```elixir
  # Before (0.4.x)  
  view_transition_class :fade, old: [...], new: [...]
  # Then use fade() function

  # After (0.5.0)
  @fade view_transition_class(old: [...], new: [...])
  # Use @fade directly
  ```

- Keyframe names now use `x<hash>-B` format (matching StyleX) instead of `k<hash>`

### Added

- `position_try/1` macro for CSS Anchor Positioning (`@position-try` at-rules)
  - Creates fallback positioning options for anchor-positioned elements
  - Returns a dashed-ident string (e.g., `"--x1a2b3c4"`) for use with `position_try_fallbacks`
  - Validates that only allowed properties are used (position, inset, margin, size, self-alignment)
  - Supports RTL/LTR transformations for logical properties
  - Available in both `use LiveStyle` and `use LiveStyle.Tokens`
  ```elixir
  style :tooltip,
    position_try_fallbacks: position_try(
      bottom: "anchor(top)",
      left: "anchor(center)"
    )
  ```

## [0.4.1] - 2024-12-17

### Added

- Tuple list syntax support for computed keys as an alternative to map syntax:
  ```elixir
  # Now you can use tuple lists with computed keys
  style :responsive,
    font_size: [
      {:default, "1rem"},
      {Tokens.breakpoints_lg(), "1.5rem"}
    ]
  ```

### Fixed

- CI now only checks formatting on Elixir 1.17 to avoid formatter version differences

## [0.4.0] - 2024-12-17

### Added

- Keyword list syntax support for all macros as an alternative to map syntax:
  - `style/2`, `keyframes/2`, `defvars/2`, `defconsts/2`, `defkeyframes/2`, `create_theme/3`
  - `view_transition/2`, `view_transition_class/2`
- `normalize_to_map/1` helper function for recursively converting keyword lists to maps
- Dedicated test file `test/live_style/keyword_syntax_test.exs` for keyword syntax coverage

### Changed

- All style macros now accept both map syntax (`%{key: value}`) and keyword list syntax (`key: value`)
- Documentation updated with keyword list examples throughout

### Notes

- Keyword list syntax is more idiomatic Elixir and recommended for most use cases
- For computed keys, use either map syntax with `=>` or tuple list syntax `[{key, value}]`

## [0.3.0] - 2024-12-17

### Added

- `LiveStyle.ViewTransitions` module for CSS View Transitions API support:
  - `view_transition/2` macro for defining transitions by name pattern
  - `view_transition_class/2` macro for class-based transitions
  - Automatic keyframe name resolution in view transition styles
  - Support for `:old`, `:new`, `:group`, `:image_pair` pseudo-element keys
  - Support for `:only-child` variants (`:old_only_child`, `:new_only_child`, etc.)
  - Media query conditions (e.g., `prefers-reduced-motion`)
  - Compile-time validation for keyframe references in `animation_name`

### Changed

- `defkeyframes/2` now defines a function that returns the hashed keyframe name
  - Allows keyframes to be used in both styles and view transitions
  - Example: `MyApp.Tokens.fade_in()` returns `"k1a2b3c4"`

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
- `conditions/1` macro - allows module attributes as condition keys in style declarations
- Nested pseudo-class conditions - combine selectors like `:nth-child(2):where(.marker:hover *)`

## [0.1.0] - 2024-12-16

### Added

- Initial release of LiveStyle
- `style/2` macro for declaring named styles with CSS declarations
- `keyframes/2` macro for defining CSS animations
- `var/1` macro for referencing CSS custom properties
- `first_that_works/1` macro for CSS fallback values
- `defvars/2` macro for defining CSS custom properties (design tokens)
- `defconsts/2` macro for defining compile-time constants
- `defkeyframes/2` macro for defining keyframes in token modules
- `create_theme/3` macro for creating scoped theme overrides
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
- Configurable `manifest_path` for build artifact location (useful for monorepos)
