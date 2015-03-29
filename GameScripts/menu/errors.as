import version;

void init() {
	string ver = SCRIPT_VERSION;
	int pos = ver.findLast(" ");
	if(pos != -1)
		ver = ver.substr(pos+2);
	errorVersion = toUInt(ver);
}