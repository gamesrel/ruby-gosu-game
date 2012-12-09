require 'securerandom'

module Registerable
  def registry_id
    @registry_id or raise("No ID set for #{self}")
  end

  def generate_id
    raise "#{self}: Already have ID #{@registry_id}, cannot set to #{id}" if @registry_id
    @registry_id = SecureRandom.uuid
  end

  def registry_id=(id)
    raise "#{self}: Already have ID #{@registry_id}, cannot set to #{id}" if @registry_id
    @registry_id = id
  end
end