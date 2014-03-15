require "socket"
require "uri"

Dir.chdir File.dirname(__FILE__)
pwd = Dir.pwd
document_root = "#{pwd}/httpdocs"
logger = document_root + "/raw.log"
index_files = ["index.html", "index.htm", "home.html", "home.htm", "default.html", "default.htm", ]

host = 'localhost'
port = 8080
server = TCPServer.new(host, port)
server.setsockopt(Socket::SOL_SOCKET, Socket::SO_REUSEADDR, 1)
puts "Listening @#{host} on port #{port}"

RFC_EOH = "\r\n"
response = Hash.new
response["404"] = Hash.new
response["404"][:body]   = "<html><head><title>Page Not Found</title></head><body><h1>404</h1><p>Sorry your request is futile!</p></body></html>"
response["404"][:header] = "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
response["501"] = Hash.new
response["501"][:body]   = "<html><head><title>Method Not Implemented</title></head><body><h1>501</h1><p>The reques metod used is not implemented yet!</p></body></html>"
response["501"][:header] = "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n",

loop do
    Thread.start(server.accept) do |client|

        # get the whole request
        # @todo verify if must/should trim ending CR LF and empty lines from headers
        #
        # See RFC :
        #     - http://www.w3.org/Protocols/rfc2616/rfc2616-sec2.html#sec2.2
        #     - http://www.w3.org/Protocols/rfc2616/rfc2616-sec4.html#sec4
        request_headers = []
        loop do
            request_headers.push client.gets
            break if request_headers.last == RFC_EOH
        end

        # Log request
        File.open(logger, "a") do |content|
            content.write "[#{Time.now}] #{request_headers.join}\n"
        end
        print "[#{Time.now}] Incoming request #{request_headers.join}"

        # parse request
        request = {
            :method => request_headers.first.split(" ")[0],
            :script => request_headers.first.split(" ")[1],
            :versio => request_headers.first.split(" ")[2]
        }
        case request[:method]
        when "HEAD"
            # set NO BODY RESPONSE
        when "GET"
            begin
                request[:script] = document_root + URI.unescape(request[:script])
                request[:script] = File.realpath request[:script]

                if File.directory? request[:script]
                    available_indexes = index_files.select {|idx| File.exist? "#{request[:script]}/#{idx}" }
                    unless available_indexes.first.nil?
                        request[:script] += "/#{available_indexes.first}"
                    else
                        # 404 no index page for directory
                        raise "File (index) not found"
                    end
                end

                # @todo implement 403 ?!
                raise "Unallowed resource" unless request[:script].index(document_root) == 0

                # really needed ? isn't realpath allready checking this ?!
                if File.exist?(request[:script]) and File.file?(request[:script]) and File.readable?(request[:script])
                    File.open(request[:script], "r") do |content|
                        client.write "HTTP/1.1 200/OK\r\nContent-type:text/html\r\n\r\n"
                        client.write content.read
                    end
                else
                    raise "Can't read the requested file"
                end
            rescue
                client.write response["404"][:header]
                client.write response["404"][:body]
            end
        else
            client.write response["501"][:header]
            client.write response["501"][:body]
        end

        client.close

    end

    Signal.trap ("INT" ) do |sigint|
        puts "Fuk U Beach!"
        exit
    end
    Signal.trap ("TERM") do |sigint|
        puts "goodbye:"
        exit
    end
    Signal.trap ("QUIT") do |sigint|
        puts "bye!"
        exit
    end
    Signal.trap ("ABRT") do |sigint|
        puts "Emergency?!"
        exit
    end

end
