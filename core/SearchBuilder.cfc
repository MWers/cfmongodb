<cfcomponent hint="Creates a Domain Specific Language (DSL) for querying MongoDB collections.">
<cfscript>

  /*---------------------------------------------------------------------

    DSL for MongoDB searches:

    query = collection.query().
    				startsWith('name','foo').  //string
                    endsWith('title','bar').   //string
                    like('field','value').   //string
					          regex('field','value').    //string
                    eq('field','value').       //numeric
                    lt('field','value').       //numeric
                    gt('field','value').       //numeric
                    gte('field','value').      //numeric
                    lte('field','value').      //numeric
                    in('field','value').       //array
                    nin('field','value').      //array
                    mod('field','value').      //numeric
                    size('field','value').     //numeric
                    after('field','value').    //date
                    before('field','value');   //date


    results = query.find(keys=[keys_to_return],limit=num,start=num);

-------------------------------------------------------------------------------------*/

builder = '';
pattern = '';
dbCollection = '';
collection = '';
mongoUtil = '';
</cfscript>

<cffunction name="init">
	<cfargument name="DBCollection">

	<cfscript>
		variables.dbCollection = arguments.DBCollection;
		variables.mongoUtil = DBCollection.getMongoUtil();
		builder = mongoUtil.newDBObjectBuilder();
		pattern = createObject('java', 'java.util.regex.Pattern');
		return this;
	</cfscript>
</cffunction>

<cffunction name="builder">
	<cfreturn builder>
</cffunction>

<cffunction name="start">
	<cfscript>
		builder.start();
		return this;
	</cfscript>
</cffunction>

<cffunction name="add">
	<cfargument name="key">
	<cfargument name="value">

	<cfscript>
		builder.add( key, value );
		return this;
	</cfscript>
</cffunction>

<cffunction name="get">
	<cfreturn builder.get()>
</cffunction>

<cffunction name="startsWith">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		regex = '^' & val;
		builder.add( element, pattern.compile(regex) );
		return this;
	</cfscript>
</cffunction>

<cffunction name="endsWith">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		regex = val & '$';
		builder.add( element, pattern.compile(regex) );
		return this;
	</cfscript>
</cffunction>


<cffunction name="like">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		regex = '.*' & val & '.*';
		builder.add( element, pattern.compile(regex) );
		return this;
	</cfscript>
</cffunction>


<cffunction name="regex">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		regex = val;
		builder.add( element, pattern.compile(regex) );
		return this;
	</cfscript>
</cffunction>


<!--- May need at least some exception handling --->
<cffunction name="where">
	<cfargument name="js_expression">

	<cfscript>
		builder.add( '$where', js_expression );
		return this;
	</cfscript>
</cffunction>

<cffunction name="inArray">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		builder.add( element, val );
		return this;
	</cfscript>
</cffunction>


<!--- vals should be list or array --->
<cffunction name="$in">
	<cfargument name="element">
	<cfargument name="vals">

	<cfscript>
		if(isArray(vals)) return addArrayCriteria(element, vals,'$in');
		return addArrayCriteria(element, listToArray(vals),'$in');
	</cfscript>
</cffunction>

<cffunction name="$nin">
	<cfargument name="element">
	<cfargument name="vals">

	<cfscript>
		if(isArray(vals)) return addArrayCriteria(element, vals,'$nin');
		return addArrayCriteria(element, listToArray(vals),'$nin');
	</cfscript>
</cffunction>


<cffunction name="$eq">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		builder.add( element, val );
		return this;
	</cfscript>
</cffunction>


<cffunction name="$ne">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$ne", val);
		builder.add( element, criteria );
		return  this;
	</cfscript>
</cffunction>


<cffunction name="$lt">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$lt", val);
		builder.add( element, criteria );
		return  this;
	</cfscript>
</cffunction>


<cffunction name="$lte">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$lte", val);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>


<cffunction name="$gt">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$gt", val);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>


<cffunction name="$gte">
	<cfargument name="element">
	<cfargument name="val">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$gte", val);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>

<cffunction name="$exists">
	<cfargument name="element">
	<cfargument name="exists" default="true">

	<cfscript>
		criteria = {$exists = javacast("boolean",exists)};
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>

<cffunction name="between">
	<cfargument name="element">
	<cfargument name="lower">
	<cfargument name="upper">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$gte", lower);
		criteria.put("$lte", upper);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>

<cffunction name="betweenExclusive">
	<cfargument name="element">
	<cfargument name="lower">
	<cfargument name="upper">

	<cfscript>
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$gt", lower);
		criteria.put("$lt", upper);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>

<cffunction name="before">
	<cfargument name="element" type="string">
	<cfargument name="val" type="date">

	<cfscript>
		date = parseDateTime(val);
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$lte", date);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>

<cffunction name="after">
	<cfargument name="element" type="string">
	<cfargument name="val" type="date">
	
	<cfscript>
		date = parseDateTime(val);
		criteria = createObject('java', 'java.util.HashMap');
		criteria.put("$gte", date);
		builder.add( element, criteria );
		return this;
	</cfscript>
</cffunction>

<!--- 
@element The array element in the document we're searching
@val The value(s) of an element in the array
@type $in,$nin,etc. --->
<cffunction name="addArrayCriteria">
	<cfargument name="element" type="string">
	<cfargument name="val" type="array">
	<cfargument name="type" type="string">
	
	<cfscript>
		exp = {};
		exp[type] = val;
		builder.add( element, exp );
		return this;
	</cfscript>
</cffunction>

<!--- 
@keys A list of keys to return
@skip the number of items to skip
@limit Number of the maximum items to return
@sort A struct or string representing how the items are to be sorted --->
<!--- NOTE: Renamed this function to "_find_" since CF8 doesn't allow functions to be named the same as cfscript functions --->
<cffunction name="_find_">
	<cfargument name="keys" type="string" default="">
	<cfargument name="skip" type="numeric" default="0">
	<cfargument name="limit" type="numeric" default="0">
	<cfargument name="sort" type="any" default="#structNew()#">
	
	<cfreturn dbCollection._find_( criteria=get(), keys=keys, skip=skip, limit=limit, sort=sort )>
</cffunction>

<cffunction name="count">
	<cfreturn dbCollection.count( get() )>
</cffunction>

<!--- DEPRECATED. Use find() instead --->
<cffunction name="search">
	<cfargument name="keys" type="string" default="">
	<cfargument name="skip" type="numeric" default="0">
	<cfargument name="limit" type="numeric" default="0">
	<cfargument name="sort" type="any" default="#structNew()#">

	<cfreturn  this.find( argumentcollection = arguments )>
</cffunction>

</cfcomponent>