#include "Outcomes.h"
/* This file is part of niqlow. Copyright (C) 2011-2018 Christopher Ferrall */

ExogAuxOut::ExogAuxOut() {
    ExTask();
    auxlike = zeros(N::Ewidth,1);
    }
ExogAuxOut::Likelihood(howmany,outcm) {
    decl tv;
    if (!sizeof(Chi)) return 1.0;
    this.outcm = outcm;
    auxlike[] = 1.0;
    if (howmany==DoAll) {
        loop();
        return auxlike;
        }
    else {
        Run();
        return auxlike[I::all[exog]];
        }
    }
ExogAuxOut::Run() {
    decl c;
    Hooks::Do(PreAuxOutcomes);
    foreach (c in Chi) if (c.indata) auxlike[I::all[onlyexog]] *= c->Likelihood(outcm);
    }

/**  Simple Panel Simulation.
@param Nsim  integer, number of paths to simulate per fixed group<br>[default] UseDefault, whic is 1
@param T	integer, length of panel<br>[default], length of lifecycle or  10
@param outopt integer [default] print to screen or <br/>string name of file to save to
@param ErgOrStateMat 0 [default]: find lowest reachable indexed state to start from<br/>
1: draw from stationary distribution (must be ergodic)<br/>matrix of initial states to draw from (each column is a different starting value)
@param DropTerminal TRUE: eliminate termainl states from the data set<br/>FALSE: [default] include terminal states.

This routine simplifies simulating a solved DP model.  Simply call it instead of creating an `Panel` object.

**/
SimulateOutcomes(Nsim,T,outopt,ErgOrStateMat,DropTerminal) {
    decl op = new Panel("simdata"), TT;
    if (T==UseDefault) {
        TT = Flags::IsErgodic ? 10: N::T;
        }
    else TT = T;
    op -> Simulate(Nsim==UseDefault ? 1 : Nsim,TT,ErgOrStateMat,DropTerminal);
    op -> Print( isint(outopt) ? 2 : outopt );
    delete op;
    }

/** Record everything about a single realization of the DP.
@param prior `Outcome` object, the previous realization along the path<br/>
		<em>integer</em>, this is first realization on the path. `Task::state` uninitialized.<br/>
		<em>vector</em>, initial value of `Task::state`
**/
Outcome::Outcome(prior) {
    Task();
    left = SS[onlysemiexog].left;
	right = SS[tracking].right;
	decl nxtstate;
	snext = onext = UnInitialized;
	act   = constant(.NaN,1,SS[onlyacts].D);
	z     = constant(.NaN,1,zeta.length);
	aux   = constant(.NaN,1,N::aux);
	Ainds = <>;
	if (isclass(prior)) {
		prev = prior;
		t = prev.t+1;
		nxtstate = prior.snext;
		prior.onext = this;
		}
	else {
		prev = t = 0;
		nxtstate = prior;
		}	
	state = isint(nxtstate) ? constant(.NaN,N::All) : nxtstate;
	ind = new array[DSubSpaces];
	ind[onlyacts+1:] = DoAll;
	ind[onlyacts] = new array[N::J];
    if (isint(exaux)) exaux = new ExogAuxOut();
    decl d;
    foreach (d in fixeddim)
        if (     !isnan(state[ SS[d].left:SS[d].right ]))
            ind[d] = I::OO[d][ SS[d].left:SS[d].right ]
                       *state[ SS[d].left:SS[d].right ];
	}

/** clean up.
@comments
Does not delete prev and next to avoid recursion.
**/
Outcome::~Outcome() {
	if (isclass(prev)) prev.onext = UnInitialized;
	delete ind, aux, act, z, state, Ainds;
	}

/** Return the outcome as a (flat) row vector.

Used to print or save a series or panel as a matrix.

<DD>Columns:<pre>
t ~ State_Ind ~ Type ~ Aind ~ &epsilon; ~ eta; ~ &theta; ~ &gamma; ~ &alpha; ~
&zeta; ~ aux
</pre></DD>

**/
Outcome::Flat(Orientation)	{
	if (!Settheta(ind[tracking])) return <>;
    if (Orientation==LONG)
        return t~ind[tracking]~I::curth.Type~I::curth.Aind~state'~ind[onlyacts][0]~act~z~aux;
    else
        return  state'~act~z~aux;
    // prefix(tprefix(t),labels),
    //ind[onlyacts] shows only A[0] index.
	}


/** Print the outcome as record.


**/
Outcome::Deep(const depth)	{
	decl pfx = depth*5;
    Settheta(ind[tracking]);
    Indent(pfx); println("|----------");
    Indent(pfx); println("|t:",t);
    Indent(pfx); println("|ind:",ind[tracking]);
    Indent(pfx); println("|act:",ind[onlyacts][0]);
    Indent(pfx); println("|",isclass(onext) ? "-->" : "----------");
	}

/** Simulate the IID stochastic elements of a realization.

&theta; and &gamma; areas of `Task::state` already set.
The &epsilon; and &eta; elements are simulated from their
transitions.  Then `Bellman::Simulate` called to simulate
&zeta;, &apha;, and &Upsilon;.
@return TRUE if path is ended, FALSE otherwise
@see DP::DrawOneExogenous, Bellman::Simulate
**/
Outcome::Simulate() {
	decl i,f;
    for (i=0;i<columns(fixeddim);++i) ind[fixeddim[i]] = I::OO[fixeddim[i]][]*state;
    state[S[exog].M:S[semiexog].X] = 0;
	ind[bothexog] = DrawOneExogenous(&state);
	ind[onlyexog] = I::OO[onlyexog][]*state;
	ind[onlysemiexog] = I::OO[onlysemiexog][]*state;
	SyncStates(0,N::S-1);
    I::Set(state,FALSE);
	if (!isclass(I::curth)) oxrunerror("DDP Error 49. simulated state"+sprint(ind[tracking])+" not reachable");
	snext = I::curth->Simulate(this);
	return snext==UnInitialized;
	}

/** Create a new series of `Outcome`s along a realized path.
@param id <em>integer</em>, id or tag for the path.
@param state0 <code>UnInitialized</code> (-1), set state to uninitalized<br/>
&gt; 0 fixed effect index to use, <br/><em>vector</em>, initial state
**/
Path::Path(i,state0) {
	decl ni;
	T = 0;
	this.i = i;
	if (isint(state0) && state0!=UnInitialized)
			Outcome( DrawGroup(state0).state );
	else Outcome(state0);
	last = pnext = UnInitialized;
	if ( (N::R>One || N::DynR>One ) && isint(summand)) {
		summand = new RandomEffectsIntegration();
		upddens = new UpdateDensity();
		}
	}

/** Destroy all outcomes along a path. **/
Path::~Path() {
	while (isclass(onext)) {
		cur = onext.onext;
		delete onext;
		onext = cur;
		}
	if (isclass(summand)) {delete summand, upddens ; summand=UnInitialized;}
	~Outcome();
	}	

/** Produce a matrix representation of the path.
Path id (`Path::i`) is appended as the first column.
Each row is an `Outcome`.
@return TxM matrix
**/
Path::Flat(Orientation){
	decl pth = <>,curo;
	cur = this;
	do {
        curo = cur->Outcome::Flat(Orientation);
        if (Orientation==LONG)
            pth |= i ~curo;
        else
            pth ~= curo;
        } while((isclass(cur = cur.onext)));
	return pth;
	}	

/** Produce a two dimensional view of the path;
**/
Path::Deep(){
    decl j=1;
	cur = this;
    Indent(j);println("_________________________________________________________________________________");
    Indent(j);println("|Path: ",i," --> ");
	do cur->Outcome::Deep(++j); while((isclass(cur = cur.onext)));
	}	

/** Simulate a list of realized states and actions from an initial state.

Checks to see if transition is &Rho; is <code>tracking</code>.  If not, process span the state space with `EndogTrans`.
@param T integer, max. length of the panel<br/>0, no maximum lenth; simulation goes on until a Terminal State is reached.


@example <pre>
</pre></dd>

**/
Path::Simulate(T,DropTerminal){
	decl done;
	cur = this;
	this.T=1;  //at least one outcome on a path
    if (T==UnInitialized) T = INT_MAX;
    Flags::Phase = Simulating;
    do {
       done = cur->Outcome::Simulate();
       if ( done || this.T>=T || (isclass(pathpred) && pathpred->AppendSimulated(cur)) ) break;
       ++this.T;
       cur = !isclass(cur.onext) ? new Outcome(cur) : cur.onext;
       } while(TRUE);
	if (DropTerminal && done && this.T>1) {  //don't delete if first state is terminal!! Added March 2015.
		last = cur.prev;
		delete cur;
		last.onext = UnInitialized;
		--this.T;
		}
	else
		last = cur;
	}

/** Load the first or next outcome in the path.
@param observed source data to extract observables from<br/>
**/
Path::Append(observed) {
	last = (T) ? new Outcome(last) : this;
	last->FromData(observed);
	++T;
	}
	
/** Store a panel of realized paths with common fixed group.
@param f integer tag for the panel (such as replication index) [default=0]
@param method `Method` to call to solve<br/>0 [default] do nothing, something else handles solution
**/
FPanel::FPanel(f,method) {
	this.f = f;
	this.method = method;
	Path(0,UnInitialized);
	if (isint(SD)&&Flags::IsErgodic) SD = new SDTask();
	fnext = UnInitialized;
	NT = N = 0;
	L = <>;
	cur = this;
	}

FPanel::GetCur() { return cur; }

/** Destroy all paths in a fixed panel.
**/
FPanel::~FPanel() {
	while (isclass(pnext)) {	//end of panel not reached
		cur = pnext.pnext;
		delete pnext;
		pnext = cur;
		}
	if (isclass(SD)) {delete SD; SD = UnInitialized;}
	~Path();				//delete root path
	}	

/** Simulate a homogenous panel (fpanel) of paths.
@param Nsim &gt; 0, number of paths to simulate
@param Tmax maximum path length<br/>0 no maximum length.
@param ErgOrStateMat 0 [default]: find lowest reachable indexed state to start from<br/>
1: draw from stationary distribution (must be ergodic)<br/>matrix of initial states to draw from (each column is a different starting value)
@param DropTerminal TRUE: eliminate termainl states from the data set<br/>FALSE: [default] include terminal states.
@param pathpred 0 [default] or PathPrediction object to filter simulated values
@comments &gamma; region of state is masked out.
**/
FPanel::Simulate(Nsim, T,ErgOrStateMat,DropTerminal,pathpred){
	decl msucc=FALSE, ii = isint(ErgOrStateMat), erg=ii&&(ErgOrStateMat>0), iS, curg,
         Nstart=columns(ErgOrStateMat), rvals, curr, i;
	if (Nsim <= 0) oxrunerror("DDP Error 50a. First argument, panel size, must be positive");
    if (ii) {
	   if (erg) {
		  if (!isclass(SD)) oxrunerror("DDP Error 50b. model not ergodic, can't draw from P*()");
		  SD->SetFE(f);
		  SD->loop();
		  }
        else {
           iS = 0; while (!Settheta(iS)) ++iS;
           iS = ReverseState(iS,tracking);
           }
        }
	if (isclass(upddens)) {
        upddens->SetFE(f);
		upddens->loop();
        rvals = DrawFsamp(f,Nsim);
        }
    else rvals = matrix(Nsim);
    if (Flags::IsErgodic && !T) oxwarning("DDP Warning 08.\nSimulating ergodic paths without fixed Tmax?\nPath may be of unbounded length.");
	cputime0 = timer();
    Outcome::pathpred = pathpred;
	cur = this;
    NT = 0;
    for (curr=0;curr<columns(rvals);++curr) {
        if (!rvals[curr]) continue;  // no observations
	    if (isclass(method)) {
            if (!method->Solve(f,curr)) oxrunerror("DDP Error. Solution Method failed during simulation.");
            }
	    curg = SetG(f,curr);
        for(i=0;i<rvals[curr];++i) {
            cur.state = curg.state;
		    cur.state += (erg) ? curg->DrawfromStationary()
                           : ( (ii)
                                ? iS
                                : ErgOrStateMat[][imod(this.N,Nstart)]
                              );
            I::Set(cur.state,TRUE);
		    cur->Path::Simulate(T,DropTerminal);
		    NT += cur.T;
		    if (++this.N<Nsim && cur.pnext==UnInitialized) cur.pnext = new Path(this.N,UnInitialized);
            cur = cur.pnext;
		    }
        }
	if (!Version::MPIserver && Data::Volume>SILENT) fprintln(Data::logf," FPanel Simulation time: ",timer()-cputime0);
	}

FPanel::Append(pathid) {
	if (N) cur = cur.pnext = new Path(pathid,UnInitialized);
	++N;
	}
	
/** Return the fixed panel as a flat matrix.
index of panel
@return long <em>matrix</em> of panels
**/
FPanel::Flat(Orientation)	{
	decl op = <>;
	cur = this;
	do op |= f ~ cur->Path::Flat(Orientation); while ((isclass(cur = cur.pnext)));
	return op;
	}

/** .
**/
FPanel::Deep()	{
	cur = this;
    println("Fpanel: ",f);
	do cur->Path::Deep(); while ((isclass(cur = cur.pnext)));
	}

/** Set the nested DP solution method to use when evaluating the panel's econometric objective.
@param method `Method`
**/
Panel::SetMethod(method) {
    decl fp=this;
    do {   fp.method = method; } while ((isclass(fp=fp.fnext)));
    }

/** Store a list of heterogenous fixed panels.
@param r integer tag for the panel (such as replication index)
@param method `Method` `Method` object, the DP solution to call to solve `FPanel`
problem.<br/>(default) 0 do nothing, something else handles solution
**/
Panel::Panel(r,method) {
	decl i, q;
    this.method = method;
    if (!isint(r)) {
        oxwarning("Panel tag should be an integer");
        this.r = Zero;
        }
    else
	     this.r = r;
	FPanel(0,method);	
	fparray = new array[N::F];
	fparray[0] = 0;
	flat = FNT = 0;
	cur = this;
	for (i=1;i<N::F;++i) cur = cur.fnext = fparray[i] = new FPanel(i,method);
	if (isint(LFlat)) {
        LFlat = new array[FlatOptions];
		LFlat[LONG] = {PanelID}|{FPanelID}|{PathID}|PrefixLabels|Labels::Vprt[svar]|{"|ai|"}|Labels::Vprt[avar];
		LFlat[WIDE] = Labels::Vprt[svar]|Labels::Vprt[avar];
		for (i=0;i<zeta.length;++i) {
                LFlat[LONG] |= "z"+sprint(i);
                LFlat[WIDE] |= "z"+sprint(i);
                }
		foreach (q in Chi) {
            LFlat[LONG] |= q.L;
            LFlat[WIDE] |= q.L;
            }
		Fmtflat = {"%4.0f","%4.0f"}|{"%4.0f","%4.0f","%7.0f","%3.0f"}|Labels::Sfmts|"%4.0f";
		for (i=0;i<N::Av;++i) Fmtflat |= "%4.0f";
		for (i=0;i<zeta.length;++i) Fmtflat |= "%7.3f";
        foreach (q in Chi) Fmtflat |= "%7.3f"; //		for (i=0;i<Naux;++i) Fmtflat |=        "%7.3f";
		}
	}

/** Destroy all `FPanel`s in the Panel.
**/
Panel::~Panel() {
	while (isclass(fnext)) {	//end of panel not reached
		cur = fnext.fnext;
		delete fnext;		//delete fpanel
		fnext = cur;
		}
	~FPanel();				//delete root panel
	}

/** Simulate a (heterogeneous) panel.
Each value of fixed &gamma; is simulated N times, drawing
the random effects in &gamma; from their density.
@param N <em>integer</em> number of paths to simulate in each `FPanel`.
@param T <em>Integer</em>, max length of each path<br/>
        vector, max length for each FPanel.
@param ErgOrStateMat 0: find lowest reachable indexed state to start from<br/>
1: draw from stationary distribution (must be ergodic)<br/>
matrix of initial states to draw from (each column is a different starting value)
@param DropTerminal TRUE: eliminate termainl states from the data set
@param pathpred Integer [default] or PathPrediction object that is simulating
**/
Panel::Simulate(N,T,ErgOrStateMat,DropTerminal,pathpred) {
	cur = this;
    FN = 0;
    decl fpi = 0;
	do { // Update density???
		cur->FPanel::Simulate(N,isint(T)? T : T[fpi],ErgOrStateMat,DropTerminal,pathpred);
		FNT += cur.NT;
        FN += N;
        ++fpi;
		} while ((isclass(cur = cur->fnext)));
	}

/** Store the panel as long flat matrix. **/
Panel::Flat(Orientation)	{
	cur = this;
	flat = <>;
	do {
        flat |= r~cur->FPanel::Flat(Orientation);
        } while ((isclass(cur = cur.fnext)));
	}

/** Print the deep view of the panel. **/
Panel::Deep()	{
	cur = this;
	do cur->FPanel::Deep(); while ((isclass(cur = cur.fnext)));
	}

/** Produce a matrix of the panel.
If  `Panel::flat`is an uninitialized then `Panel::Flat`() is called first.
Flat version of the data set is stored in `Panel::flat`.
@param fn 0: do not print or save, just return<br/>1 print to data log file<br/>2 print to screen<br/>string: save to a
file
@param Orientation  LONG or WIDE
@return long <em>matrix</em> of panels
**/
Panel::Print(fn,Orientation)	{
	if (isint(flat)) Flat(Orientation);
	if (isint(fn)) {
        if (fn==1) fprint(Data::logf,"%c",LFlat[Orientation],"%cf",Fmtflat,flat);
        else if (fn>1) {
            if (Version::HTopen) println("</pre><a name=\"Panel\"/><pre>");
            println("-------------------- Panel ------------------------\n");
            println("%c",LFlat[Orientation],"%cf",Fmtflat,flat);
            println("\n-------------------- End Panel --------------------\n");
            }
        }
	else if (!savemat(fn,flat,LFlat[Orientation])) oxrunerror("DDP Error 51. FPanel print to "+fn+"failed");
	}

/** Get tracking probabilities and tomorrow indices consistent with tomorrow's observation .
@return TRUE if there are tomorrow states that are consistent, FALSE otherwise **/
Outcome::TomIndices(qind,xind) {
    icol = 0;
	[TF,TP] = GetTrackTrans(qind,xind);           //Oct. 2018 was ind[onlysemiexog]
	return columns(viinds[tom]) && rows(intersection(viinds[tom],TF,&icol));
    }

Outcome::Likelihood(Type) {
    switch_single(Type) {
        case CCLike     : CCLikelihood();
        case ExogLike   : IIDLikelihood();
        case PartObsLike: PartialObservedLikelihood();
        }
    }

Outcome::AuxLikelihood(howmany) {
    decl al, hold = state[left:right], xind = howmany==DoAll ? onlysemiexog : bothexog;
    exaux.state[:right] = state[:right]
            = (ReverseState(ind[xind],xind)+ReverseState(viinds[now],tracking))[:right];
    SyncStates(left,right);
    I::Set(state,FALSE);
    al = exaux->Likelihood(howmany,this);
    state[left:right] = hold;
    return al;
    }

/** Compute conditional forward likelihood of an outcome.
<dd>
$$L(\theta) = \sum_{\eta} \sum_{\alpha} P*() P()$$
</dd>
**/
Outcome::PartialObservedLikelihood() {
	decl h, ep, q, PS, bothrows, curprob, totprob,
		dosemi = ind[onlysemiexog]==DoAll ? range(0,S[onlysemiexog].N-1)' : ind[onlysemiexog],
		einds =  ind[onlyexog]    ==DoAll ? range(0,N::Ewidth-1)          :	ind[onlyexog];
	viinds[now] = vecr(ind[tracking])';
	vilikes[now] = zeros(viinds[now]);
	for(q=0;q<columns(viinds[now]);++q) {                  //loop over current states consistent with data so far
		arows=ind[onlyacts][Ainds[q]];                    //action rows consistent with this state
		PS = GetPstar(viinds[now][q])[arows][];         //choice probabilities of consistent actions
		for (h = 0,totprob = 0.0;h<sizeof(dosemi);++h) {      //loop over semi-exogenous values
			bothrows = dosemi[h]*N::Ewidth + einds;                       //combination of consistent epsilon and eta values
			curprob = sumr( PS[][ bothrows ].*NxtExog[Qprob][ bothrows ]' )';  //combine cond. choice prob. and iid prob. over today's shocks
			totprob += sumc(NxtExog[Qprob][ bothrows ]);                      //prob. over consistent iid shocks
			vilikes[now][q] +=       // add to today's conditional probability
                    TomIndices(viinds[now][q],dosemi[h])
					? curprob*sumr(TP[arows][icol[1][]] .* vilikes[tom][icol[0][]]) // combine tomorrow's prob. with todays iid & choice prob.
					: sumr(curprob);       //no states tomorrow, just add up today.
   			}
		vilikes[now][q] /= totprob;   //cond. prob.
		}
	}	

/** Compute likelihood of an outcome given observablity of &theta; and &eta; but integrating over &epsilon;
<dd>
$$L(\theta) = $$
</dd>
**/
Outcome::IIDLikelihood() {
    decl ep, lo, curprob, hi;
    viinds[now] = ind[tracking];
    arows=ind[onlyacts][Ainds[0]];
    lo = ind[onlysemiexog]*N::Ewidth;
    hi = lo + N::Ewidth-1;
    curprob =NxtExog[Qprob][ lo:hi ] ;  //need to get conditional prob. of eta
    vilikes[now] =     vilikes[!now]          //future like
                    *  curprob                // distn of exogenous variables
                    .* (OnlyTransitions
                        ? 1.0
                        : GetPstar(viinds[now])[arows][lo:hi]'  //CCP
                        );
    vilikes[now] .*= AuxLikelihood(DoAll);
    vilikes[now] *= TomIndices(viinds[now],ind[onlysemiexog])
                                ? TP[arows][icol[1][0]]
                                : 1.0;
    vilikes[now] = double( sumc(vilikes[now])/sumc(curprob) );
	}	


/** Compute likelihood of choices and transitions this period
    assuming full state and action observability.

**/
Outcome::CCLikelihood() {
    decl c;
    viinds[now] = ind[tracking];
    arows       = ind[onlyacts][Ainds[0]];
    vilikes[now]= vilikes[!now]
                    * (OnlyTransitions
                        ? 1.0
                        : double( GetPstar(viinds[now])[arows][ind[bothexog]]) );
    vilikes[now] *= AuxLikelihood(UseCurrent);
	if (viinds[tom]==UnInitialized) return;
    vilikes[now] *= TomIndices(viinds[now],ind[onlysemiexog]) ? TP[arows][icol[1][0]] : 1.0;
	}

/** Integrate over the path.

**/
Path::TypeContribution(pf,subflat) {
	decl cur;
	now = NOW;
    viinds[!now] = <>;
    vilikes[!now] = (LType==PartObsLike)
                            ? <>          //build up contingent future likes
                            : <1.0>;      //next state observed up to IID states
	cur = last;
	do {
		tom = !now;
		cur->Outcome::Likelihood(LType);
		now = !now;
		} while((isclass(cur = cur.prev)));
    L = pf*double(sumr(vilikes[!now])); //final like always in !now.
	return L;
	}

/** Compute likelihood of a realized path.
**/
Path::Likelihood() {
    Flags::Phase = Liking;
	if (isint(viinds)) {
		viinds = new array[DVspace];
		vilikes = new array[DVspace];
		}
	if (isclass(summand))
		[L,flat] = summand->Integrate(this);
	else
		TypeContribution();  //density=1.0 by default
    }
	
DataColumn::DataColumn(type,obj) {
	this.type = type;
	this.obj = obj;
	incol = ind = label = UnInitialized;
    obsv = FALSE;
	force0 = (ismember(obj,"N") && obj.N==1) ;  // force quantities that have only  1 value observed
	}

DataColumn::Observed(LorC) {
	obsv = TRUE;
	if (isstring(LorC)) {
		label = LorC;
		return;
		}
	if (isint(LorC)) {
		if (LorC==UseLabel)
			label = obj.L;
		else
			ind = LorC;
		return;
		}
	oxrunerror("DDP Error 53. LorC should be string or integer");		
	}

DataColumn::UnObserved() {
	obsv = FALSE;
	incol = ind = label = UnInitialized;

	}

DataColumn::ReturnColumn(dlabels,incol)	{
	this.incol = incol;
	if (isstring(label)) return strfind(dlabels,label);
	return ind;
	}
	
/** Compute the vector log-likelihood for paths in the fixed (homogeneous) panel.
The vector of path log-likelihoods is stored in `FPanel::FPL`.
<DT>If the method is a class</DT>
<DD> `Method::Solve`() is called first.</DD>
<DD>If `Task::done` equals <code>IterationFailed</code> the likelihood is not
computed. <code>FPL</code>
is set to a vector of <code>.NaN</code>.</DD>
**/
FPanel::LogLikelihood() {
	decl i,cur;
	cputime0 =timer();
	if (isclass(method)) {
        if (!method->Solve(f)) {
	       FPL = constant(.NaN,N,1);
           return FALSE;
           }
        }
    else
        if (Flags::UpdateTime[AfterFixed]) {ETT->Transitions(); }
	FPL = zeros(N,1);  //NT
    if (isclass(upddens)) {
		upddens->SetFE(state);
		summand->SetFE(state);
		upddens->loop();
		}
	for (i=0,cur = this;i<N;++i,cur = cur.pnext) {
        cur->Path::Likelihood();
		FPL[i] = log(cur.L);
		}
    return TRUE;
	}


/**Compute the vector of log-likelihoods.
The vector of path log-likelihoods is stored in `Panel::M`,
it is constructed by appending each `FPanel::FPL`.
If `FPanel::method` is an object, then <code>`FPanel::method`-&gt;Solve()</code>
is called.
@see OutcomeDataSet::EconometricObjective
**/
Panel::LogLikelihood() {
    decl succ;
	cur = this;
	M = <>;	
    succ = TRUE;
	if (!isclass(method) && Flags::UpdateTime[OnlyOnce]) {ETT->Transitions(state);}
	do {
		succ = succ && cur->FPanel::LogLikelihood();
		M |= cur.FPL;
		} while ((isclass(cur=cur.fnext)));
    return succ;
	}

Path::Mask() {		
	cur = this;
    AnyMissing[] = FALSE;
    do { cur ->Outcome::Mask();	} while ( (isclass(cur = cur.onext)) );
    if (any(AnyMissing[maskoffs]))
        LType = PartObsLike;
    else if (AnyMissing[onlyexog])
        LType = ExogLike;
    else
        LType = CCLike;
	}	
	
FPanel::Mask(aLT) {
	cur = this;	do { cur -> Path::Mask(); aLT[0][cur.LType] += 1;} while ( (isclass(cur = cur.pnext)) );
	}	

/** Mask unobservables.
**/
OutcomeDataSet::Mask() {
	decl s;
	if (isint(mask)) mask = new array[NColumnTypes];
    for(s=0;s<NColumnTypes;++s) mask[s] = <>;
	// if (list[0].obsv!=TRUE) list[0].obsv=FALSE; Oct 2018.  Initialized to FALSE so not needed
	for(s=0;s<N::Av;++s)
		if (!list[s+low[avar]].obsv && !list[s+low[avar]].force0) mask[avar] |= s;
	for(s=0;s<N::S;++s)
		if (!list[s+low[svar]].obsv && !list[s+low[svar]].force0) mask[svar] |= s;
	for(s=0;s<N::aux;++s) {
		if (!list[s+low[auxvar]].obsv) mask[auxvar] |= s;
        list[s+low[auxvar]].obj.indata = list[s+low[auxvar]].obsv;
        }
	if (!Version::MPIserver && Data::Volume>SILENT) Summary(0);
	cur = this;
    LTypes[] = 0;
	do {
        cur -> FPanel::Mask(&LTypes);
        } while ((isclass(cur = cur.fnext)));
	masked = TRUE;
    println("Path like type counts","%c",{"CCP","IID","PartObs"},"%cf","%7.0f",LTypes');
   }

/** set the column label or index of the observation ID.
@param lORind string, column label<br>integer&ge;0 column index;
**/
OutcomeDataSet::IDColumn(lORind) {
	if (isint(lORind)&&lORind<0) oxrunerror("DDP Error 54. column index cannot be negative");
	list[idvar]->Observed(lORind);
	}

OutcomeDataSet::tColumn(lORind) {
	if (isint(lORind)&&lORind<0) oxrunerror("DDP Error 54. column index cannot be negative");
    list[low[svar]+counter.t.pos] -> Observed(lORind);
    }

/** Identify a variable with a data column.
@param aORs  Either an `ActionVariable`, element of &alpha;, or a `StateVariable`,
    element of one of the state vectors, or a `AuxiliaryValue`, element of &chi;<br/>
            <em>OR<em><br/>
@param LorC	 UseLabel, variable's label to denote column of data with observations <br/>
             integer &ge; 0, column of data matrix that contains observations<br/>
			 string, label of column with observations.

**/
OutcomeDataSet::MatchToColumn(aORs,LorC) {
	if (StateVariable::IsBlock(aORs)) oxrunerror("DDP Error 55. Can't use columns or external labels to match blocks. Must use ObservedWithLabel(...)");
	decl offset,k;
	if (!Version::MPIserver && Data::Volume>SILENT) fprint(Data::logf,"\nAdded to the observed list: ");
	offset = isclass(aORs,"ActionVariable") ? 1
				: isclass(aORs,"StateVariable") ? 1+N::Av
				: 1+N::Av+N::S;
	if (list[offset+aORs.pos].obsv==FALSE && masked) oxrunerror("DDP Error 56. cannot recover observations on UnObserved variable after reading/masking");
	list[offset+aORs.pos]->Observed(LorC);				
	if (!Version::MPIserver && Data::Volume>SILENT) fprint(Data::logf,aORs.L," Matched to column ",LorC);
    }

	
/** Mark actions and state variables as observed in data, matched with their internal label.
@param aORs  Either an `ActionVariable`, element of &alpha;, or a `StateVariable`, element of
			one of the state vectors, or a `AuxiliaryValue`, element of &chi;<br/>
            <em>OR<em><br>
            array of the form {v1,v2,&hellip;}.  In this case all other arguments are
            ignored.<br/>
@param ... continues with object2, LoC2, object3, LorC3, etc.<br/>
**/
OutcomeDataSet::ObservedWithLabel(...
    #ifdef OX_PARALLEL
    va
    #endif
) {
	decl offset,aORs,LorC,k,bv;
	if (!Version::MPIserver && Data::Volume>SILENT) fprint(Data::logf,"\nAdded to the observed list: ");
    foreach (aORs in va) {
		if (StateVariable::IsBlock(aORs)) {
	        foreach (bv in aORs.Theta) ObservedWithLabel(States[bv]);
		    continue;
			}
		offset = isclass(aORs,"ActionVariable") ? 1
				: isclass(aORs,"StateVariable") ? 1+N::Av
				: isclass(aORs,"AuxiliaryValue") ? 1+N::Av+N::S
                : 0;
		if (list[offset+aORs.pos].obsv==FALSE && masked)
            oxrunerror("DDP Error 57. cannot recover observations on UnObserved variable after reading/masking");
		list[offset+aORs.pos]->Observed(UseLabel);				
		if (!Version::MPIserver && Data::Volume>SILENT) fprint(Data::logf,aORs.L," ");
		}
	if (!Version::MPIserver && Data::Volume>SILENT) fprintln(Data::logf,".");
	}

/** UnMark action and states variables as observed.
@param as1 `Discrete` object, either an `ActionVariable`, element of &alpha;, or a
`StateVariable`, element of
			one of the state vectors<br/>
			`StateBlock`: each variable in the block will be marked unobserved.
@param ... as2, etc.

@comments Does nothing unless variable was already sent to
`OutcomeDataSet::ObservedWithLabel`();
**/
OutcomeDataSet::UnObserved(...
    #ifdef OX_PARALLEL
    va
    #endif
) {
	decl offset,aORs,k;
	for (k=0;k<sizeof(va);++k) {
		aORs = va[k];
		if (StateVariable::IsBlock(aORs)) {
			decl bv;
			foreach (bv in aORs.Theta) UnObserved(States[bv]);
			continue;
			}
		offset = isclass(aORs,"ActionVariable") ? 1
				: isclass(aORs,"StateVariable") ? 1+N::Av
				: 1+N::Av+N::S;
		if (list[offset+aORs.pos].obsv==TRUE) list[offset+aORs.pos]->UnObserved();
		}
    masked = FALSE;  // reset masked.
	}
	
/**  Copy external current values of actions, states and auxiliaries into the outcome.
This calls `Outcome::AccountForUnobservables'
**/
Outcome::FromData(extd) {
	act[] = extd[avar][];
	state[] = extd[svar][];
	aux[] = extd[auxvar][];
	AccountForUnobservables();
	}

/**  Set all unobserved values to NaN.
This calls `Outcome::AccountForUnobservables'
**/
Outcome::Mask() {
	act[mask[avar]] = .NaN;
	state[mask[svar]] = .NaN;
	aux[mask[auxvar]] = .NaN;
	AccountForUnobservables();
	}
	
/** Modify outcome to list indices of states consistent with observables.
**/
Outcome::AccountForUnobservables() {
	decl s, ss, myA, ai, myi, inta;
	for (ss=1;ss<DSubSpaces;++ss)
		if ( (ind[ss]==DoAll)|| any(isdotnan(state[SS[ss].left:SS[ss].right]))) {  //have to integrate over states
            AnyMissing[ss] = TRUE;
			ind[ss] = <0>;
			for(s=SS[ss].left;s<=SS[ss].right;++s)
                if ( I::OO[ss][s] )	{  //more than one value of state s
					if (isnan(state[s]))  // all values of s are possible
						ind[ss] = vec(ind[ss]+reshape(I::OO[ss][s]*States[s].vals',
                                                       rows(ind[ss]),States[s].N)); //Oct. 2018 was .actual????
					else
						ind[ss] += I::OO[ss][s]*state[s];  // add index of observed state value
					}
			}					
	s = 0;
	Ainds = <>;
  	do {
		if (( (myA = GetAind(ind[tracking][s]))!=NoMatch )) {
			ai =  Alpha::AList[myA]*SS[onlyacts].O;	 // indices of feasible acts
			myi = selectifr( Alpha::AList[myA],prodr((Alpha::AList[myA] .== act) + isdotnan(act)) )
					* SS[onlyacts].O; //indices of consistent acts
			if (sizeof(intersection(ai,myi,&inta))) {  // some feasible act are consistent
				if (!ismatrix( ind[onlyacts][myA] )) {
                    ind[onlyacts][myA] = matrix(inta[0][]);	  //rows of A[Aind] that are consistent with acts
                    if (!AnyMissing[onlyacts] && rows(ind[onlyacts][myA])>1) AnyMissing[onlyacts] = TRUE;
                    }
				Ainds |= myA;  // keep track of which feasible set goes with state s
		  		++s;
				}
			else  //observed actions not feasible at this tracking state
				ind[tracking] = dropr(ind[tracking],matrix(s));	  //do not increment s because of drop
			}
		else   // trim unreachable states from list
			ind[tracking] = dropr(ind[tracking],matrix(s));	 //do not increment s because of drop
		} while (s<sizeof(ind[tracking]));
//    println("acts",ind[onlyacts]," groups ",ind[bothgroup]," tracking",ind[tracking],"---------");
	}

/** The default econometric objective: log-likelihood.
@param subp  DoAll (default), solve all subproblems and return likelihood vector<br/>
             Non-negative integer, solve only subproblem, return contribution to
             overall L
@return `Panel::M`, <em>lnL = (lnL<sub>1</sub> lnL<sub>2</sub> &hellip;)</em>
@see Panel::LogLikelihood
**/
OutcomeDataSet::EconometricObjective(subp) {
	if (!masked) {oxwarning("DDP Warning 09.\n Masking data for observability.\n"); Mask();}
    if (subp==DoAll) {
	   this->Panel::LogLikelihood();
	   return M;
         }
    else {
        oxrunerror("OutcomeDataSet Objective not updated for subproblem parallelization");
        }
	}

/** Produce a Stata-like summary statistics table.
@param data <em>matrix</em>, data to summarize<br><em>integer</em>, summarize `Panel::flat`
@param rlabels [default=0], array of labels

**/
OutcomeDataSet::Summary(data,rlabels) {
	decl rept = zeros(3,0),s;		
	foreach (s in list) rept ~= s.obsv | s.force0 | s.incol;
	fprintln(Data::logf,"\nOutcome Summary: ",label);
	fprintln(Data::logf,"%c",Labels::Vprt[idvar]|Labels::Vprt[avar]|Labels::Vprt[svar]|Labels::Vprt[auxvar],"%r",{"observed"}|{"force0"}|{"column"},"%cf","%6.0f",rept);
    if (ismatrix(data)) MyMoments(data,rlabels,Data::logf);
    else {
        Print(0);
        MyMoments(flat,{"f"}|"r"|"i"|"t"|"track"|"type"|"Ai"|Labels::Vprt[svar]|"Arow"|Labels::Vprt[avar]|Labels::Vprt[auxvar],Data::Volume>QUIET ? 0 : Data::logf);
        }
	}
	
/** Load data from the Ox DataBase in <code>source</code>.
@internal
**/
OutcomeDataSet::LoadOxDB() {
	decl s,curid,data,curd = new array[NColumnTypes],row,obscols,inf,fpcur,obslabels,nc;
	dlabels=source->GetAllNames();
	obscols=<>;
    obslabels = {};
	for(s=0;s<sizeof(list);++s)
		if (list[s].obsv==TRUE) {
			obscols |= nc = list[s].ReturnColumn(dlabels,sizeof(obscols));
            obslabels |= dlabels[nc];
            }
		else
			list[s].obsv=FALSE;
	data = source->GetVarByIndex(obscols);
    for (s=S[fgroup].M;s<=S[fgroup].X;++s)
            if (list[N::Av+s].obsv)
                data = deleteifr(data,data[][list[N::Av+s].incol].>=SubVectors[fgroup][s].N);
	if (Data::Volume>SILENT) Summary(data,obslabels);
	curid = UnInitialized;
	cur = this;
	FN = N = 0;
	curd[avar] = constant(.NaN,1,N::Av);
	curd[svar] = constant(.NaN,N::S,1);
	curd[auxvar] = constant(.NaN,1,N::aux);	
	for (row=0;row<rows(data);++row) {
		curd[idvar] = data[row][list[0].incol];
		for(s=0;s<N::Av;++s) {
			curd[avar][0][s] = (list[low[avar]+s].obsv)
						          ? data[row][list[low[avar]+s].incol]
						          : (list[low[avar]+s].force0)
							          ? 0
							          : .NaN;
            }
		for(s=0;s<N::S;++s) {
			curd[svar][s] = (list[low[svar]+s].obsv)
						      ? data[row][list[low[svar]+s].incol]
						      : (list[low[svar]+s].force0)
							     ? 0
							     : .NaN;
			}
		for(s=0;s<N::aux;++s)
			curd[auxvar][0][s] = (list[low[auxvar]+s].obsv)
						          ? data[row][list[low[auxvar]+s].incol]
						          : .NaN;
		if (curd[idvar]!=curid) {	// new path on possibly new FPanel
			if ((inf = I::OO[onlyfixed][]*curd[svar])) //fixed index not 0
				cur = fparray[inf];
			else	//fparray does not point to self
				cur = this;
			cur->FPanel::Append(curid = curd[idvar]);
			++FN;
			}
		fpcur = cur->GetCur();
		fpcur -> Path::Append(curd);   // append outcome to current Path of current FPanel
		++FNT;
		}
	if (!Version::MPIserver && Data::Volume>SILENT) {
            fprintln(Data::logf,". Total Outcomes Loaded: ",FNT);
            if (Data::Volume>LOUD) Summary(0);
            }
	}
	
/** Load outcomes into the data set from a (long format) file or an Ox database.
@param FNorDB string, file name with extension that can be read by
<code>OX::Database::Load</code><br>Database object
@param SearchLabels TRUE: search data set labels and use any matches as observed.

@example
<pre>
  d = new OutcomeDataSet();
  d -&gt; Read("data.dta");
</pre></dd>

**/
OutcomeDataSet::Read(FNorDB,SearchLabels) {
	if (FNT) oxrunerror("DDP Error 58. Cannot read data twice into the same data set. Merge files if necessary");
    if (isstring(FNorDB)) {
	   source = new Database();
	   if (!source->Load(FNorDB)) oxrunerror("DDP Error 59. Failed to load data from "+FNorDB);
        }
    else source = FNorDB;
	cputime0=timer();
	if (!list[idvar].obsv) {
        oxwarning("DDP Warning 60. OutcomeDataSet::IDColumn not called before reading data.  Using default (may cause an error)");
        IDColumn();
        }
	if (!list[low[svar]+counter.t.pos].obsv) {
        oxwarning("DDP Warning 60. OutcomeDataSet::tColumn not called before reading data. Using default (may cause an error)");
        tColumn();
        }
	if (SearchLabels) {
		decl lnames,mtch, i,j;
		lnames = source->GetAllNames();
		mtch = strfind(lnames,Labels::V[svar]);
		foreach(i in mtch[j]) if (i!=NoMatch) MatchToColumn(States[j],i);
		mtch = strfind(lnames,Labels::V[avar]);
		foreach(i in mtch[j]) if (i!=NoMatch) MatchToColumn(SubVectors[acts][j],i);
		mtch = strfind(lnames,Labels::V[auxvar]);
		foreach(i in mtch[j]) if (i!=NoMatch) MatchToColumn(Chi[j],i);
		}
	decl i;
	for (i=S[fgroup].M;i<=S[fgroup].X;++i)
		if (!list[low[svar]+i].obsv && !list[low[svar]+i].force0) oxrunerror("DDP Error 61. Fixed Effect Variable "+sprint(list[low[svar]+i].obj.L)+" must be observed or have N=1");	
    LoadOxDB();
	masked = FALSE;
	delete source;
	}

/** Store a `Panel` as a data set.
@param id <em>string</em>, tag for the data set
@param method, solution method to be used as data set is processed.<br/>0 [default], no
solution
**/
OutcomeDataSet::OutcomeDataSet(id,method) {
	if (!Flags::ThetaCreated) oxrunerror("DDP Error 62. Cannot create OutcomeDataSet before calling CreateSpaces()");
	label = id;
	Panel(0,method);
	masked = FALSE;
	decl q, aa=SubVectors[acts];
	list = {};
	list |= new DataColumn(idvar,0);
    low = zeros(NColumnTypes,1);
    low[avar] = 1;                  //first action variable
    low[svar] = low[avar]+N::Av;    //first state variable
    low[auxvar] = low[svar]+N::S;   //first aux. variable
	foreach (q in aa)      list |= new DataColumn(avar,q);
	foreach (q in States)  list |= new DataColumn(svar,q);
	foreach (q in Chi)     list |= new DataColumn(auxvar,q);
    LTypes = zeros(LikelihoodTypes,1);
	}																		

OutcomeDataSet::Simulate(N,T,ErgOrStateMat,DropTerminal,pathpred) {
    Panel::Simulate(N,T,ErgOrStateMat,DropTerminal,pathpred);
    IDColumn();
    tColumn();
    }

/** Delete a data set.
**/
OutcomeDataSet::~OutcomeDataSet() {
	~Panel();
	decl q;
	foreach (q in list) delete q;
	delete list;
	}
