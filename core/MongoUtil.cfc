<cfcomponent accessors="true">

	<cfset variables.mongoFactory="">

	<!--- initialize the MongoUtil. Pass an instance of JavaLoaderFactory to bypass the default MongoFactory
	Using a JavaLoaderFactory lets you use the libs provided with cfmongodb without adding them to your
	path and restarting CF --->
	<!--- function init(mongoFactory=""){ --->
	<cffunction name="init" access="public">
		<cfargument name="mongoFactory" required="false" default="">

		<cfscript>
			if(isSimpleValue(mongoFactory)){
				arguments.mongoFactory = createObject("component", "DefaultFactory");
			}
			variables.mongoFactory = arguments.mongoFactory;
			variables.dboFactory = mongoFactory.getObject('com.mongodb.CFBasicDBObject');
			variables.dboBuilderFactory = mongoFactory.getObject('com.mongodb.CFBasicDBObjectBuilder');
			variables.typerClass = getDocumentTyperClass();
			variables.operationTyperClass = getOperationTyperClass();
			variables.typer = mongoFactory.getObject(typerClass).getInstance();
			variables.operationTyper = mongoFactory.getObject(operationTyperClass).getInstance();
			
			return this;
		</cfscript>
	</cffunction>

	<!--- returns the typer class name to use for Document and Query objects.

		For Adobe ColdFusion, we need the CFStrictTyper because Adobe CF will treat numbers and booleans as strings.

		For Railo, we can use the "NoTyper" because Railo treats numbers as numbers and booleans as booleans --->
	<!--- public function getDocumentTyperClass(){ --->
	<cffunction name="getDocumentTyperClass" access="public">
		<cfscript>
			if( server.coldfusion.productname eq "Railo") return "net.marcesher.NoTyper";
			return "net.marcesher.CFStrictTyper";
		</cfscript>
	</cffunction>

	<!--- 
	returns a simple typer class that only concerns itself with 1, -1, and 0, which MongoDB uses
	  for operation decision making such as sorting and field selection --->
	<!--- public function getOperationTyperClass(){ --->
	<cffunction name="getOperationTyperClass" access="public">
		<cfreturn "net.marcesher.MongoDBOperationOnlyTyper">
	</cffunction>

	<!--- Create a new instance of the CFBasicDBObject. You use these anywhere the Mongo Java driver takes a DBObject --->
	<!--- function newDBObject(){ --->
	<cffunction name="newDBObject" access="public">
		<cfreturn dboFactory.newInstance(variables.typer)>
	</cffunction>

	<!--- Create a new instance of the CFBasicDBObject for use in operational (i.e. non-document-save) situations --->
	<!--- function newOperationalDBObject(){ --->
	<cffunction name="newOperationalDBObject" access="public">
		<cfreturn dboFactory.newInstance(variables.operationTyper)>
	</cffunction>

	<!--- Create a new instance of a CFBasicDBObjectBuilder --->
	<!--- function newDBObjectBuilder(){ --->
	<cffunction name="newDBObjectBuilder" access="public">
		<cfreturn dboBuilderFactory.newInstance()>
	</cffunction>

	<!--- Converts a ColdFusion structure to a CFBasicDBobject, which  the Java drivers can use --->
	<!--- function toMongo(any data){ --->
	<cffunction name="toMongo" access="public">
		<cfargument name="data" type="any">

		<cfscript>
			//for now, assume it's a struct to DBO conversion
			if( isCFBasicDBObject(data) ) return data;
			dbo = newDBObject();
			dbo.putAll( data );
			return dbo;
		</cfscript>
	</cffunction>

	<!--- Converts a ColdFusion structure to a CFBasicDBobject which ensures 1 and -1 remain ints --->
	<!--- function toMongoOperation( struct data ){ --->
	<cffunction name="toMongoOperation" access="public">
		<cfargument name="data" type="struct">

		<cfscript>
			if( isCFBasicDBObject(data) ) return data;
			dbo = newOperationalDBObject();
			dbo.putAll( data );
			return dbo;
		</cfscript>
	</cffunction>

	<!--- Converts a Mongo DBObject to a ColdFusion structure --->
	<!--- function toCF(BasicDBObject){ --->
	<cffunction name="toCF" access="public">
		<cfargument name="BasicDBObject">

		<cfscript>
			s = {};
			s.putAll(BasicDBObject);
			return s;
		</cfscript>
	</cffunction>

	<!--- Convenience for turning a string _id into a Mongo ObjectId object --->
	<!--- function newObjectIDFromID(String id){ --->
	<cffunction name="newObjectIDFromID" access="public">
		<cfargument name="id" type="string">

		<cfscript>
			if( not isSimpleValue( id ) ) return id;
			return mongoFactory.getObject("org.bson.types.ObjectId").init(id);
		</cfscript>
	</cffunction>

	<!--- Convenience for creating a new criteria object based on a string _id --->
	<!--- function newIDCriteriaObject(String id){ --->
	<cffunction name="newIDCriteriaObject" access="public">
		<cfargument name="id" type="string">

		<cfreturn newDBObject().put("_id",newObjectIDFromID(id))>
	</cffunction>


	<!--- Creates a Mongo CFBasicDBObject whose order matches the order of the keyValues argument
	keyValues can be:
	  	1) a string in k,k format: "STATUS,TS". This will set the value for each key to "1". Useful for creating Mongo's 'all true' structs, like the "keys" argument to group()
	    2) a string in k=v format: STATUS=1,TS=-1
		3) an array of strings in k=v format: ["STATUS=1","TS=-1"]
		4) an array of structs (often necessary when creating "command" objects for passing to db.command()):
		  createOrderedDBObject( [ {"mapreduce"="tasks"}, {"map"=map}, {"reduce"=reduce} ] ) --->	
	<!--- function createOrderedDBObject( keyValues, dbObject="" ){ --->
	<cffunction name="createOrderedDBObject" access="public">
		<cfargument name="keyValues">
		<cfargument name="dbObject" default="">

		<cfscript>
			if( isSimpleValue(dbObject) ){
				dbObject = newDBObject();
			}
			kv = "";
			if( isSimpleValue(keyValues) ){
				keyValues = listToArray(keyValues);
			}
			for(i = 1; i <= ArrayLen(keyValues); i++){
				kv = keyValues[i];
				if( isSimpleValue( kv ) ){
					key = listFirst(kv, "=");
					if( find("=",kv) ) {
						value = listRest(kv, "=");
					} else {
						value = 1;
					}
				} else {
					key = structKeyList(kv);
					value = kv[key];
				}
	
				dbObject.append( key, value );
			}
			return dbObject;
		</cfscript>
	</cffunction>

	<!--- function listToStruct(list){ --->
	<cffunction name="listToStruct" access="public">
		<cfargument name="list">

		<cfscript>
			item = '';
			s = {};
			i = 1;
			items = listToArray(list);
			itemCount = arrayLen(items);
			for(i; i lte itemCount; i++) {
				s.put(items[i],1);
			}
			return s;
		</cfscript>
	</cffunction>

	<!--- Extracts the timestamp from the Doc's ObjectId. This represents the time the document was added to MongoDB --->
	<!--- function getDateFromDoc( doc ){ --->
	<cffunction name="getDateFromDoc" access="public">
		<cfargument name="doc">

		<cfscript>
			ts = doc["_id"].getTime();
			return createObject("java", "java.util.Date").init(ts);
		</cfscript>
	</cffunction>

	<!--- Whether this doc is an instance of a CFMongoDB CFBasicDBObject --->
	<!--- function isCFBasicDBObject( doc ){ --->
	<cffunction name="isCFBasicDBObject" access="public">
		<cfargument name="doc">

		<cfreturn NOT isSimpleValue( doc ) AND getMetadata( doc ).getCanonicalName() eq "com.mongodb.CFBasicDBObject">
	</cffunction>

</cfcomponent>
