require 'singleton'
require 'open3'
require 'set'


module TblSync
    class AddressMapper
        include Singleton

        AddressMapping = Struct.new(:ip_address, :physical_address, :interface, :expiration)

        TABLE_GENERATORS = [
            "/usr/sbin/arp -an | sed -E \"s/ +/|/g\"",
            "/usr/sbin/ndp -an | sed -E \"s/ +/|/g\"",
        ].freeze


        def initialize()
            @table = {}
            refresh()
        end

        def refresh()
            @table = TABLE_GENERATORS.
                map{ |cmd| (Open3.capture2e(cmd)).first.split("\n").drop(1) }.
                flatten.
                map{ |line| AddressMapping.new(*(line.split("|")[0..3])) }.
                select{ |mapping| mapping.physical_address != "(incomplete)" }
            @table.each do |mapping|
                mapping.ip_address.gsub!(/%.*/, '')
            end
        end

        def entries
            return @table
        end

        def phys_to_ip(addr)
            return Set.new( @table.select{ |mapping| mapping.physical_address == addr }.map(&:ip_address) )
        end

        def ip_to_phys(addr)
            return Set.new( @table.select{ |mapping| mapping.ip_address == addr }.map(&:physical_address) )
        end
    end
end
