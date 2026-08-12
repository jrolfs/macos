# ╌╌↘
#
# Format and clean up an SVG with svgo and print the result to stdout.
# Accepts a local file path, a remote URL, or an SVG string piped via stdin.
#
# ```sh
#   svg-fmt ./logo.svg
#   svg-fmt https://www.sfmta.com/themes/custom/fp_theme/logo.svg
#   pbpaste | svg-fmt
# ```
#
# ╌╌↗
svg-fmt() {
  local svg_source="$1"

  if [[ -z "$svg_source" || "$svg_source" == "-" ]] && [[ -t 0 ]]; then
    print -u2 "usage: svg-fmt <url-or-path>  (or pipe an SVG via stdin)"
    return 1
  fi

  local temporary_directory config_file
  temporary_directory=$(mktemp -d)
  config_file="$temporary_directory/svgo-config.mjs"

  cat > "$config_file" << 'EOF'
export default {
  multipass: true,
  plugins: [
    {
      name: 'preset-default',
    },
    'removeStyleElement',
    {
      name: 'removeAttrs',
      params: { attrs: 'class' }
    },
  ]
};
EOF

  if [[ -z "$svg_source" || "$svg_source" == "-" ]]; then
    cat
  elif [[ -f "$svg_source" ]]; then
    cat "$svg_source"
  else
    curl -sL "$svg_source"
  fi | pnpm dlx svgo --config="$config_file" -i - -o - --pretty --indent=2

  rm -rf "$temporary_directory"
}
