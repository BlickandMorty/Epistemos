//
//  Epistemos-Bridging-Header.h
//  Epistemos
//
//  Bridges C/ObjC headers into Swift.
//

// Rust graph engine FFI
#include "graph-engine-bridge/graph_engine.h"
#include "graph-engine-bridge/graph_engine_bolt.h"
#include "syntax-core-bridge/syntax_core.h"

// ObjC exception catching (Swift can't catch NSException natively)
#import "Epistemos/App/ObjCExceptionCatcher.h"

// NSTextContentManagerDelegate wiring (bypasses NSTextContentStorage's delegate override)
#import "Epistemos/App/ContentManagerDelegateHelper.h"
