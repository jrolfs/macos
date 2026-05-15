#!/usr/bin/env node

// Required parameters:
// @raycast.schemaVersion 1
// @raycast.title Convert to Superscript Ordinals
// @raycast.mode transform
// @raycast.packageName Text Utils
// @raycast.description Convert ordinal numbers (1st, 2nd, 3rd, etc.) to superscript versions (1ˢᵗ, 2ⁿᵈ, 3ʳᵈ, etc.)

const superscripts = {
  // Ordinal indicators using modifier letters
  'st': 'ˢᵗ',  // U+02E2 + U+1D57
  'nd': 'ⁿᵈ',  // U+207F + U+1D48
  'rd': 'ʳᵈ',  // U+02B3 + U+1D48
  'th': 'ᵗʰ'   // U+1D57 + U+02B0
};

const main = (input: string) =>
  input.replace(/(\d+)(st|nd|rd|th)\b/gi, (_, number, suffix) =>
    number + (superscripts[suffix.toLowerCase()] ?? suffix)
  );

export default main;
