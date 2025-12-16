# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

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
