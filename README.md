rebol-opensearch-proxy
======================

Rebol (2) module that allows you to define access to your own search service (any data source(s) you want).  

~~~
>> do %opensearch.r
Script: {Returns Opensearch results formatted for MS Windows search} (31-Oct-2013)

   ... available functions ...
 * opensearch &conn opensearch-connector-object

0:10:38.513 44.5 KB 194.6 KB 5.6 MB Returns Opensearch results formatted for MS Windows search is loaded. [
    &conn [object!] {search connector object must implement load and find}
    /local searchTerm results p*
]
>>
~~~
