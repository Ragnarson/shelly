guard 'rspec', :cli => '--color --format doc' do
  watch(%r{^spec/.+_spec\.rb$})
  watch('lib/shelly/helpers.rb') { "spec" }
  watch(%r{^lib/shelly/(.+)\.rb$})     { |m| "spec/shelly/#{m[1]}_spec.rb" }
  watch('spec/spec_helper.rb')  { "spec" }
end
