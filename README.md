rebol-opensearch-proxy
======================

Base search server script written in Rebol (2) that returns OpenSearch format XML.

You can define your own search proxy for anything and interact with it directly in Windows Explorer, through a platform called Federated Search.  It operates as a Windows Explorer search plugin; after installing -- which only requires launching a
specialliy-formatted XML file with the ".osdx" extension -- Windows sends the string you type into Windows Explorer search and displays the HTTP response.

Accept requests in the format specified in osdx url template.  The query typed into Windows search is sanitized somewhat; multiple blnks are singled and trimmed from ends and certain characters are removed like &%<>/.  Results are displayed directly
in Windows Explorer, acording to their Federated Search facility.

Your script can call multiple and diverse services and turn the results into an OpenSearch response that Windows Explorer displays.  The response is very much like RSS or Atom with some Yahoo media and Windows-specific elements.  (I'm still figuring out what can go in there.)

Your script should do %opensearch.r , then call opensearch with an object that:

  * Has properties 'title, 'link and 'port. 'title and 'link are displayed in Windows Explorer and 'port is the port our server will listen on.

  (The .osdx file contains the url! we listen on, which is wherever you start your script.)

  * Implements a 'search function that returns its results as a block! of blocks of key value pairs that correspond to OpenSearch elements

  * Optionally implements a 'load function to let you reformat and cache data.  It gets called at startup and every hour thereafter.


~~~
>> do %opensearch.r
Script: {Returns Opensearch results formatted for MS Windows search} (1-Dec-2013)
USAGE:
    OPENSEARCH &conn

DESCRIPTION:
    (undocumented)
     OPENSEARCH is a function value.

ARGUMENTS:
     &conn -- search connector object must implement load and find (Type: object)
22:19:47.233 +84.0KB 70.3MB Loaded.
~~~

A sample connector that you would define in Rebol
=================================================





TODO
====

Add paging options - will require slightly more elaborate template in .osdx, better
parsing of that request, and actual paging by opensearch itself, knowing that Windows only handles 100 results at a time.

