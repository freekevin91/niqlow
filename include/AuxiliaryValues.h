#import "DDPShared"


/** Base Class for variables related to outcomes.
Auxiliary variables are typically functions of the state and action vectors that would be observed in the data.

For example, in a search model, suppose the worker's ability <var>x</var> and the match quality <var>m</var> are
both unobserved, but the wage, <var> w = xm</var>, is observed.  Then an auxiliary variable can be created for wage, added to
the outcome and read in along with other data.

**/
struct AuxiliaryValue : Quantity {
    decl indata;
	AuxiliaryValue(L="Aux");
	virtual Realize(y=0);
    virtual Likelihood(y=0);
    virtual Track(LorC);
	}

struct StaticAux : AuxiliaryValue {
    const decl target;
    virtual Realize(y=0);
    StaticAux(L,target);
    }

/** Built-in variable that records realized utility, <var>U(&alpha;,&epsilon;,&eta;,&theta;,&gamma;)</var>
**/
struct RealizedUtility : AuxiliaryValue {
	RealizedUtility();
	virtual Realize(y=0);
	}

/** An auxiliary value that is an indicator for values other actions or states.
**/
struct Indicator : AuxiliaryValue {
    const decl ttype, target, myval, iobj, iacted;
    Indicator(target,myval,iobj=UnInitialized,prefix=NotInData);
    virtual Realize(y=0);
    }

/** Create
**/
struct MultiIndicator : Indicator {
    MultiIndicator(target,myval,iobj,prefix);
    Realize(y=0);
    }

struct ZetaRealization : AuxiliaryValue {  //Changed April 2016 from Quantity
	const decl length;
	ZetaRealization(length);
	virtual Realize(y=0);
	}

/** Add normal noise to a AV() compatible target, either linear or log-linear. **/
struct Noisy : AuxiliaryValue {
    decl truevalue, sigma, eps, Linear;
    Noisy(truevalue,sigma=1.0,Linear=TRUE);
    Realize(y=0);
    Likelihood(y=0);
    }
