#import "StateVariable"
/* This file is part of niqlow. Copyright (C) 2012-2018 Christopher Ferrall */

/** An element of the group vector &gamma;.
**/
struct TimeInvariant : StateVariable {
	Transit();
	Update();
	}

/** A state variable that is non-random and invariant for an individual DP problem.

Solution methods loop over fixed effect values, re-using storage space.

@see FETask

**/
struct FixedEffect : TimeInvariant {
	FixedEffect(L="FE", N=1);
	}
	
/** A random state variable that is invariant for an individual DP problem.

A random effect plays a similar to its counterpart in an econometric model. Solution methods loop over random effect values and will account for the distribution
in computing predictions, simulations and econometric objectives.

@examples
N equally likely values:
<pre>
RandomEffect("g",N);
</pre>
A binary variable with constant and unequal weights:
<pre>RandomEffect("g",2,<0.8;0.2>);</pre>
A two-point random effect for which the distribution is a function of the value of a fixed effect
(level of education) and a parameter vector &beta;:
<pre>
decl beta;
&vellip;
hd() {
    decl v = exp((1~AV(educ))*CV(beta)), s = sumc(v);
    return v/s;
    }
&vellip;
GroupVariables(
   h=RandomEffect("h",2,hd),
   educ = FixedEffect("ed",4);
   }
</pre>
A random effect with a distribution that equals a Simplex parameter block:
<pre>
enum{Npts = 5};
hd = new Simplex("h",Npts);
RandomEffect("h",Npts,hd);
</pre></DD>

<DT><code>fDist</code> is stored in a non-constant member, so it can be changed after the <code>CreateSpaces()</code>
has been called.</DT>

<DT>Most Flexible Option</DT>
The user can define a derived class and supply a replacement to the virtual `RandomEffect::Distribution`().


@see RETask, FixedEffect, RandomEffectBlock

**/
struct RandomEffect : TimeInvariant	{
    decl
    /** holds the object that computes and returns
       the distribution across values. **/ fDist;
		 RandomEffect(L="RE",N=1,fDist=UnInitialized);
	virtual Distribution();
	}

/** An element of the FixedEffectBlock.
**/
struct SubEffect : FixedEffect {
	/** EffectBlock that I belong to  **/		decl block;
	/** Index into block array/vector **/    	decl bpos;
	SubEffect(L="SubFE", N=1);
}
	
/** A Block of `FixedEffect` group variables.

**/
struct FixedEffectBlock : StateBlock {
	FixedEffectBlock(L="FEBlock");
	}

/**
**/
struct Regressors : FixedEffectBlock {
    decl ObservedX;
    Regressors(L,vNorM,UseOnlyObserved=TRUE);
    InObservedX();
    }
	
/** An element of a RandomEffectBlock.
**/
struct CorrelatedEffect : RandomEffect {
	/** EffectBlock that I belong to  **/		decl block;
	/** Index into block array/vector **/    	decl bpos;
	CorrelatedEffect(L="CorrRE", N=1);
}

/** A Block of `CorrelatedEffect` group variables.

**/
struct RandomEffectBlock : StateBlock {
	RandomEffectBlock(L="REBlock");
	virtual Distribution();
	}

/**  A permanent discretize N(0,&sigma;<sup>2</sup>) random effect.
@see DiscreteNormal
**/
struct NormalRandomEffect : RandomEffect {
	const decl mu, sigma;
	NormalRandomEffect(L,N,mu=0.0, sigma=1.0);
	Distribution();
	}		

/** Use Tauchen's method to discretize a normal variable.
**/
struct TauchenRandomEffect : NormalRandomEffect {
	const decl M;
	TauchenRandomEffect(L,N,mu, sigma,M);
	virtual Distribution();
	}
	
