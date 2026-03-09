# DITA-OT Validator
# Validates DITA output using DITA-OT
# Assumes 'dita' command is on PATH

class DITAValidator
  def initialize(output_dir)
    @output_dir = output_dir
  end

  def validate(file_path)
    # Check if dita command is available
    unless system('which dita > /dev/null 2>&1')
      return { valid: true, message: 'DITA-OT not found on PATH, skipping validation' }
    end

    # Use DITA-OT validate transformation
    output = `dita --input="#{file_path}" --format=validate 2>&1`

    if $?.success? && !output.include?('Error')
      { valid: true, message: 'Validation passed' }
    else
      # Extract just the error messages
      errors = output.lines.select { |l| l.include?('Error') || l.include?('ERROR') || l.include?('[DOTJ') }
      { valid: false, message: errors.empty? ? output : errors.join }
    end
  end

  # Validate an entire output directory
  def validate_output
    return { valid: true, message: 'DITA-OT not found on PATH, skipping validation' } unless system('which dita > /dev/null 2>&1')

    # Find ditamap or dita files
    ditamap = Dir.glob(File.join(@output_dir, '*.ditamap')).first

    if ditamap
      output = `dita --input="#{ditamap}" --format=validate 2>&1`
    else
      # Validate individual files
      dita_files = Dir.glob(File.join(@output_dir, '**/*.dita'))
      return { valid: true, message: 'No DITA files to validate' } if dita_files.empty?

      errors = []
      dita_files.each do |f|
        result = `dita --input="#{f}" --format=validate 2>&1`
        errors << result unless $?.success?
      end
      output = errors.join("\n")
    end

    if output.empty? || !output.include?('Error')
      { valid: true, message: 'Validation passed' }
    else
      { valid: false, message: output }
    end
  end
end
