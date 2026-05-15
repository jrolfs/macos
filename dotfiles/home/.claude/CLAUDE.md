# Global Claude Code Guidelines

## TypeScript / JavaScript Conventions

### Function Style
- Prefer arrow functions: `const myFunction = (param: string): string => ...`
- Use `const` for function declarations instead of the `function` keyword

### Naming
- Don't abbreviate or use shorthand unless it's conventional in context (e.g. `environment` not `env`, but `req` is fine in Express)

### Programming Style
- Functional but pragmatic — prefer immutability and expressions over statements
- Prefer `const` over `let` unless performance demands otherwise
- Prefer `.reduce()`, `.map()`, `.filter()`, `.forEach()` over loops, unless performance-critical
- When imperative style is chosen for performance, document why
- `readonly` by default — use `readonly` arrays/tuples and `Readonly<T>` for object params
- Early returns over nesting — flat guard clauses rather than deeply nested if/else
- Composition over inheritance — small, composable functions over class hierarchies
- Avoid classes unless the domain genuinely benefits from encapsulation (e.g. wrapping a stateful SDK client)

### Type Modeling
- Use strict typing throughout
- Prefer `unknown` over `any` — force narrowing at the boundary
- Prefer explicit types for function parameters and return types
- Use `as const` where appropriate for better type inference
- Prefer interfaces over object type aliases
- Always create interfaces for "options objects" passed to hooks and helpers
- Prefer sum types: string literal unions or discriminated unions with type guards
- Prefer exhaustive matching — use `ts-pattern` if it's already in the project, otherwise use `switch` statements (as IIFEs if needed for expressions) with exhaustive checking via a `never` default or an available helper
- Prefer type inference over explicit annotations unless:
  - Necessary for portability (TS2742)
  - The inferred type is very complex and may cause type-checking performance issues
  - The inferred type is overkill for how it's referenced and hard to read in LSP popups

### Documentation
- Write clear, concise TSDoc comments above functions
- TSDoc format: separate description, @param entries, and @returns with blank lines
- Always use multi-line format (`/** ... */`)
- Don't over-document — component prop interfaces don't need docs, but non-obvious props should have them
- If told "nah doc" or "no doc", stop including TSDoc until told "ya doc"

### Exports
- Export items inline, not at the end of a file
