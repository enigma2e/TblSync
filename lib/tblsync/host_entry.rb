require 'set'
require 'securerandom'


module TblSync
    class HostEntry
        RANDOM_PHYSICAL_ADDRESS = '00:00:00:00:00:00'

        def self.random_physical_address()
            return ("32dbe8" + SecureRandom.hex(3)).match(/^(..)(..)(..)(..)(..)(..)$/){ |md| md[1..6].join(":") }
        end


        attr_reader :physical_address, :name, :description, :hostname, :ip_addresses, :tables, :version, :purge_at
        attr_writer :name, :description, :hostname, :ip_addresses, :tables, :version, :purge_at

        def initialize(attrs = {})
            @physical_address = (attrs['physical_address'] || RANDOM_PHYSICAL_ADDRESS).to_s.downcase.gsub(/[-: ]/, '').match(/^(..)(..)(..)(..)(..)(..)$/){ |md| md[1..6].join(":") }
            @physical_address = self.class.random_physical_address() if @physical_address == RANDOM_PHYSICAL_ADDRESS

            @name             = attrs['name']
            @description      = attrs['description']
            @hostname         = attrs['hostname']
            @ip_addresses     = Set.new(attrs['ip_addresses'])
            @tables           = Set.new(attrs['tables'])
            @version          = attrs['version']&.to_i || 0
            @purge_at         = (attrs['purge_at'].nil?) ? nil : Time.at(attrs['purge_at'])
        end

        def to_s()
            return "#<TableEntry Name:#{@name};PhysAddr:#{@physical_address};IpAddr:#{@ip_addresses.join(",")};V:#{@version}>"
        end

        def to_h()
            return {
                'physical_address' => @physical_address.to_s,
                'name'             => @name.to_s,
                'description'      => @description.to_s,
                'hostname'         => @hostname.to_s,
                'ip_addresses'     => @ip_addresses.to_a.map(&:to_s),
                'tables'           => @tables.to_a.map(&:to_s),
                'version'          => @version.to_i,
                'purge_at'         => @purge_at&.to_i,
            }
        end

        def to_json(opts = {})
            return to_h.to_json(opts)
        end
    end
end
