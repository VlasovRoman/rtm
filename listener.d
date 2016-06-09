import std.stdio : writeln;
import std.socket;
import std.conv;
import std.algorithm : remove;
import std.getopt;

struct Sender {
	string name;
	Socket sock;

	this(string name, Socket sock) {
		this.name = name;
		this.sock = sock;
	}
}

bool getString(Socket sock, out string output) {
	char[1024] buf;
	auto dataLength = sock.receive(buf);
	
	if(dataLength != 0) {
		output = to!(string)(buf[0..dataLength]);

		return true;
	}
	else if(dataLength == Socket.ERROR)
		writeln("Connection error");
	
	else {
		writeln("Connection closed");
	}

	output = "";

	return false;
}

void main(string[] args) {
	ushort listenedPort = 2015;

	auto result = getopt(args,
		"p", "port", &listenedPort);

	if(result.helpWanted) {
		defaultGetoptPrinter("Some info about the program.", result.options);
	}

	auto listenerSocket = new TcpSocket();
	listenerSocket.bind(new InternetAddress(listenedPort));

	listenerSocket.listen(0);

	enum MaxConnection = 60;

	auto sendersSet = new SocketSet(MaxConnection + 1);
	Sender[] senders;

	for(;;) {
		sendersSet.add(listenerSocket);

		foreach(sender; senders) {
			sendersSet.add(sender.sock);
		}

		Socket.select(sendersSet, null, null);

		foreach(i, sender; senders) {
			if(sendersSet.isSet(sender.sock)) {
				string buffer;
				
				if(sender.sock.getString(buffer)){
					writeln("by ", sender.name, ": ");
					writeln(buffer);
					continue;
				}

				sender.sock.close();
				senders = senders.remove(i);
				i--;

			}		
		}

		if(sendersSet.isSet(listenerSocket)) {
			Socket newSenderSocket = listenerSocket.accept();
			
			string name;			
			if(newSenderSocket.getString(name)) {
				writeln("New connection: ", name);
				Sender sender = Sender(name, newSenderSocket);
				senders ~= sender;
			}
		}
		sendersSet.reset();
	}

	scope(exit) {
		listenerSocket.close();
	}
}
