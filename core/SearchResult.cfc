<cfcomponent>
	<cfscript>
		mongoCursor = "";
		query = "";
		mongoUtil = "";
	
		documents = "";
		count = "";
		tCount = "";
	</cfscript>

	<cffunction name="init">
		<cfargument name="mongoCursor">
		<cfargument name="sort">
		<cfargument name="mongoUtil">

		<cfscript>
			structAppend( variables, arguments );
			query = mongoCursor.getQuery();
			return this;
		</cfscript>
	</cffunction>

	<!--- The fastest return type... returns the case-sensitive cursor which you'd iterate over with
	while(cursor.hasNext()) {cursor.next();}

	Note: you can use the cursor object to get full access to the full API at http://api.mongodb.org/java --->
	<cffunction name="asCursor">
		<cfreturn mongoCursor>
	</cffunction>
	
	<!--- Converts all cursor elements into a ColdFusion structure and returns them as an array of structs. --->
	<cffunction name="asArray">
		<cfscript>
			if( isSimpleValue(documents) ){
				documents = [];
				while(mongoCursor.hasNext()){
					doc = mongoUtil.toCF( mongoCursor.next() );
					arrayAppend( documents, doc );
				}
			}
			return documents;
		</cfscript>
	</cffunction>
	
	<!--- The number of elements in the result, after limit and skip are applied --->
	<cffunction name="size">
		<cfscript>
			if( count eq "" ){
				//designed to reduce calls to mongo... mongoCursor.size() will additionally query the database, and arrayLen() is faster
				if( isArray( documents ) ){
					count = arrayLen( documents );
				} else {
					count = mongoCursor.size();
				}
			}
			return count;
		</cfscript>
	</cffunction>

	<!--- The total number of elements for the query, before limit and skip are applied --->
	<cffunction name="totalCount">
		<cfscript>
			if( variables.tCount eq "" ){
				variables.tCount = mongoCursor.count();
			}
			return variables.tCount;
		</cfscript>
	</cffunction>

	<!--- Mongo's native explain command. Useful for debugging and performance analysis --->
	<cffunction name="explain">
		<cfreturn mongoCursor.explain()>
	</cffunction>

	<!--- The criteria used for the query. Use getQuery().toString() to get a copy/paste string for the Mongo shell --->
	<cffunction name="getQuery">
		<cfreturn query>
	</cffunction>

	<!--- The sort used for the query. use getSort().toString() to get a copy/paste string for the Mongo shell --->
	<cffunction name="getSort">
		<cfreturn sort>
	</cffunction>

</cfcomponent>