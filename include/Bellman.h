#ifdef OX_PARALLEL
#ifndef DPin
    #define DPin
    #include "DP.h"
#endif
#endif
/* This file is part of niqlow. Copyright (C) 2011-2018 Christopher Ferrall */

/** &theta;-specific values.

Corresponds to a a model with no continuous shocks &zeta; and no ex-post smoothing.

Since a new instance of DP is created for each reachable point in the (endogneous) state space, the structure relies heavily
on static members in order to reduce memory requirements.  These are defined in the base `DP` class.

<code>MyModel</code> should be derived from (a derivation from) `Bellman`.

**/
struct  Bellman : DP {
	decl
        /**Integer code to classify state (InSubSample,LastT,Terminal).
            This avoids multiple integer values at each point in the state space.
            Defined in `StateTypes`. Set in `DP::CreateSpaces`() and `DP::SubSampleStates`()
            @see StateVariable::MakeTerminal, Clock::Last **/       Type,
		/**&theta;.j index into `Alpha::CList`.**/  				Aind,
		/** v(&alpha;;&theta;) and &Rho;*(&hellip;,&gamma;). **/    pandv,
		/** TransStore x &eta;-Array of feasible endogenous	state
			indices and transitions
			&Rho;(&gamma;&prime;;&alpha;,&eta;,&gamma;).**/			Nxt,
		/**EV(&theta;)  **/					                        EV;

			static 	Delete();
			static 	Initialize(userState,UseStateList=FALSE);
			static  CreateSpaces();
                    OnlyFeasible(myU);
            virtual ExogExpectedV();
			virtual FeasibleActions();
            virtual Reachable();
			virtual Utility();
            virtual UReset();
			virtual thetaEMax() ;
			virtual ActVal();
            virtual ExogStatetoState();
            virtual HMQVal();
            virtual AMEMax();
			virtual Smooth();
			virtual KernelCCP(task);
			virtual ZetaRealization();
			virtual	AutoVarPrint1(task);
			virtual	Interface();
            virtual OutcomesGivenEpsilon();
            //virtual ExpectedOutcomesOverEpsilon(CondChoiceProb);
//			virtual Predict(tod);
            virtual OutputValue();
            virtual SetTheta(state=0,picked=0);
            virtual GetCondVal();
            virtual SetContVal(Aoptvals,Aobj);

					Bellman(state,picked);
                    Allocate(picked,CallFromBellman=FALSE);
					~Bellman();
					Simulate(Y);
					ThetaTransition();
					UpdatePtrans(ap=0,vind=0);
                    StateToStatePrediction(intod);
					MedianActVal();
                    virtual InSS();
	}																																				

/** Choice probabilities are smoothed ex post.

<DT>Utility() has no continuous error terms that affect the formula for computing $EV(\theta)$.
</DT>
<DT>After $V(\theta)$ is computed, choice probabilities are either </dt>
<DD>left unsmoothed or </dd>
<Dd>smoothed <em>ex post</em>
according to the `SmoothingMethods` sent to `ExPostSmoothing::CreateSpaces`().</DD>

**/
struct ExPostSmoothing : Bellman {
	static decl Method, rho, sigma;
	static Initialize(userState,UseStateList=FALSE);
	static CreateSpaces(Method=NoSmoothing,smparam=1.0);
	virtual Smooth();
			Logistic();
			Normal();
	}

/** A model where there is a single decision, no value shocks and no dynamics.
The user simply supplies a static utility function which is called from the built-in
version here.

**/
struct OneStateModel : ExPostSmoothing {
    static decl U;
	static Initialize(U,Method=NoSmoothing,...);
    virtual Utility();
	}
	
/** Additve extreme value errors enter U().

<DT>Specification</DT>
<dd><pre>
U() = Utility(&alpha;,&eta;,&epsilon;,&theta;,&gamma;) + &zeta;
&zeta;.N = (&theta;.A).D          IID error for each feasible &alpha;
F(z<sub>i</sub>) = exp{ -exp{-x/&rho;} }
</pre>
<DT>Bellman Equation Iteration.</DT>
<DD><pre>
v(&alpha;;&epsilon;,&eta;) = exp{  &rho;( U + &delta;&sum; <sub>&theta;&prime;</sub> &Rho;(&theta;&prime;;&alpha;,&eta;,&theta;) EV(&theta;&prime;) ) }
V(&epsilon;,&eta;) = log(&sum;<sub>&alpha;</sub> v(&alpha;;&epsilon;,&eta;))
EV = &sum;<sub>&epsilon;,&eta;</sub> [ V(&epsilon;,&eta;)*f(&epsilon;)f(&eta;)/&rho; ]
</pre>
<DT>Choice Probabilities</DT>
<DD>Once EV() has converged<pre>
&Rho;*(&alpha;;&epsilon;,&eta;,&gamma;) =
</pre></dd>

**/
struct ExtremeValue : Bellman {
    static const decl lowb = 0.9*DBL_MIN_E_EXP,
                      hib = 0.9*DBL_MAX_E_EXP;
	static decl
		/** Choice prob smoothing &rho;.**/ rho,
		/** Hotz-Miller estimation task.**/ HMQ;
	static SetRho(rho);
	static Initialize(rho,userState,UseStateList=FALSE);
	static  CreateSpaces();
	virtual thetaEMax() ;
	virtual Smooth();
	virtual KernelCCP(task);
	}

/** Ergodic state transition with standard Extreme Value &zeta; and binary choice.

**/
struct Rust : ExtremeValue {
	static decl
	/**The decision variable. **/ d;
	static Initialize(userState);
	static CreateSpaces();
	}

/** Myopic choice problem (&delta;=0.0) with standard Extreme Value &zeta;.

**/
struct McFadden : ExtremeValue {
	static decl
	/**The decision variable. **/ d;
	static Initialize(Nchoices,userState,UseStateList=FALSE);
	static CreateSpaces();
	ActVal();
	}
	
/** DP Models that include additive normal choice-specific &zeta;.

**/
struct Normal : Bellman {
	static decl
					Chol,
	/** **/			AChol;
	static Initialize(userState,UseStateList=FALSE);
	static CreateSpaces();
	thetaEMax() ;
	virtual Smooth();
	virtual ActVal();
	}

/** Correlated errors and smooth  simulation of choice probabilities. **/
struct NnotIID : Normal {
	// GHK and Quadrature integration
	static decl
		/**  replications for GHK **/				R,
		/**  RNG seed argument **/					iseed,
		/**  . @internal;		**/					ghk;
	static Initialize(userState,UseStateList=FALSE);
	static SetIntegration(R,iseed,AChol);
	static CreateSpaces();
	static UpdateChol();
	ActVal();
    ExogExpectedV();
	}

/** Numerically integrate using Gauss-Hermite Quadrature.

**/
struct NIID : Normal {
	static decl
							MM,
							GQNODES,
							GQLevel;
	static Initialize(userState,UseStateList=FALSE);
	static SetIntegration(GQLevel,AChol);
	static CreateSpaces() ;
	static UpdateChol();
	ActVal();
    ExogExpectedV();
	}

/** One-dimensional action models with user defined distribution of &zeta;.

<DT>Allows for solving the model by finding cutoffs (reservation values) in a continuous error using the `ReservationValues` method.</DT>

<DT>The reservation value solution works when</DT>
<UL>
<LI>There is a single action variable <em>and</em></LI>
<LI>There are no exogenous (&epsilon;) or semi-exogenous (&eta;) states added to the model.  State variables that would be eligible
for inclusion in those vectors need to be placed in &theta;.</LI>
<LI>The model must exhibit a reservation property in z (i.e. a single-crossing property and if <code>d.N&gt;2</code> monotonicity in the crossing points.</LI>

<LI>Formally,</LI>
<DD><pre>
&alpha; = (d)
&zeta; = (z)
&epsilon; = ()
&eta; = ()

U(d;&zeta;,&theta;) = U(d;z,&theta;)
</pre></dd>

</UL>

<!--&exists; unique z*<sub>0</sub> &lt; z*<sub>1</sub> &hellip; &lt; z*<sub>a.N&oline;</sub> such that U(a;z,&theta;-->

<DT>The restrictions above do not apply if other solution methods are applied to a <code>OneDimensionalChoice</code>.</DT>

<DT>The user provides methods that return:</DT>
<UL>
<LI><code>Uz(z)</code>: the utility matrix at a given vector of cut-offs z. <code>Uz(z)</code> should return a <code>d.N &times; d.N-1</code> matrix equal to the
utility of each value of <code>d=i</code> at &zeta;=z<sub>j</sub>.  In the case of a binary choice there is just one cut-off and <code>Uz(z)</code> returns a column vector of
the utilities of the two choices at <code>z</code>  Internally the difference between adjacent values of <code>d</code> is computed from this matrix.</LI>

<LI><code>EUtility()</code>: an array of size <code>d.N</code> that returns the expected utlity of <code>d=j</code> for values of z in the interval (z*<sub>j-1</sub>,z*<sub>j</sub>)
and the corresponding probabilities &Rho;[z &in (z*<sub>j-1</sub>,z*<sub>j</sub>) ].  <code>EUtility()</code> gets
<code>z*star</code> from the data member `OneDimensionalChoice::zstar`.</LI>
</UL>


**/
struct OneDimensionalChoice : ExPostSmoothing {
	static 	decl
            /** scratch space for E[U] in z* intervals.     **/	EUstar,
            /** space for current Prob(z) in z* intervals. **/	pstar,
            /** single action variable. **/                     d;
			decl
            /** TRUE: solve for z* at this state.
                Otherwise, ordinary discrete choice.**/             solvez,
			/**N::Aind-1 x N::R array of reservation value vectors.  **/	zstar;
	static 	Initialize(userState,d=Two,UseStateList=FALSE);
	static  CreateSpaces(Method=NoSmoothing,smparam=1.0);
	virtual Uz(z);
	virtual EUtility();
    virtual Utility();
	virtual thetaEMax() ;
	virtual Smooth();  //pstar
	virtual ActVal();
    virtual SetTheta(state=0,picked=0);
    virtual Continuous();
            SysSolve(RVs); //VV
            Getz();
    virtual Setz(z);
	}

/** A OneDimensionalChoice model with discretized approximation to $\zeta$.

A discrete approximation to $\zeta$ enters the state vector if the decision is to accept (<code>d&gt;0</code>).

**/
struct KeepZ : OneDimensionalChoice {
	static 	decl
            /** Discrete state variable of kept &zeta;.**/ keptz, myios;
	static 	Initialize(userState,d=2,UseStateList=FALSE);
    static  SetKeep(N,held=TRUE);
	virtual thetaEMax();
	virtual ActVal();
    virtual DynamicActVal(z);
    virtual DynamicTransit(z);
    static  CreateSpaces();
	}
