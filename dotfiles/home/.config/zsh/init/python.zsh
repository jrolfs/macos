# Fix Python SSL issue
# https://github.com/danhper/asdf-python/issues/106#issuecomment-873814320

function python-ssl {
  local certificate_path=$(python -m certifi)

  if [ -n "$certificate_path" ]; then
    export SSL_CERT_FILE=${certificate_path}
    export REQUESTS_CA_BUNDLE=${certificate_path}
  fi
}
