REBOL [
	Title: "Returns Opensearch results formatted for MS Windows search"
	Purpose: {
		Provide a generic base for custom searches to be integrated into Windows

		windows-search-connector will be the listener that Windows Explorer sends
		requests to.  It provides basic sanitizing of query then calls extended
		search function, which returns formatted results (???).

		Your extended object!'s search function may call a service, query a db or scrape a web startPage
		(It can also optionally cause change.)

		The extended object! can supply an optional load-search-data function
	}

	File: %opensearch.r
	Rebol: 2
	Author: "Grant Wesley Parks"
	Home: https://github.com/grantwparks
	Date: 01-Dec-2013
	Version: 0.1.1
	History: {
		BOO!
		0.0.1	Copied from my existing specific searches
				GOAL: create a generic base object! that will do everything
				necessary to provide a user designed search from Windows Explorer
		0.1.0	All new structure.  After running the script, you call opensearch with
					an object that implements the 'search function, optionally implementing
					a 'load function which get called by opensearch on startup and every
					hour to refresh.
		0.1.1 	New handling of the results from plugin with a rejoin.  Building buffer-out as
						early as poss. and not sanitizing until the end (except for ampersands in urls).
	}
	Requires: [
		%sysmon.r [*.]
	]
]

;
; Defines OPENSEARCH as a function the function that starts the proxy
; service using functions and propeties in the object that's passed.
;
opensearch: use [
	minimum-length sanitize-query get-request-from http-port
	buffer-out item-template cleanup next-time
	chars-A ; special chars to translate to "A"
	p* ; temp ptr
][
	unless connected? [to-error "No internet connection found. Please check your connection."]
	unless value? 'sysmon.r [do %../lib/sysmon.r]
	minimum-length: 3	buffer-out: make string! 4096 next-time: now/time - 1
	chars-A: charset [#"^(C0)" - #"^(C5)"]

	item-template: [
		{<item>}
		either p*: select itm 'title  [join {<title><![CDATA[} [p* {]]></title>}]][""]
		either p*: select itm 'author [join {<author><![CDATA[} [p* {]]></author>}]][""]
		either p*: select itm 'link [join {<link><![CDATA[} [p* {]]></link>}]][""]
		either p*: select itm 'description [join {<description><![CDATA[} [p* {]]></description>}]][""]
		either p*: select itm 'thumbnail [join {<media:thumbnail url="} [replace/all p* #"&" "&amp;" {"/>}]][""]
 		either p*: select itm 'content [join {<media:content url="} [replace/all p* #"&" "&amp;" {"/>}]][""]
 		either p*: select itm 'category [join {<media:category><![CDATA[} [p* {]]></media:category>}]][""]
		{</item>}
	]

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
			insert request reduce ["Address: " in-port/host newline]                         ; probe head request
		  also next find pick parse head request none 2 "?" buffer-in: none
		]
	]

	func [
		&conn [object!] "search connector object must implement load and find"
		/local searchTerm results limit
	][
		*. ["opensearch start" &conn/port]
		attempt [close server-port] server-port: open/lines to-url join "tcp://:" &conn/port
		limit: 100
		; if error? err: try [
			forever [

				if now/time >= next-time [
					*. "Loading search data..."
					all [in &conn 'load &conn/load]
					next-time: now/time + 3599	 ; an hour from now
				]
				*. ["Listening on..." server-port/port-id "next data refresh in" next-time - now/time]

				clear buffer-out buffer-out: insert buffer-out rejoin [
					{<?xml version="1.0" encoding="UTF-8"?><rss version="2.0" xmlns:win="http://schemas.microsoft.com/windows/2008/propertynamespace" xmlns:media="http://search.yahoo.com/mrss" xmlns:opensearch="http://a9.com/-/spec/opensearchdescriptionch/1.1/" xmlns:atom="http://www.w3.org/2005/Atom">}
						{<channel><title>} &conn/title {</title><link>} &conn/link {</link><description>Search results for }]

				results: either any [minimum-length <= length? searchTerm: sanitize-query get-request-from http-port: first wait server-port searchTerm/1 = #"!"] [
					&conn/search searchTerm limit
				][
					print "The search term is too short to send"
					[]
				]
		   	*. ["There are" length? results "rows with" searchTerm]

				buffer-out: insert buffer-out rejoin [searchTerm
					{</description><opensearch:totalResults>} length? results
					{</opensearch:totalResults><opensearch:itemsPerPage>100</opensearch:itemsPerPage><opensearch:startIndex>} 1
					{</opensearch:startIndex><atom:link rel="search" type="application/opensearchdescription+xml" href="http://example.com/opensearchdescription.xml"/>}
					{<opensearch:Query role="request" searchTerms="} searchTerm {" startPage="1" />}]

				foreach itm copy/part results limit [buffer-out: insert buffer-out rejoin bind item-template 'itm]

				trim/lines  buffer-out: head insert buffer-out {</channel></rss>}
				replace/all buffer-out #"^M" #","   ; 146 is the weird right single quote
				replace/all buffer-out to-char 150 #"-"   ; 150 is weird en dash
				replace/all buffer-out to-char 146 #"'"
				replace/all buffer-out to-char 169 "&#169;"
				replace/all buffer-out chars-A #"A"

; chars-up: charset [#"^(80)" - #"^(FF)"]
; print ["BAD?" copy/part any [find buffer-out chars-up "nope"] 25]
				unset [searchTerm results]
				insert buffer-out rejoin ["HTTP/1.0 200 OK^/Content-length: " length? buffer-out "^/Content-type: application/rss+xml^/^/"]
				write-io http-port buffer-out length? buffer-out  ;print copy/part buffer-out 10000
			]
		; ][
		; 	print mold disarm err
		; ]
		do cleanup
	]
]

; *. {

;                     - available functions -

; ; start opensearch with a connector definition
; opensearch context []
; }

? opensearch *. "Loaded."
