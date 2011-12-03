<cfcomponent accessors="true">

	<cfset variables.mongoUtil="">

	<cfscript>
		variables.collectionName = "";
		variables.mongo = "";
	
		//these are the underlying java objects
		variables.mongoDB = "";
		variables.collection = "";
	</cfscript>

	<!--- Not intended to be invoked directly. Always fetch DBCollection objects via mongo.getDBCollection( collectionName ) --->
	<!--- function init( collectionName, mongo ){ --->
	<cffunction name="init" access="public">
		<cfargument name="collectionName">
		<cfargument name="mongo">

		<cfscript>
			structAppend( variables, arguments );
			variables.mongoUtil = mongo.getMongoUtil();
			variables.mongoConfig = mongo.getMongoConfig();
	
			variables.mongoDB = getMongoDB();
			variables.collection = mongoDB.getCollection( collectionName );
	
			return this;
		</cfscript>
	</cffunction>

	<!--- private function toMongo( doc ){ --->
	<cffunction name="toMongo" access="private">
		<cfargument name="doc">
		
		<cfreturn mongoUtil.toMongo( doc )>
	</cffunction>

	<!--- private function toMongoOperation( doc ){ --->
	<cffunction name="toMongoOperation" access="private">
		<cfargument name="doc">
		
		<cfreturn mongoUtil.toMongoOperation( doc )>
	</cffunction>

	<!--- private function toCF( dbObject ){ --->
	<cffunction name="toCF" access="private">
		<cfargument name="dbObject">
		
		<cfscript>
			if( NOT StructKeyExists( arguments, "dbObject" ) ){
				return javacast("null","");
			}
			return mongoUtil.toCF( dbObject );
		</cfscript>
	</cffunction>

	<!--- Get the underlying Java driver's DB object --->
	<!--- private function getMongoDB(){ --->
	<cffunction name="getMongoDB" access="private">
		<cfreturn variables.mongo.getMongo().getDb( variables.mongo.getMongoConfig().getDBName() )>
	</cffunction>

	<!--- Get the underlying Java driver's DBCollection object for the given collection --->
	<!--- function getMongoDBCollection(){ --->
	<cffunction name="getMongoDBCollection" access="public">
		<cfreturn variables.collection>
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

	<!--- function getNothing(){}; --->
	<cffunction name="getNothing" access="public">
		<cfreturn>
	</cffunction>
	
	<!--- Returns a single document matching the passed in id (i.e. the mongo _id)
		usage:
			byID = collection.findById( url.personId ); --->
	<!--- function findById( id ){ --->
	<cffunction name="findById" access="public">
		<cfargument name="id">
		
		<cfreturn toCF( collection.findOne( mongoUtil.newIDCriteriaObject( id ) ) )>
	</cffunction>

	<!--- Find a single document matching the given criteria.
		usage:
			doc = collection.findOne( {"age" = 18} ); --->
	<!--- function findOne( struct criteria="#structNew()#" ){ --->
	<cffunction name="findOne" access="public">
		<cfargument name="criteria" type="struct" required="false" default="#structNew()#">
		
		<cfscript>
			result = collection.findOne( toMongo( criteria ) );
			if( StructKeyExists( variables, "result" ) ){
				return toCF( result );
			}
		</cfscript>
	</cffunction>

	<!--- Find documents matching the given criteria. Returns a SearchResult object.
		usage:
			sort = {"NAME" = -1};
			result = collection.find( criteria={"AGE" = {"$gt"=18}}, limit="5", sort=sort );
			writeDump( var=result.asArray(), label="For query #result.getQuery().toString()# with sort #result.getSort().toString()#, returning #result.size()# of #result.totalCount()# documents" ); --->
	<!--- function find( struct criteria="#structNew()#", string keys="", numeric skip=0, numeric limit=0, any sort="#structNew()#" ){ --->
	<!--- NOTE: Renamed this function to "_find_" since CF8 doesn't allow functions to be named the same as cfscript functions --->
	<cffunction name="_find_" access="public">
		<cfargument name="criteria" type="struct" default="#structNew()#">
		<cfargument name="keys" type="string" default="">
		<cfargument name="skip" type="numeric" default="0">
		<cfargument name="limit" type="numeric" default="0">
		<cfargument name="sort" type="any" default="#structNew()#">
		
		<cfscript>
			_keys = mongoUtil.createOrderedDBObject(arguments.keys, mongoUtil.newOperationalDBObject());
			sort = toMongoOperation( sort );
			search_results = [];
			criteria = toMongo( criteria );
			search_results = collection.find(criteria, _keys).limit(limit).skip(skip).sort(sort);
			return createObject("component", "SearchResult").init( search_results, sort, mongoUtil );
		</cfscript>
	</cffunction>

	<!--- function count( struct criteria="#structNew()#" ){ --->
	<cffunction name="count" access="public">
		<cfargument name="criteria" type="struct" default="#structNew()#">
		<cfreturn collection.count( toMongo(criteria) )>
	</cffunction>

	<!--- 
	  Build a query object, and then execute that query using find()
	  Query returns a SearchBuilder object, which you'll call functions on.
	  Finally, you'll use various "execution" functions on the SearchBuilder to get a SearchResult object,
	  which provides useful functions for working with your results.

	  sort = {"NAME" = -1};
	  kidSearch = collection.query().between("KIDS.AGE", 2, 30).find( keys="", skip=0, limit=0, sort=sort );
	  writeDump( var=kidSearch.asArray(), label="For query #kidSearch.getQuery().toString()# with sort #kidSearch.getSort().toString()#, returning #kidSearch.size()# of #kidSearch.totalCount()# documents" );

	  See gettingstarted.cfm for many examples --->
	<!--- function query(){ --->
	<cffunction name="query" access="public">
		<cfreturn createObject("component", "SearchBuilder").init(this)>
	</cffunction>

	<!--- Runs mongodb's distinct() command. Returns an array of distinct values

		distinctAges = collection.distinct( "KIDS.AGE" );

		use query to filter results
		collection.distinct( "KIDS.AGE", {GENDER="MALE"} ) --->
	<!--- function distinct( string key, struct query ){ --->
	<cffunction name="distinct" access="public">
		<cfargument name="key" type="string">
		<cfargument name="query" type="struct">
		
		<cfscript>
			if(structKeyExists(arguments, "query")) {
				return collection.distinct( key, toMongo(query) );
			}
			return collection.distinct( key );
		</cfscript>
	</cffunction>
	
	<!--- 
	findAndModify is critical for queue-like operations. Its atomicity removes the traditional need to synchronize higher-level methods to ensure queue elements only get processed once.

		http://www.mongodb.org/display/DOCS/findandmodify+Command

		Your "update" doc must apply one of MongoDB's update modifiers (http://www.mongodb.org/display/DOCS/Updating#Updating-update%28%29), otherwise the found document will be overwritten with the "update" argument, and that is probably not what you want. --->
	<!--- function findAndModify( struct query, struct fields, struct sort, boolean remove=false, struct update, boolean returnNew=true, boolean upsert=false ){ --->
	<cffunction name="findAndModify" access="public">
		<cfargument name="query" type="struct">
		<cfargument name="fields" type="struct">
		<cfargument name="sort" type="struct">
		<cfargument name="remove" type="boolean" default="false">
		<cfargument name="update">
		<cfargument name="returnNew" type="boolean" default="true">
		<cfargument name="upsert" type="boolean" default="false">
		
		<cfscript>
			// Confirm our complex defaults exist; need this chunk of muck because CFBuilder 1 breaks with complex datatypes in defaults
			sort = createObject('java', 'java.util.HashMap');
			sort.put("_id", 1);
			//sort = {_id=1};
			fields = {};
			
			local.argumentDefaults = {sort=sort, fields=fields};
			for(local.k in local.argumentDefaults) {
			// for( i = 1; i <= ArrayLen(local.argumentDefaults); i++) {
				// local.k = local.argumentDefaults[i];
				if (!structKeyExists(arguments, local.k)) {
					arguments[local.k] = local.argumentDefaults[local.k];
				}
			}
			sort = toMongoOperation( sort );
	
			updated = collection.findAndModify(
				toMongo(query),
				toMongoOperation(fields),
				sort,
				remove,
				toMongo(update),
				returnNew,
				upsert
			);
			emptyStruct = {};
			if( StructKeyExists(variables,"updated") ) return emptyStruct;
	
			return toCF(updated);
		</cfscript>
	</cffunction>

	<!--- Executes Mongo's group() command. Returns an array of structs.

		usage, including optional 'query':

		result = collection.group( "STATUS,OWNER", {TOTAL=0}, "function(obj,agg){ agg.TOTAL++; }, {SOMENUM = {"$gt" = 5}}" );

		See examples/aggregation/group.cfm for detail --->
	<!--- function group( keys, initial, reduce, query, keyf="", finalize="" ){ --->
	<cffunction name="group" access="public">
		<cfargument name="keys">
		<cfargument name="initial">
		<cfargument name="reduce">
		<cfargument name="query">
		<cfargument name="keyf" default="">
		<cfargument name="finalize" default="">
	
		<cfscript>
			if (!structKeyExists(arguments, 'query'))
			{
				arguments.query = {};
			}
	
			group = 
				{ ns = collectionName,
				  key = mongoUtil.createOrderedDBObject(keys),
				  cond = query,
				  initial = initial,
				  $reduce = trim(reduce),
				  finalize = trim(finalize)
				};
			dbCommand = { group = group };
			if( len(trim(keyf)) ){
				structDelete(dbCommand.group,"key");
				dbCommand.group["$keyf"] = trim(keyf);
			}
			result = mongoDB.command( toMongo(dbCommand) );
	
			if( NOT result['ok'] ){
				throw("Error message: #result['errmsg']#", "GroupException", '', '', serializeJson(result));
			}
			return result["retval"];
		</cfscript>
	</cffunction>

	<!--- 
	Executes Mongo's mapReduce command. Returns a MapReduceResult object

		basic usage:

		result = collection.mapReduce( map=map, reduce=reduce, outputTarget="YourResultsCollection" );

		See examples/aggregation/mapReduce for detail --->
	<!--- function mapReduce( map, reduce, outputTarget, outputType="REPLACE", query, options  ){ --->
	<cffunction name="mapReduce" access="public">
		<cfargument name="map">
		<cfargument name="reduce">
		<cfargument name="outputTarget" default="REPLACE">
		<cfargument name="outputType">
		<cfargument name="query">
		<cfargument name="options">

		<cfscript>
			// Confirm our complex defaults exist; need this hunk of muck because CFBuilder 1 breaks with complex datatypes as defaults
			emptyStruct = {};
			argumentDefaults = {
				 query=emptyStruct
				,options=emptyStruct
			};
			k = "";
			for(k in argumentDefaults) {
				if (!structKeyExists(arguments, k))
				{
					arguments[k] = local.argumentDefaults[k];
				}
			}
	
			optionDefaults = {sort=emptyStruct, limit="", scope=emptyStruct, verbose=true};
			structAppend( optionDefaults, arguments.options );
			if( structKeyExists(optionDefaults, "finalize") ){
				optionDefaults.finalize = trim(optionDefaults.finalize);
			}
	
			out = {};
			out[lcase(outputType)] = outputTarget;
			if(outputType eq "inline"){
				out = {inline = 1};
			} else if (outputType eq "replace") {
				out = outputTarget;
			}
	
			dbCommandArray = [];
			tmpStruct = {mapreduce=collectionName};
			ArrayAppend(dbCommandArray, tmpStruct);
			tmpStruct = {map=trim(map)};
			ArrayAppend(dbCommandArray, tmpStruct);
			tmpStruct = {reduce=trim(reduce)};
			ArrayAppend(dbCommandArray, tmpStruct);
			tmpStruct = {query=query};
			ArrayAppend(dbCommandArray, tmpStruct);
			tmpStruct = {out=out};
			ArrayAppend(dbCommandArray, tmpStruct);
			dbCommand = mongoUtil.createOrderedDBObject( dbCommandArray );
	
			dbCommand.putAll(optionDefaults);
			commandResult = mongoDB.command( dbCommand );
	
			if( NOT commandResult['ok'] ){
				throw("Error Message: #commandResult['errmsg']#:", "MapReduceException", '', '', serializeJson(commandResult));
			}
	
			mrCollection = mongo.getDBCollection( commandResult["result"] );
			searchResult = mrCollection.query().find();
			mapReduceResult = createObject("component", "MapReduceResult").init(dbCommand, commandResult, searchResult, mongoUtil);
			return mapReduceResult;
		</cfscript>
	</cffunction>

	<!--- Inserts a struct into the collection --->
	<!--- function insert( struct doc ){ --->
	<!--- NOTE: Renamed this function to "_insert_" since CF8 doesn't allow functions to be named the same as cfscript functions --->
	<cffunction name="_insert_" access="public">
		<cfargument name="doc" type="struct">
		
		<cfscript>
			dbObject = toMongo(doc);
			dbObjectArray = [dbObject];
			collection.insert( dbObjectArray );
			doc["_id"] =  dbObject.get("_id");
			return doc["_id"];
		</cfscript>
	</cffunction>

	<!--- 
	Saves a struct into the collection; Returns the newly-saved Document's _id; populates the struct with that _id

		person = {name="bill", badmofo=true};
		collection.save( person ); --->
	<!--- function save( struct doc ){ --->
	<cffunction name="save" access="public">
		<cfargument name="doc" type="struct">
			
		<cfscript>
			if( structKeyExists(doc, "_id") ){
				update( doc = doc );
				return doc["_id"];
			} else {
				return this._insert_( doc );
			}
		</cfscript>
	</cffunction>

	<!--- 
	Saves an array of structs into the collection. Can also save an array of pre-created CFBasicDBObjects

	people = [{name="bill", badmofo=true}, {name="marc", badmofo=true}];
	collection.saveAll( people ); --->
	<!--- function saveAll( array docs ){ --->
	<cffunction name="saveAll" access="public">
		<cfargument name="docs" type="array">

		<cfscript>
			if( arrayIsEmpty(docs) ) return docs;
	
			i = 1;
			if( mongoUtil.isCFBasicDBObject( docs[1] ) ){
				collection.insert( docs );
			} else {
				total = arrayLen(docs);
				allDocs = [];
				for( i=1; i LTE total; i++ ){
					arrayAppend( allDocs, toMongo(docs[i]) );
				}
				collection.insert(allDocs);
			}
			return docs;
		</cfscript>
	</cffunction>

	<!--- 
	Updates a document in the collection.

	NOTE: This function signature *differs* from the mongo shell signature in one important way:

	mongo shell: update( query, doc, upsert, multi )
	cfmongodb:   update( doc, query, upsert, multi )

	The reason is that this enables more ColdFusion-idiomatic updating, in that we can pass in a single document argument without using named parameters. For example:

	The "doc" argument will either be an existing Mongo document to be updated based on its _id, or it will be a document that will be "applied" to any documents that match the "query" argument

	To update a single existing document, simply pass that document and update() will update the document by its _id, overwriting the existing document with the doc argument:
		person = person.findById(url.id);
		person.something = "something else";
		collection.update( person );

	To update a document by a criteria query and have the "doc" argument applied to a single found instance:
		update =  { "set" = {STATUS = "running"} };
		query = {STATUS = "pending"};
		collection.update( update, query );

	To update multiple documents by a criteria query and have the "doc" argument applied to all matching instances, pass multi=true
		collection.update( update, query, false, false )

	Pass upsert=true to create a document if no documents are found that match the query criteria --->
	<!--- function update( doc, query, upsert=false, multi=false ){ --->
	<cffunction name="update" access="public">
		<cfargument name="doc">
		<cfargument name="query">
		<cfargument name="upsert" default="false">
		<cfargument name="multi" default="false">

		<cfscript>
			if ( !structKeyExists(arguments, 'query') ){
				arguments.query = {};
			}
			
			if( structIsEmpty(query) ){
				query = mongoUtil.newIDCriteriaObject(doc['_id'].toString());
				dbo = toMongo(doc);
			} else{
				query = toMongo(query);
				keys = structKeyList(doc);
			}
			dbo = toMongo(doc);
		</cfscript>
		<!--- 
		<cfdump var="#query#">
		<cfdump var="#dbo#">
		<cfdump var="#upsert#">
		<cfdump var="#multi#">
		 --->
		<cfscript>
			collection.update( query, dbo, upsert, multi );
		</cfscript>
	</cffunction>

	<!--- 
	Remove one or more documents from the collection.

	If the document has an "_id", this will remove that single document by its _id.

	Otherwise, "doc" is treated as a "criteria" object. For example, if doc is {STATUS="complete"}, then all documents matching that criteria would be removed.

	pass an empty struct to remove everything from the collection: collection.remove( {} ); --->
	<!--- function remove( doc ){ --->
	<cffunction name="remove" access="public">
		<cfargument name="doc">

		<cfscript>
			if( structKeyExists(doc, "_id") ){
				return removeById( doc["_id"] );
			}
			dbo = toMongo(doc);
			writeResult = collection.remove( dbo );
			return writeResult;
		</cfscript>
	</cffunction>

	<!--- 
	Convenience for removing a document from the collection by the String representation of its ObjectId

		collection.removeById( url.id ); --->
	<!--- function removeById( id ){ --->
	<cffunction name="removeById" access="public">
		<cfargument name="id">

		<cfreturn collection.remove( mongoUtil.newIDCriteriaObject(id) )>
	</cffunction>

	<!--- drops this collection --->
	<!--- function drop(){ --->
	<cffunction name="drop" access="public">
		<cfscript>
			collection.drop();
		</cfscript>
	</cffunction>

	<!--- 
	The array of fields can either be
	a) an array of field names. The sort direction will be "1"
	b) an array of structs in the form of fieldname=direction. Eg:

		[
			{lastname=1},
			{dob=-1}
		]
	 --->
	<!--- public array function ensureIndex(array fields, unique=false ){ --->
	<cffunction name="ensureIndex" access="public" returnType="array">
		<cfargument name="fields" type="array">
		<cfargument name="unique" default="false">

		<cfscript>
		 	pos = 1;
		 	doc = {};
			indexName = "";
			fieldName = "";
	
		 	for( pos = 1; pos LTE arrayLen(fields); pos++ ){
				if( isSimpleValue(fields[pos]) ){
					fieldName = fields[pos];
					doc[ fieldName ] = 1;
				} else {
					fieldName = structKeyList(fields[pos]);
					doc[ fieldName ] = fields[pos][fieldName];
				}
				indexName = listAppend( indexName, fieldName, "_");
		 	}
	
		 	dbo = toMongo( doc );
		 	collection.ensureIndex( dbo, "_#indexName#_", unique );
	
		 	return getIndexes(collectionName, mongoConfig);
		</cfscript>
	</cffunction>

	<!--- Ensures a "2d" index on a single field. If another 2d index exists on the same collection, this will error --->
	<!--- public array function ensureGeoIndex( field, min="", max="" ){ --->
	<cffunction name="ensureGeoIndex" access="public" returnType="array">
		<cfargument name="field">
		<cfargument name="min" default="">
		<cfargument name="max" default="">

		<cfscript>
			doc = {};
			doc[arguments.field] = "2d";
			options = {};
			if( isNumeric(arguments.min) and isNumeric(arguments.max) ){
				options = {min = arguments.min, max = arguments.max};
			}
			collection.ensureIndex( toMongo(doc), toMongo(options) );
			return getIndexes( collectionName, mongoConfig );
		</cfscript>
	</cffunction>


	<!--- Returns an array with information about all of the indexes for the collection --->
	<!--- public array function getIndexes(){ --->
	<cffunction name="getIndexes" access="public" returnType="array">
		<cfreturn collection.getIndexInfo().toArray()>
	</cffunction>


	<!--- Drops all indexes from the collection --->
	<!--- public array function dropIndexes(){ --->
	<cffunction name="dropIndexes" access="public" returnType="array">

		<cfscript>
			collection.dropIndexes();
			return getIndexes();
		</cfscript>
	</cffunction>

</cfcomponent>