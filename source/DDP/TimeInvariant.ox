#include "TimeInvariant.h"
/* This file is part of niqlow. Copyright (C) 2011-2012 Christopher Ferrall */

/** A state variable that is non-random an invariant for and individual DP problem.

@example
	enum{male,female,Sex}
	decl sex = new FixedEffect("sex",Sex);
</dd>
@see DP::GroupVariables
**/
FixedEffect::FixedEffect(L, N) {
	StateVariable(L,N);
	pdf = ones(1,N);
	}

/** Create a state variable that is random but invariant for an individual DP problem.
@param L label
@param N number of points of support.
@param fDist integer [default], uniform distribution<br>otherwise, a `AV`() compatible object that
returns the N-vector of probabilities.

<DT>The default (and always initial) distribution is uniform:</DT>
<DD>
<pre>
RandomEffect("g",N);
</pre>
means:
<pre>
Prob(g=k) = 1/N, for k=0,...,N&oline;
</pre></DD>
<DT>Dynamic Densities</DT>
<DD>The third argument can be used to set the vector:
<pre>RandomEffect("g",2,<0.8;0.2>);</pre>
a static function:
<pre>
decl X, beta;
&vellip;
hd() {
    decl v = exp(X*beta), s = sumc(v);
    return v/s;
    }
&vellip;
RandomEffect("h",rows(X),hd);
</pre>
or a parameter block:
<pre>
enum{Npts = 5};
hd = new Simplex("h",Npts);
RandomEffect("h",Npts,hd);
</pre></DD>

<DT><code>fDist</code> is stored in a non-constant member, so it can be changed after the <code>CreateSpaces()</code>
has been called.</DT>

<DT>Most Flexible Option</DT>
The user can define a derived class and supply a replacement to the virtual `RandomEffect::Distribution`().

@see DP::GroupVariables
**/
RandomEffect::RandomEffect(L,N,fDist) {
	StateVariable(L,N);
    this.fDist = fDist;
	pdf = constant(1/N,1,N);
	}

/** Do Nothing and prohibit derived Updates.
actual should be set in Distribution.
**/
TimeInvariant::Update() { }

/** TimeInvariants have a fixed transition.
@internal
**/
TimeInvariant::Transit(FeasA) { return { matrix(v) , ones(rows(FeasA),1) }; }

/** Create a new Sub.
@param L label
@param N number of values it takes on.
@see FixedEffectBlock
**/
SubEffect::SubEffect(L,N)	{
	bpos = UnInitialized;
	block = UnInitialized;
	Discrete(L,N);
	}

/**Create a list of `FixedEffect` state variables.
@param L label for block
**/
FixedEffectBlock::FixedEffectBlock(L)	{
    StateBlock(L);
	}

/** Create a vector of fixed effects (FixedEffectBlock).
@param L string prefix <br>or array of strings, individual labels
@param vN vector of integer values, number of values each effect takes on.
@example
Create 3 fixed effects that take on 2, 3 and 5 values, respectively:
<pre> x = new Regressors("X",<2,3,5>); </pre>
Give each effect a label:
<pre> x = new Regressors({"Gender","Education","Occupation"},<2,3,5>); </pre>
</dd>
**/
Regressors::Regressors(L,vN) {
    FixedEffectBlock(isstring(L) ? L : "X");
    decl NN = vN,N,j;
    foreach(N in NN[j]) AddToBlock(new SubEffect(isstring(L) ? L+sprint("%02.0f",j) : L[j],N));
    }

/** Update `Discrete::pdf`, the distribution over the random effect.
This is the built-in default method.  It computes and stores the distribution over the random
effect in `Discrete::pdf` using `RandomEffect::fDist`;

The user can supply a replacement in a derived class.

**/
RandomEffect::Distribution() {
    pdf = isint(fDist)
            ? constant(1/N,1,N)
            : AV(fDist);
    }

/** Create a new CorrelatedEffect.
@param L label
@param N number of values it takes on.
@see RandomEffectBlock
**/
CorrelatedEffect::CorrelatedEffect(L,N)	{
	bpos = UnInitialized;
	block = UnInitialized;
	Discrete(L,N);
	}

/**Create a list of `CorrelatedEffect` state variables.
@param L label for block
**/
RandomEffectBlock::RandomEffectBlock(L)	{
    StateBlock(L);
	}

RandomEffectBlock::Distribution() {
	actual = v;
	pdf = constant(1/rows(Allv),rows(Allv),1);
	}

/** Create a permanent discretized normal random effect.
@param L label
@param N number of points
@param mu `AV`() compatible mean of the effect, &mu;
@param sigma `AV`() compatible standard deviation, &sigma;

The probabilities of each discrete value is 1/N.  The distribution is captured by adjusting the
actual values to be at the quantiles of the distribution.

**/
NormalRandomEffect::NormalRandomEffect(L,N,mu,sigma) {
	RandomEffect(L,N);
	this.mu = mu;
	this.sigma = sigma;	
	}

NormalRandomEffect::Distribution() { actual = AV(mu) + DiscreteNormal(N,0.0,AV(sigma));	}

/** Create a permanent discretized normal random effect.
@param L label
@param N number of points
@param mu `AV`() compatible mean of the effect, &mu;
@param sigma `AV`() compatible standard deviation, &sigma;
@param M number of standard deviations to set the largest value as

actual values are equally spaced between -M&sigma; and M&sigma;.

The probabilities of not uniform but are constant and depend only on
N and M.

**/
TauchenRandomEffect::TauchenRandomEffect(L,N,mu,sigma,M) {
	NormalRandomEffect(L,N,mu,sigma);
	this.M = M;
	decl pts = probn((-.Inf ~ (-M+2*M*range(0.5,N-1.5,+1)/(N-1)) ~ +.Inf) );
	pdf[] = pts[1:]-pts[:N-1];
	}

TauchenRandomEffect::Distribution() {
	actual = AV(mu) + AV(sigma)*(-M +2*M*vals/(N-1));
	}
