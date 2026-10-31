target :core_mcp do
  library 'base64'
  library 'date'
  library 'erb'
  library 'json'
  signature 'sig'
  check 'lib'

  configure_code_diagnostics(Steep::Diagnostic::Ruby.default) do |diagnostics|
    diagnostics[Steep::Diagnostic::Ruby::UnannotatedEmptyCollection] = nil
  end
end
