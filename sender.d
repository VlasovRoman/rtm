import std.stdio : writeln;
import std.socket;
import std.datetime;
import std.getopt;
import std.file;
import std.conv;

interface 	Hardware {
	float[] 	getTemperature();
}

//class WindowsOS : Hardware {
//	override float[] 	getTemperature() {return [];};
//}

version(Posix)
{
	class PosixOS : Hardware {
		this() {
			assert(exists(dir), "Directory with temp files is not exists");

			auto files = dirEntries(
				dir,
				"*_input",
				SpanMode.depth,
				false);

			foreach(d; files) {
				coreFilenames ~= d.name;
			}
		}

		override float[] 	getTemperature() {
			float[] temp;

			foreach(file; coreFilenames) {
				auto data = to!string(read(file));
				temp ~= to!float(data[0..$-4]);
			}

			return temp;
		}

		enum dir = "/sys/devices/platform/coretemp.0/hwmon/";

		string[]	coreFilenames;
	}
}

void main(string[] args) {
	int durationInMS = 1000;
	string ip = "localhost:2015";
	string name = "Sender";

	auto result = getopt(args,
		"p", "period", &durationInMS,
		"i", "ip", &ip,
		"n", "name of sender", &name);

	if(result.helpWanted) {
		defaultGetoptPrinter("Some info about the program.", result.options);
	}

	writeln("The sending period is set to ", durationInMS, " mseconds");

	auto address = new InternetAddress(2015);
	address.parse(ip);

	auto listenerSocket = new TcpSocket();

	listenerSocket.connect(address);

	writeln("The connection is established!");

	auto received = listenerSocket.send(name);

	if(received == Socket.ERROR) {
		writeln("Error.");
		listenerSocket.close();
	}

	version(Posix) {
		auto hard = new PosixOS;
	}
	//version(Windows) {
	//	auto hard = new WindowsOS;
	//}

	auto ct = Clock.currTime;

	while(listenerSocket.isAlive()) {
		auto nt = Clock.currTime;

		auto dr = (nt - ct);

		if(dr.total!"msecs" >= durationInMS) {
			ct = Clock.currTime;

			string buffer = to!string(hard.getTemperature());

			received = listenerSocket.send(buffer);

			if(received == Socket.ERROR) {
				writeln("Error");
				listenerSocket.close();
			}
		}
	}

	scope(exit) {
		listenerSocket.close();
	}
}
