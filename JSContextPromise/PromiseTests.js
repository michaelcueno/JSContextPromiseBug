;(function(global){

    global.success = function() {
        global.report("success");
    };

    global.performTest = function() { 
        new Promise(function(resolve, reject) {
            new Promise(function(resolve, reject) {
                resolve({ping: function(){
                    global.sendMessage("message");
                }});
            }).then(function(native){
                native.ping();
                // rejeting here, works.
            }).catch(report);
            // The problem only reproduces when resolving / rejecting here (outside of inner promise).
            reject("expected_rejection");
        }).then(function(){
            report("Shouldn't have been thenable - expected rejection");
        }).catch(function(errorObj){
            // Nothing is defined here. Thowing this - reports the global object, but trying to use anything (like assert) will
            // cause a JS exception "assert not defined" etc.
            console.log("This will throw an error saying console.log is not defined");
            success();
        }).catch(report); // Report failure to Xcode unit test
    };

    global.performTestWorking = function() { 
        new Promise(function(resolve, reject) {
            new Promise(function(resolve, reject) {
                resolve({ping: function(){
                    global.sendMessage("message");
                }});
            }).then(function(native){
                native.ping();
                reject("expected_rejection");
            }).catch(report);
            // The problem only reproduces when resolving / rejecting here (outside of inner promise).
        }).then(function(){
            report("Shouldn't have been thenable - expected rejection");
        }).catch(function(errorObj){
            console.log("now the outer scope of this function is maintained.");
            success();
        }).catch(report); // Report failure to Xcode unit test
    };
})(this);
