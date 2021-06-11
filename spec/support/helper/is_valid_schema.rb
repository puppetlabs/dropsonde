# frozen_string_literal: true

require 'rspec/expectations'

def is_valid_schema(schema)
  return [false, 'schema is not an Araay'] unless schema.is_a?(Array)

  return [false, 'schema to have key "name" defined'] unless schema[0].keys.find { |item| item == :name }
  return [false, 'the name value to be a String'] unless schema[0][:name].is_a?(String)

  return [false, 'schema to have key "type" defined'] unless schema[0].keys.find { |item| item == :type }

  bq_datatypes = %w[INT64 FLOAT64 INTEGER NUMERIC BIGNUMERIC BOOL STRING BYTES DATE DATETIME TIME TIMESTAMP STRUCT RECORD GEOGRAPHY]
  unless bq_datatypes.include?(schema[0][:type])
    return [false,
            'the type to be one of [INT64 FLOAT64 INTEGER NUMERIC BIGNUMERIC BOOL STRING BYTES DATE DATETIME TIME TIMESTAMP STRUCT RECORD GEOGRAPHY]']
  end

  if schema[0].keys.find { |item| item == :mode }
    return [false, 'the mode to be one of [NULLABLE REQUIRED REPEATED]'] unless %w[NULLABLE REQUIRED REPEATED].include?(schema[0][:mode])
    return is_valid_schema(schema[0][:fields]) if schema[0][:mode] == 'REPEATED'
  end
  [true, '']
end

RSpec::Matchers.define :be_a_valid_schema do
  match do |actual|
    is_valid_schema(actual)[0] == true
  end
  failure_message do |actual|
    "expected #{is_valid_schema(actual)[1]}"
  end
end
