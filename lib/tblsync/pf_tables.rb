require 'open3'


module TblSync
    class PfTables
        PF_CTL = '/usr/bin/doas /sbin/pfctl'.freeze

        attr_accessor :enabled

        def initialize(enabled)
            @enabled = enabled
        end

        def update_from(main_table, is_debug = false)
            main_table.by_table.each do |(table_name,new_ip_set)|
                print "Table:#{table_name}\n" if is_debug

                old_ip_set = Set.new() #Open3.capture2e("#{PF_CTL} -t #{table_name} -T show").first.split("\n").map(&:strip).sort)
                add_count    = (new_ip_set - old_ip_set).size
                remove_count = (old_ip_set - new_ip_set).size
                print "\t   Adds:#{add_count}\n\tRemoves:#{remove_count}\n"

                if @enabled && (add_count + remove_count) > 0
                    print "\tUpdating Tables...\n"
                    Open3.popen2e("#{PF_CTL} -t #{table_name} -T replace -f -") do |input,output,t|
                        input.write(new_ip_set.sort.uniq.join("\n"))
                        input.close
                    end
                else
                    print "\tUpdates Disabled\n"
                end
            end
        end
    end
end
