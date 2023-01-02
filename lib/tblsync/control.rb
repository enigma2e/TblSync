require 'socket'
require 'json'


module TblSync
    class Control
        DEFAULT_SYNC_PORT     = 8484
        DEFAULT_SYNC_PEERS    = ['OSPF-PEERS']

        FULL_SYNC_INTERVAL    = 60
        PEER_REFRESH_INTERVAL = 30
        MAC_REFRESH_INTERVAL  = 10



        def initialize(sync_port = DEFAULT_SYNC_PORT, sync_peers = DEFAULT_SYNC_PEERS)
            @sync_port = sync_port   || DEFAULT_SYNC_PORT
            @sync_peers = sync_peers ? 
                [sync_peers].flatten.map{ |peer| peer.split(",") }.flatten.map{ |peer| [peer.split(":"), @sync_port].flatten[0,2].join(":") }:
                nil
            @last_peer_refresh_at = (sync_peers == DEFAULT_SYNC_PEERS) ? Time.at(0) : nil
            @last_full_sync_at   = Time.at(0)
            @last_mac_refresh_at = Time.at(0)

            @quit = false
            @socket = UDPSocket.new()
            @socket.setsockopt(Socket::SOL_SOCKET, Socket::SO_RCVBUF, 65535)
            @socket.bind("0.0.0.0", @sync_port)
        end

        def quit()
            @quit = true
        end

        def sync_peers()
            now = Time.now
            if @last_peer_refresh_at && (now - @last_peer_refresh_at) > PEER_REFRESH_INTERVAL
                @sync_peers = `/usr/sbin/ospfctl show neighbor detail | grep -e 'Neighbor.*interface address' | cut -d ' ' -f 5`.
                    split("\n").
                    map{ |host| "#{host.strip}:#{@sync_port}" }.
                    sort
                @last_peer_refresh_at = now
            end
            return @sync_peers        
        end

        def notify_all_peers(msg)
            sync_peers.each do |peer_name|
                notify_specific_peer(peer_name, msg)
            end
        end

        def notify_single_peer(msg)
            notify_specific_peer(sync_peers.sample, msg)
        end

        def notify_specific_peer(peer_name, msg)
            host, port = peer_name.split(':')
            begin
                @socket.send(msg.to_json, 0, host, port)
            rescue => ex
                print "#{host}:#{port}: Error: #{ex}\n"
            end
        end

        def process_messages()
            loop do
                return if @quit
                msg, addr = read_message()
                yield(msg, addr) if block_given?
            end
        end

        def read_message()
            data, af, port, name, host = nil, nil, @sync_port, nil, "localhost"
            loop do
                begin
                    if IO.select([@socket], nil, nil, 5)
                        (data, (af, port, name, host)) = @socket.recvfrom(1500)
                        break
                    end
                rescue IO::WaitReadable
                    retry
                end
                now = Time.now
                if now - @last_full_sync_at > FULL_SYNC_INTERVAL
                    data = "{\"type\":\"resync\"}"
                    @last_full_sync_at = now
                    break
                end
                if now - @last_mac_refresh_at > MAC_REFRESH_INTERVAL
                    data = "{\"type\":\"refresh\"}"
                    @last_mac_refresh_at = now
                    break
                end
            end
            return [JSON.parse(data), "#{host}:#{port}"]
        rescue JSON::ParserError
            retry
        end
    end
end
