
module TblSync
    class AddressTable
        SYNC_DB_ADDR = "ff:ff:ff:ff:ff:fe".freeze


        def initialize(db_file)
            @db_file = db_file
            @table = {}
            load()

            # A special entry that has its version updated every time any entry is updated
            update(TblSync::HostEntry.new(
                'physical_address' => SYNC_DB_ADDR,
                'name'             => "SYNC DB",
                'description'      => "SYNC DB",
                'ip_addresses'     => [],
                'tables'           => [],
                'version'          => -1,
                'purge_at'         => nil,
            ))
        end

        def load()
            @table = JSON.parse(File.read(@db_file)).
                map{ |attr| TblSync::HostEntry.new(attr) }.
                reduce({}) { |h,entry| h.merge(entry.physical_address => entry) }
            return self
        end

        def update(new_host_entry)
            if (! @table.has_key?(new_host_entry.physical_address)) || (@table[new_host_entry.physical_address].version < new_host_entry.version)
                @table[new_host_entry.physical_address] = new_host_entry
                return ! (new_host_entry.physical_address == SYNC_DB_ADDR)
            else
                return false
            end
        end

        def purge!()
            now = Time.now
            expired_entries = @table.values.select{ |entry| entry.purge_at && entry.purge_at <= now }.map(&:physical_address)
            return false if expired_entries.size == 0
            @table.delete(*expired_entries)
            return true
        end

        def commit!()
            File.write(@db_file, JSON.pretty_generate(@table.values))
        end

        def db_ver()
            return @table[SYNC_DB_ADDR]
        end

        def entries()
            return @table.reject{ |(k,v)| k == SYNC_DB_ADDR }.values
        end

        def find_by_physical_address(physical_address)
            return @table[physical_address]
        end

        def by_table()
            return @table.
                values.
                map{ |entry| entry.tables.map{ |tbl| [tbl, Set.new(entry.ip_addresses)] } }.
                flatten(1).
                group_by{ |(tbl, ip_set)| tbl }.
                transform_values{ |sets| Set.new( sets.map(&:last).reduce(&:merge).sort ) }
        end
    end
end
