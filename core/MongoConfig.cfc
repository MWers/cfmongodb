<cfcomponent accessors="true" output="false" hint="Main configuration information for MongoDb connections. Defaults are provided, but should be overridden as needed in subclasses. ">

	<cfset variables.environment = "local">
	<cfset variables.mongoFactory = "">

	<cfscript>
	variables.environment = "local";
	variables.conf = {};
	</cfscript>

	<!--- 
	* Constructor
	* @hosts Defaults to [{serverName='localhost',serverPort='27017'}]
	--->
	<!--- public function init(Array hosts, dbName='default_db', MongoFactory="#createObject('DefaultFactory')#"){ --->
	<cffunction name="init" access="public">
		<cfargument name="hosts" type="array">
		<cfargument name="dbName" required="false" default="default_db">
		<cfargument name="MongoFactory" required="false" default="#createObject('component','DefaultFactory')#">

		<cfscript>
			if (!structKeyExists(arguments, 'hosts') || arrayIsEmpty(arguments.hosts)) {
				host = {serverName='localhost',serverPort='27017'};
				arguments.hosts = [host];
			}
	
			variables.mongoFactory = arguments.mongoFactory;
			establishHostInfo();
	
			auth = {username="",password=""};
			variables.conf = { dbname = dbName, servers = mongoFactory.getObject('java.util.ArrayList').init(), auth=auth };
	
			item = "";
			//for(item in arguments.hosts){
			for( i = 1; i <= ArrayLen(arguments.hosts); i++) {
				item = arguments.hosts[i];
				addServer( item.serverName, item.serverPort );
			}
	
			//main entry point for environment-aware configuration; subclasses should do their work in here
			environment = configureEnvironment();
	
			return this;
		</cfscript>
	</cffunction>

	<!--- public function addServer(serverName, serverPort){ --->
	<cffunction name="addServer" access="public">
		<cfargument name="serverName">
		<cfargument name="serverPort">
		
		<cfscript>
			sa = mongoFactory.getObject("com.mongodb.ServerAddress").init( serverName, serverPort );
			variables.conf.servers.add( sa );
			return this;
		</cfscript>
	</cffunction>

	<!--- public function removeAllServers(){ --->
	<cffunction name="removeAllServers" access="public">		
		<cfscript>
			variables.conf.servers.clear();
			return this;
		</cfscript>
	</cffunction>

    <!--- public function establishHostInfo(){ --->
	<cffunction name="establishHostInfo" access="public">
		<cfscript>
			// environment decisions can often be made from this information
			inetAddress = createObject( "java", "java.net.InetAddress");
			variables.hostAddress = inetAddress.getLocalHost().getHostAddress();
			variables.hostName = inetAddress.getLocalHost().getHostName();
			return this;
		</cfscript>
	</cffunction>

	<!--- /**
	* Main extension point: do whatever it takes to decide environment;
	* set environment-specific defaults by overriding the environment-specific
	* structure keyed on the environment name you decide
	*/ --->
	<!--- public string function configureEnvironment(){ --->
	<cffunction name="configureEnvironment" access="public" returnType="string">
		<cfscript>
			//overriding classes could do all manner of interesting things here... read config from properties file, etc.
			return "local";
		</cfscript>
	</cffunction>

	<!--- public string function getDBName(){ ---> 
	<cffunction name="getDBName" access="public" returnType="string">
		<cfscript>
			return getDefaults().dbName;
		</cfscript>
	</cffunction>

	<!--- public Array function getServers(){ --->
	<cffunction name="getServers" access="public" returnType="array">
		<cfscript>
			return getDefaults().servers;
		</cfscript>
	</cffunction>

	<!--- public struct function getDefaults(){ --->
	<cffunction name="getDefaults" access="public" returnType="struct">		
		<cfscript>
			return conf;
		</cfscript>
	</cffunction>

	<cffunction name="getMongoFactory" access="public">
		<cfreturn variables.mongoFactory>
	</cffunction>

	<cffunction name="setMongoFactory" access="public">
		<cfargument name="mongoFactory">
	
		<cfscript>
				variables.mongoFactory = arguments.mongoFactory;
		</cfscript>
	</cffunction>
	
</cfcomponent>