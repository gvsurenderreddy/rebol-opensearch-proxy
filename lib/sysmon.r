REBOL [ 
	Title: "Utility functions for memory and timing"
    Date: 22-Oct-2013 "or thereabouts"
	File: %sysmon.r
]

sysmon.r: true

abbrev-bytes: use [limits][limits: [1073741824 GB 1048576 MB 1024 KB 1 B]
    func [bytes [number!]][
        limits: head limits forskip limits 2 [
            if bytes > limits/1 [
                return reduce [round/to (bytes / limits/1) .1 limits/2]
            ]
        ] 
    ]
]

mem: does[abbrev-bytes stats]

memuse: use[blk][
    blk: make block! 25
    func [
        "Returns the number of bytes used since memory counter was last checked" 
        'counter-name [string! word!] "Unique name for this counter"
        /clr
        /local mem previous
    ][
        mem: stats
        unless previous: find blk counter-name [insert blk reduce [counter-name mem] return 0]
        also mem - first next previous if clr [change next previous mem]
    ]
]

log-app: use [last-time initial-mem last-mem] [
    last-time: now/time/precise
    initial-mem: last-mem: stats
    func [
        "Prefix the argument with time and current Rebol memory use"
        message [any-type!]
        ;/to block! of destinations or call log app with an arg that redirect to...
        /local log-time log-mem memdiff
    ][
        log-time: now/time/precise log-mem: stats
        message: reduce [now/time/precise abbrev-bytes log-mem - last-mem abbrev-bytes log-mem - initial-mem abbrev-bytes log-mem reduce message] 
        last-time: log-time last-mem: log-mem
        print message
    ]
]
