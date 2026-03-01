//
//  Epistemos-Bridging-Header.h
//  Epistemos
//
//  Bridges C/ObjC headers into Swift.
//

// Rust graph engine FFI
#include "graph-engine-bridge/graph_engine.h"

// ObjC exception catching (Swift can't catch NSException natively)
#import "Epistemos/App/ObjCExceptionCatcher.h"
