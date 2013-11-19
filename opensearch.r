REBOL [ 
	Title: "Returns Opensearch results formatted for MS Windows search" 
	Purpose: {
		Provide a generic base for custom searches to be integrated into Windows

		windows-search-connector will be the listener that Windows Explorer sends
		requests to.  It provides basic sanitizing of query then calls extended 
		search function, which returns formatted results.

		Your extended object!'s load and search functions may call a service, query a db or scrape a web startPage
	}

	File: %opensearch.r
	Rebol: 2
	Author: "Grant Wesley Parks"
	Home: https://github.com/grantwparks
	Date: 31-Oct-2013
	Version: 0.0.1
	History: {
		BOO!
		0.0.1	Copied from my existing specific searches 
				GOAL: create a generic base object! that will do everything
				necessary to provide a user designed search from Windows Explorer
	}
	Requires: {
		%sysmon.r [log-app]
	}
]

;
; Defines OPENSEARCH as a function the function that starts the proxy
; service using functions and propeties in the object that's passed.
;
opensearch: use [
	minimum-length sanitize-query get-request-from http-port 
	buffer-out cleanup next-time
][
	unless connected? [to-error "No internet connection found. Please check your connection."]
	unless value? 'sysmon.r [do %./lib/sysmon.r]
	minimum-length: 3
	buffer-out: make string! 4096 next-time: now/time - 1

	cleanup: [
		print "cleanup" 
		attempt [close http-port] 
		attempt [close server-port]
		unset [http-port server-port searchTerm results buffer-out]
	]

	; Makes a COPY of input string, unhexes the special chars, 
	;	turns its '+'s into blanks (Windows search encodes space this as '+'),
	;   removes a bunch of characters, trims blanks from head and tail,
	;	and compresses mult whitespace 
	sanitize-query: func[str [string!]][
		trim/lines trim/with replace/all dehex copy str #"+" #" " {"&%<>/"}
	]

	get-request-from: use [request][
		request: make string! 256
		;it's interesting to note the coincidence.  I used 'request and there's a request func to get
		; user input.  Wonder if this would be the place to be able to use this on the cmd line to search
		func[
			"Returns the search term from in-port"
			in-port [port!] "port to read from"
			/local buffer-in
		][ 
		    ; build up the request buffer
			clear request: head request while [not empty? buffer-in: first in-port][
				request: insert request reduce [buffer-in newline]
			]
			insert request reduce ["Address: " in-port/host newline]
		    also next find pick parse head request none 2 "?" buffer-in: none
		]
	]

	func [
		&conn [object!] "search connector object must implement load and find"
		/local searchTerm results p*
	][
		log-app ["opensearch start" &conn/port]
		attempt [close server-port] server-port: open/lines to-url join "tcp://:" &conn/port

		; if error? err: try [
			forever [ 
				if next-time < now/time [
					log-app "Loading search data..." all [in &conn 'load &conn/load]
					next-time: now/time + 3599	 ; an hour from now
				]
				log-app ["Listening on..." server-port/port-id "next data refresh in" third next-time - now/time]
		
				; FIX the following back to something simple
				results: any [
					all [
						minimum-length > length? searchTerm: sanitize-query get-request-from http-port: first wait server-port 
						print "The search term is too short to send" []
					]
					&conn/search searchTerm [] 
				]
			    log-app ["There are" length? results "rows with" searchTerm]
			    clear buffer-out insert buffer-out rejoin [
			    	{<?xml version="1.0" encoding="UTF-8"?>}
					{<rss version="2.0" xmlns:media="http://search.yahoo.com/mrss" xmlns:opensearch="http://a9.com/-/spec/opensearchdescriptionch/1.1/" xmlns:atom="http://www.w3.org/2005/Atom">}
						{<channel><title>} &conn/title 
							{</title><link>} &conn/link 
							{</link><description>Search results for} searchTerm 
							{</description><opensearch:totalResults>} length? results 
							{</opensearch:totalResults><opensearch:itemsPerPage>} length? results 
							{</opensearch:itemsPerPage><opensearch:startIndex>} 1 
							{</opensearch:startIndex><atom:link rel="search" type="application/opensearchdescription+xml" href="http://example.com/opensearchdescription.xml"/>}
							{<opensearch:Query role="request" searchTerms="} searchTerm 
							{" startPage="1" />} rejoin [
					    		map-each value-map results [
									rejoin [ 
						    		; USE PARSE FOR THIS!!!!:
										{<item>} 
										if p*: select value-map 'title [join {<title><![CDATA[} [p* {]]></title>}]]
										if p*: select value-map 'author [join {<author><![CDATA[} [p* {]]></author>}]]
										if p*: select value-map 'link [join {<link><![CDATA[} [p* {]]></link>}]]
										if p*: select value-map 'description [join {<description><![CDATA[} [p* {]]></description>}]]
										if p*: select value-map 'thumbnail [join {<media:thumbnail url="} [p* {"/>}]]
										{</item>}
									]
								]
					    	]
						</channel> </rss>
				]
				unset [searchTerm results p*]
			    insert buffer-out rejoin ["HTTP/1.0 200 OK^/Content-length: " length? buffer-out "^/Content-type: application/rss+xml^/^/"]
				write-io http-port buffer-out length? buffer-out ; print buffer-out
			]
		; ][
		; 	print mold disarm err
		; ]
		do cleanup
	]
]

print {
   ... available functions ...
 * opensearch &conn opensearch-connector-object
}
log-app [system/script/header/title "is loaded." mold third :opensearch]