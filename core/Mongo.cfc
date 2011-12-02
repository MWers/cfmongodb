<cfcomponent accessors="true">

	<cfset variables.mongoConfig = "">
	<cfset variables.mongoFactory = "">
	<cfset variables.mongoUtil = "">

	<!---
	You can init CFMongoDB in two ways:
	   1) drop the included jars into your CF's lib path (restart CF)
	   2) use Mark Mandel's javaloader (included). You needn't restart CF)

	   --1: putting the jars into CF's lib path
		mongoConfig = createObject('component','cfmongodb.core.MongoConfig').init(dbName="mongorocks");
		mongo = createObject('component','cfmongodb.core.Mongo').init(mongoConfig);

	   --2: using javaloader
		javaloaderFactory = createObject('component','cfmongodb.core.JavaloaderFactory').init();
		mongoConfig = createObject('component','cfmongodb.core.MongoConfig').init(dbName="mongorocks", mongoFactory=javaloaderFactory);
		mongo = createObject('component','cfmongodb.core.Mongo').init(mongoConfig);

	  Note that authentication credentials, if set in MongoConfig, will be used to authenticate against the database.
	 --->
	<!--- function init(MongoConfig="#createObject('MongoConfig')#"){ --->
	<cffunction name="init" access="public">
		<cfargument name="MongoConfig" required="false" default="#createObject('component','MongoConfig')#">
	
		<cfscript>
			setMongoConfig(arguments.MongoConfig);
			setMongoFactory(mongoConfig.getMongoFactory());
			variables.mongo = variables.mongoFactory.getObject("com.mongodb.Mongo");
			initCollections();
	
			if( arrayLen( mongoConfig.getServers() ) GT 1 ){
				variables.mongo.init(variables.mongoConfig.getServers());
			} else {
				servers = mongoConfig.getServers();
				_server = servers[1];
				variables.mongo.init( _server.getHost(), _server.getPort() );
			}
	
			setMongoUtil(createObject('component','MongoUtil').init(mongoFactory));
	
			return this;
		</cfscript>
	</cffunction>

	<!--- private function initCollections(){ --->
	<cffunction name="initCollections" access="private">
		<cfscript>
			dbName = getMongoConfig().getDBName();
			emptyStruct = {};
			variables.collections = { dbName = emptyStruct };
		</cfscript>
	</cffunction>
	
	<!--- 
	Authenticates connection/db with given name and password

		Typical usage:
		mongoConfig.init(...);
		mongo = new Mongo( mongoConfig );
		mongo.authenticate( username, password );

		If authentication fails, an error will be thrown
	 --->
	<!--- void function authenticate( string username, string password ){ --->
	<cffunction name="authenticate" access="public">
		<cfargument name="username" type="string">
		<cfargument name="password" type="string">
		
		<cfscript>
			emptyStruct = {};
			result = {authenticated = false, error=emptyStruct};
			result.authenticated = getMongoDB( variables.mongoConfig ).authenticateCommand( arguments.username, arguments.password.toCharArray() );
		</cfscript>
	</cffunction>

	<!--- Adds a user to the database --->
	<!--- function addUser( string username, string password) { --->
	<cffunction name="addUser" access="public">
		<cfargument name="username" type="string">
		<cfargument name="password" type="string">
		
		<cfscript>
			getMongoDB( variables.mongoConfig ).addUser(arguments.username, arguments.password.toCharArray());
			return this;
		</cfscript>
	</cffunction>

	<!--- Drops the database currently specified in MongoConfig --->
	<!--- function dropDatabase() { --->
	<cffunction name="dropDatabase" access="public">
		<cfscript>
			variables.mongo.dropDatabase(variables.mongoConfig.getDBName());
			return this;
		</cfscript>
	</cffunction>

	<!--- Gets a CFMongoDB DBCollection object, which wraps the java DBCollection --->
	<!--- function getDBCollection( collectionName ){ --->
	<cffunction name="getDBCollection" access="public">
		<cfargument name="collectionName">
		
		<cfscript>
			if( not structKeyExists( variables.collections, collectionName ) ){
				variables.collections[ collectionName ] = createObject("component", "DBCollection" ).init( collectionName, this );
			}
			return variables.collections[ collectionName ];
		</cfscript>
	</cffunction>

	<!--- Closes the underlying mongodb object. Once closed, you cannot perform additional mongo operations and you'll need to init a new mongo.
	  Best practice is to close mongo in your Application.cfc's onApplicationStop() method. Something like:
	  getBeanFactory().getBean("mongo").close();
	  or
	  application.mongo.close()

	  depending on how you're initializing and making mongo available to your app

	  NOTE: If you do not close your mongo object, you WILL leak connections!
	 --->
	<!--- function close(){ --->
	<cffunction name="close" access="public">
		<cfscript>
			try{
				variables.mongo.close();
			}catch(any e){
				//the error that this throws *appears* to be harmless.
				writeLog("Error closing Mongo: " & e.message);
			}
			return this;
		</cfscript>
	</cffunction>

	<!--- Returns the last error for the current connection. --->
	<!--- function getLastError() --->
	<cffunction name="getLastError" access="public">
		<cfreturn getMongoDB().getLastError()>
	</cffunction>

	<!--- Decide whether to use the MongoConfig in the variables scope, the one being passed around as arguments, or create a new one --->
	<!--- function getMongoConfig(mongoConfig=""){ --->
	<cffunction name="getMongoConfig" access="public">
		<cfargument name="mongoConfig" required="false" default="">
	
		<cfscript>
			if(isSimpleValue(arguments.mongoConfig)){
				mongoConfig = variables.mongoConfig;
			}
			return mongoConfig;
		</cfscript>
	</cffunction>

	<cffunction name="setMongoConfig" access="public">
		<cfargument name="mongoConfig">
	
		<cfscript>
			variables.mongoConfig = arguments.mongoConfig;
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

	<cffunction name="getMongoUtil" access="public">
		<cfreturn variables.mongoUtil>
	</cffunction>

	<cffunction name="setMongoUtil" access="public">
		<cfargument name="mongoUtil">
	
		<cfscript>
			variables.mongoUtil = arguments.mongoUtil;
		</cfscript>
	</cffunction>

	<!--- Get the underlying Java driver's Mongo object --->
	<!--- function getMongo(){ --->
	<cffunction name="getMongo" access="public">
		<cfreturn variables.mongo>
	</cffunction>

	<!--- Get the underlying Java driver's DB object --->
	<!--- function getMongoDB( mongoConfig="" ){ --->
	<cffunction name="getMongoDB" access="public">
		<cfargument name="mongoConfig" required="false" default="">
		
		<cfscript>
			jMongo = getMongo(mongoConfig);
			return jMongo.getDb(getMongoConfig(mongoConfig).getDefaults().dbName);
		</cfscript>
	</cffunction>

	<!--- Deprecated. See DBCollection.findById() --->
	<!--- function findById( id, string collectionName ){ --->
	<cffunction name="findById" access="public">
		<cfargument name="id">
		<cfargument name="collectionName" type="string">
		
		<cfreturn getDBCollection( collectionName ).findById( id )>
	</cffunction>

	<!--- Deprecated. See DBCollection.query() --->
	<!--- function query(string collectionName, mongoConfig=""){ --->
	<cffunction name="query" access="public">
		<cfargument name="collectionName" type="string">
		<cfargument name="mongoConfig" required="false" default="">
		
		<cfreturn getDBCollection( collectionName ).query()>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.distinct() --->
	<!--- function distinct( string key, string collectionName ){ --->
	<cffunction name="distinct" access="public">
		<cfargument name="key" type="string">
		<cfargument name="collectionName" type="string">
		
		<cfreturn getDBCollection( collectionName ).distinct( key )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.findAndModify --->
	<!--- function findAndModify( struct query, struct fields, any sort, boolean remove=false, struct update, boolean returnNew=true, boolean upsert=false, boolean overwriteExisting=false, string collectionName ){ --->
	<cffunction name="findAndModify" access="public">
		<cfargument name="query" type="struct">
		<cfargument name="fields" type="struct">
		<cfargument name="sort" type="any">
		<cfargument name="remove" type="boolean" default="false">
		<cfargument name="update" type="struct">
		<cfargument name="returnNew" type="boolean" default="true">
		<cfargument name="upsert" type="boolean" default="false">
		<cfargument name="overwriteExisting" type="boolean" default="false">
		<cfargument name="collectionName" type="string">
				
		<cfreturn getDBCollection(collectionName).findAndModify( argumentcollection=arguments )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.group() --->
	<!--- function group( collectionName, keys, initial, reduce, query, keyf="", finalize="" ){ --->
	<cffunction name="group" access="public">
		<cfargument name="collectionName">
		<cfargument name="keys">
		<cfargument name="initial">
		<cfargument name="reduce">
		<cfargument name="query">
		<cfargument name="keyf" default="">
		<cfargument name="finalize" default="">
		
		<cfreturn getDBCollection( collectionName ).group( argumentcollection = arguments )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.mapReduce() --->
	<!--- function mapReduce( collectionName, map, reduce, outputTarget, outputType="REPLACE", query, options  ){ --->
	<cffunction name="mapReduce" access="public">
		<cfargument name="collectionName">
		<cfargument name="map">
		<cfargument name="reduce">
		<cfargument name="outputTarget">
		<cfargument name="outputType" default="REPLACE">
		<cfargument name="query">
		<cfargument name="options">
		
		<cfreturn getDBCollection( collectionName ).mapReduce( argumentCollection = arguments )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.save() --->
	<!--- function save( struct doc, string collectionName ){ --->
	<cffunction name="save" access="public">
		<cfargument name="doc" type="struct">
		<cfargument name="collectionName" type="string">
		
		<cfreturn getDBCollection( collectionName ).save( doc )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.saveAll() --->
	<!--- function saveAll( array docs, string collectionName ){ --->
	<cffunction name="saveAll" access="public">
		<cfargument name="docs" type="array">
		<cfargument name="collectionName" type="string">
		
		<cfreturn getDBCollection( collectionName ).saveAll( docs )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.update() --->
	<!--- function update( doc, collectionName, query, upsert=false, multi=false, overwriteExisting=false ){ --->
	<cffunction name="update" access="public">
		<cfargument name="doc">
		<cfargument name="collectionName">
		<cfargument name="query">
		<cfargument name="upsert" type="boolean" default="false">
		<cfargument name="multi" type="boolean" default="false">
		<cfargument name="overwriteExisting" type="boolean" default="false">
		
		<cfreturn getDBCollection( collectionName ).update( argumentCollection=arguments )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.remove() --->
	<!--- function remove(doc, collectionName ){ --->
	<cffunction name="remove" access="public">
		<cfargument name="doc">
		<cfargument name="collectionName">
		
		<cfreturn getDBCollection( collectionName ).remove( doc )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.removeById() --->
	<!--- function removeById( id, collectionName ){ --->
	<cffunction name="removeById" access="public">
		<cfargument name="id">
		<cfargument name="collectionName">
		
		<cfreturn getDBCollection( collectionName ).removeById( id )>
	</cffunction>

	<!--- Deprecated. See DBCollection.ensureIndex() --->
	<!--- public array function ensureIndex( array fields, collectionName, unique=false ){ --->
	<cffunction name="ensureIndex" access="public">
		<cfargument name="fields" type="array">
		<cfargument name="collectionName">
		<cfargument name="unique" type="boolean" default="false">
		
		<cfreturn getDBCollection( collectionName ).ensureIndex( fields, unique )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.ensureGeoIndex() --->
	<!--- public array function ensureGeoIndex( field, collectionName, min="", max="" ){ --->
	<cffunction name="ensureGeoIndex" access="public">
		<cfargument name="field">
		<cfargument name="collectionName">
		<cfargument name="min" default="">
		<cfargument name="max" default="">
		
		<cfreturn getDBCollection( collectionName ).ensureGeoIndex( field, min, max )>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.getIndexes() --->
	<!--- public array function getIndexes( collectionName ){ --->
	<cffunction name="getIndexes" access="public">
		<cfargument name="collectionName">
				
		<cfreturn getDBCollection( collectionName ).getIndexes()>
	</cffunction>
	
	<!--- Deprecated. See DBCollection.dropIndexes() --->
	<!--- public array function dropIndexes(collectionName, mongoConfig=""){ --->
	<cffunction name="dropIndexes" access="public">
		<cfargument name="collectionName">
		<cfargument name="mongoConfig" default="">
		
		<cfreturn getDBCollection( collectionName ).dropIndexes()>
	</cffunction>
		
	<!--- Deprecated. See DBCollection.getMongoDBCollection() --->
	<!--- function getMongoDBCollection( collectionName="" ){ --->
	<cffunction name="getMongoDBCollection" access="public">
		<cfargument name="collectionName" default="">
		
		<cfreturn getDBCollection( collectionName ).getMongoDBCollection()>
	</cffunction>
	
</cfcomponent>
 