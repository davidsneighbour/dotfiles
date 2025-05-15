// set a larger maximum number of listeners globally
require("events").EventEmitter.defaultMaxListeners = 20;

// fixes the following warning
// (node:1238552) MaxListenersExceededWarning: Possible EventEmitter memory leak
//                detected. 11 close listeners added to [TLSSocket]. Use
//                emitter.setMaxListeners() to increase limit
