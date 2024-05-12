#include "shaders/SettingsDefines.fxh"

/*
	Shared shader code that we use for Project Reality: BF2
	Author: [R-DEV]papadanku @ 2023
*/

#if !defined(_HEADERS_)
	#define _HEADERS_
#endif

#if !defined(REALITY_DEFINES)
	#define REALITY_DEFINES

	// 16x is more or less the modern GPU standard
	#define PR_MAX_ANISOTROPY 16

	// This hardcoded value fixes a bug with undergrowth's alphatesting
	// NOTE: We compensate for this change by multiplying the texture's alpha by ~2
	#define PR_ALPHA_REF 127

	// Project Reality's default Z-testing
	// We expose it here so it is easy to port over to reversed depth buffering
	#define PR_ZFUNC_NOEQUAL LESS
	#define PR_ZFUNC_WITHEQUAL LESSEQUAL

	// #define _USELINEARLIGHTING_
	// #define _USETONEMAP_
#endif
