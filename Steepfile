target :core_mcp do
  library 'base64'
  library 'date'
  library 'erb'
  library 'json'
  library 'uri'
  signature 'sig'
  signature 'sig_dependencies'
  check 'lib'

  configure_code_diagnostics(Steep::Diagnostic::Ruby.default) do |diagnostics|
    diagnostics[Steep::Diagnostic::Ruby::UnannotatedEmptyCollection] = nil
  end
end
